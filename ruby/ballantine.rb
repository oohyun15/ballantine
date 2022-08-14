#!/usr/bin/env ruby

require 'thor'
require_relative 'src/author'
require_relative 'lib/string'

class Ballantine < Thor
  FILE_GITMODULES = '.gitmodules'

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

  TYPE_TERMINAL = 'terminal'
  TYPE_SLACK = 'slack'
  AVAILABLE_TYPES = [TYPE_TERMINAL, TYPE_SLACK].freeze

  package_name 'Ballantine'

  desc 'diff', 'diff commits'
  method_option :type, aliases: '-t', default: TYPE_TERMINAL, enum: AVAILABLE_TYPES
  # @param [String] from
  # @param [String] to
  # @return [Integer] exit code
  def diff(from, to)
    preprocess(from, to)

    @_options = options
    @app_name = File.basename(`git config --get remote.origin.url`.chomp, '.git')

    # check argument is tag
    from = check_tag(from)
    to = check_tag(to)

    # check commits are newest
    system 'git pull -f &> /dev/null'

    # find main, sub path
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

  # @param [String] from
  # @param [String] to
  # @return [NilClass] nil
  def preprocess(from, to)
    if Dir['.git'].empty?
      raise SystemCallError, "ERROR: There is no \".git\" in #{Dir.pwd}."
    end

    if (uncommitted = `git diff HEAD --name-only`.split("\n")).any?
      raise SystemCallError, "ERROR: Uncommitted file exists. stash or commit uncommitted files.\n#{uncommitted}"
    end

    if from == to
      raise ArgumentError, "ERROR: target(#{from}) and source(#{to}) branch can't be equal."
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
    case @_options[:type]
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

    case @_options[:type]
    when TYPE_TERMINAL
      puts "Check commits before #{@app_name.red} deployment. (#{from.cyan} <- #{to.cyan}) " + "#{url}/compare/#{from}...#{to}".gray
      puts "Author".yellow + ": #{number}"
      puts "Last Commit".blue + ": #{last_commit}"
      authors.map(&:print_commits)
    when TYPE_SLACK
      # set message for each author
      messages = authors.map(&:serialize_commits)
      actor = `git config user.name`

      # send message to slack
      require 'net/http'
      require 'uri'
      require 'json'
      uri = URI.parse(ENV['BLNT_WEBHOOK'])
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
