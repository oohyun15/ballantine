#!/usr/bin/env ruby

require 'thor'
require 'json'
require_relative 'src/author'
require_relative 'lib/string'

class Ballantine < Thor
  # reference: https://github.com/desktop/desktop/blob/a7bca44088b105a04714dc4628f4af50f6f179c3/app/src/lib/remote-parsing.ts#L27-L44
  GITHUB_REGEXES = [
    '^https?://(.+)/(.+)/(.+)\.git/?$', # protocol: https -> https://github.com/oohyun15/ballantine.git | https://github.com/oohyun15/ballantine.git/
    '^https?://(.+)/(.+)/(.+)/?$',      # protocol: https -> https://github.com/oohyun15/ballantine | https://github.com/oohyun15/ballantine/
    '^git@(.+):(.+)/(.+)\.git$',        # protocol: ssh   -> git@github.com:oohyun15/ballantine.git
    '^git@(.+):(.+)/(.+)/?$',           # protocol: ssh   -> git@github.com:oohyun15/ballantine | git@github.com:oohyun15/ballantine/
    '^git:(.+)/(.+)/(.+)\.git$',        # protocol: ssh   -> git:github.com/oohyun15/ballantine.git
    '^git:(.+)/(.+)/(.+)/?$',           # protocol: ssh   -> git:github.com/oohyun15/ballantine | git:github.com/oohyun15/ballantine/
    '^ssh://git@(.+)/(.+)/(.+)\.git$',  # protocol: ssh   -> ssh://git@github.com/oohyun15/ballantine.git
  ].freeze

  FILE_GITMODULES = '.gitmodules'
  FILE_BALLANTINE_CONFIG = '.ballantine.json'

  TYPE_TERMINAL = 'terminal'
  TYPE_SLACK = 'slack'

  AVAILABLE_CONFIG = ['slack_webhook'].freeze

  attr_reader :app_name, :main_path, :sub_path, :slack_webhook, :send_type

  package_name 'Ballantine'

  desc 'init', 'init ballantine configuration'
  def init
    puts "🥃 Init ballantine configuration"
    slack_webhook = ask("Q. Set slack webhook (optional)\n> ")

    config = {
      slack_webhook: slack_webhook
    }
    File.write('./' + FILE_BALLANTINE_CONFIG, JSON.dump(config))
  end

  desc 'diff [TARGET] [SOURCE]', 'diff commits between TARGET and SOURCE'
  option TYPE_SLACK, type: :boolean, aliases: '-s', default: false, desc: 'send to slack using slack webhook URL.'
  def diff(from, to = `git rev-parse --abbrev-ref HEAD`.chomp)
    load_config
    preprocess(from, to, **options)

    # check argument is tag
    from = check_tag(from)
    to = check_tag(to)

    # check commits are newest
    system 'git pull -f &> /dev/null'

    # set instance variables
    @send_type = options[TYPE_SLACK] ? TYPE_SLACK : TYPE_TERMINAL
    @app_name = File.basename(`git config --get remote.origin.url`.chomp, '.git')
    @main_path = Dir.pwd
    @sub_path =
      if Dir[FILE_GITMODULES].any?
        file = File.open(FILE_GITMODULES)
        lines = file.readlines.map(&:chomp)
        file.close
        lines.grep(/path =/).map{ |line| line[/(?<=path \=).*/, 0].strip }.sort
      else
        []
      end

    # find github url, branch
    main_url = github_url(`git config --get remote.origin.url`.chomp)
    current_branch = `git rev-parse --abbrev-ref HEAD`.chomp

    # get commit hash
    main_from, sub_from = commit_hash(from)
    main_to, sub_to = commit_hash(to)
    system "git checkout #{current_branch} -f &> /dev/null"

    # check commits
    check_commits(main_from, main_to, main_url)
    @sub_path.each_with_index do |path, idx|
      next if sub_from[idx] == sub_to[idx]
      Dir.chdir(path)
      sub_url = github_url(`git config --get remote.origin.url`.chomp)
      check_commits(sub_from[idx], sub_to[idx], sub_url)
      Dir.chdir(@main_path)
    end

    send_commits(from, to, main_url)

    exit 0
  end

  private

  def load_config
    return if Dir[FILE_BALLANTINE_CONFIG].empty?

    JSON.parse(File.read('./' + FILE_BALLANTINE_CONFIG)).each do |key, value|
      next unless AVAILABLE_CONFIG.include?(key)
      instance_variable_set('@' + key, value)
    end
  end

  # @param [String] from
  # @param [String] to
  # @param [Hash] options
  # @return [NilClass] nil
  def preprocess(from, to, **options)
    if Dir['.git'].empty?
      raise SystemCallError, "ERROR: There is no \".git\" in #{Dir.pwd}."
    end

    if (uncommitted = `git diff HEAD --name-only`.split("\n")).any?
      raise SystemCallError, "ERROR: Uncommitted file exists. stash or commit uncommitted files.\n#{uncommitted.join("\n")}"
    end

    if from == to
      raise ArgumentError, "ERROR: target(#{from}) and source(#{to}) can't be equal."
    end

    if options[TYPE_SLACK] && !@slack_webhook
      raise ArgumentError, "ERROR: Can't find any slack webhook. Set slack webhook using `ballantine init`."
    end

    nil
  end

  # @param [String] name
  # @return [String] hash
  def check_tag(name)
    list = `git tag -l`.split("\n")
    return name unless list.grep(name).any?

    system "git fetch origin tag #{name} -f &> /dev/null"
    `git rev-list -n 1 #{name}`.chomp[0...7]
  end

  # @param [String] from
  # @param [String] to
  # @param [String] url
  # @return [NilClass] nil
  def check_commits(from, to, url)
    repo = File.basename(`git config --get remote.origin.url`.chomp, '.git')
    names = `git --no-pager log --pretty=format:"%an" #{from}..#{to}`.split("\n").uniq.sort
    authors = names.map{ |name| Author.find_or_create_by(name) }
    authors.each do |author|
      format = commit_format(url)
      commits = `git --no-pager log --reverse --no-merges --author="#{author.name}" --format="#{format}" --abbrev=7 #{from}..#{to}`.gsub('"', '\"').gsub(/[\u0080-\u00ff]/, '')
      next if commits.empty?
      author.commits[repo] = commits.split("\n")
    end
    nil
  end

  # @param [String] url
  # @return [String] github_url
  def github_url(url)
    owner, repository =
      GITHUB_REGEXES.each do |regex|
        if (str = url.match(regex))
          break [str[2], str[3]]
        end
      end
    "https://github.com/#{owner}/#{repository}"
  end

  # @param [String] hash
  # @param [Array<String>] sub_path
  # @return [Array(String, Array<String>)] main, sub's hash
  def commit_hash(hash)
    system "git checkout #{hash} -f &> /dev/null"
    system 'git pull &> /dev/null'
    main_hash = `git --no-pager log -1 --format='%h'`.chomp
    sub_hash =
      if @sub_path.any?
        `git ls-tree HEAD #{@sub_path.join(' ')}`.split("\n").map{ |line| line.split(' ')[2] }
      else
        []
      end
    [main_hash, sub_hash]
  end

  # @param [String] url
  # @param [String] format
  def commit_format(url)
    case @send_type
    when TYPE_TERMINAL
      " - "+ "%h".yellow + " %s " + "#{url}/commit/%H".gray
    when TYPE_SLACK
      "\\\`<#{url}/commit/%H|%h>\\\` %s - %an"
    end
  end

  # @param [String] from
  # @param [String] to
  # @param [String] url
  # @return [NilClass] nil
  def send_commits(from, to, url)
    authors = Author.all
    if authors.empty?
      raise ArgumentError, "ERROR: There is no commits between \"#{from}\" and \"#{to}\""
    end
    number = authors.size
    last_commit = `git --no-pager log --reverse --format="#{commit_format(url)}" --abbrev=7 #{from}..#{to} -1`.strip

    case @send_type
    when TYPE_TERMINAL
      puts "Check commits before #{@app_name.red} deployment. (#{from.cyan} <- #{to.cyan}) " + "#{url}/compare/#{from}...#{to}".gray
      puts "Author".yellow + ": #{number}"
      puts "Last commit".blue + ": #{last_commit}"
      authors.map(&:print_commits)
    when TYPE_SLACK
      # set message for each author
      messages = authors.map(&:serialize_commits)
      actor = `git config user.name`

      # send message to slack
      require 'net/http'
      require 'uri'
      uri = URI.parse(@slack_webhook)
      request = Net::HTTP::Post.new(uri)
      request.content_type = 'application/json'
      request.body = JSON.dump({
        'text' => ":check: *#{@app_name}* deployment request by <@#{actor}> (\`<#{url}/tree/#{from}|#{from}>\` <- \`<#{url}/tree/#{to}|#{to}>\` <#{url}/compare/#{from}...#{to}|compare>)\n:technologist: Author: #{number}\nLast commit: #{last_commit}",
        'attachments' => messages
      })
      req_options = { use_ssl: uri.scheme == 'https' }
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
      puts response.message
    end
  end
end

Ballantine.start
