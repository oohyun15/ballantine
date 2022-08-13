#!/usr/bin/env ruby

require 'thor'
require 'fileutils'
class Ballantine < Thor
  FILE_GITMODULES = '.gitmodules'

  P_NC= "\e[0m"
  P_GRAY= "\e[1;30m"
  P_RED= "\e[1;31m"
  P_GREEN= "\e[1;32m"
  P_YELLOW= "\e[1;33m"
  P_BLUE= "\e[1;34m"
  P_CYAN= "\e[1;36m"

  TEMP_PATH = '/tmp/commit_log'

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
  def diff(from, to)
    @_options = options
    @app_name = `git config --get remote.origin.url`.chomp[/([\w-]+)\.git/, 1]

    # check argument is tag
    from = check_tag(from)
    to = check_tag(to)

    # check commits are newest
    system 'git pull -f &> /dev/null'

    # find main, sub path
    @temp_path = FileUtils.mkdir_p(TEMP_PATH)[0]
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
  end

  private

  # @param [String] name
  # @return [String] hash
  def check_tag(name)
    # not implemented
    name
  end

  # @param [String] from
  # @param [String] to
  # @param [String] url
  # @return [NilClass] nil
  def check_commits(from, to, url)
    repo = `git config --get remote.origin.url`.chomp[/([\w-]+)\.git/, 1]
    authors = `git --no-pager log --pretty=format:"%an" #{from}..#{to}`.split("\n").uniq.sort

    authors.each do |author|
      file_path = @temp_path + "/#{author}.log"
      format = commit_format(url)
      commits = `git --no-pager log --reverse --no-merges --author=#{author} --format="#{format}" --abbrev=7 #{from}..#{to}`.gsub('"', '\"')
      next if commits.empty?
      count = commits.split("\n").size
      var = count == 1 ? 'commit' : 'commits'

      file = File.open(file_path, 'a')
      case @_options[:type]
      when TYPE_TERMINAL
        file.write("> #{P_BLUE}#{repo}#{P_NC}: #{count} new #{var}\n")
        file.write(commits)
        file.close
      when TYPE_SLACK
        file.write("*#{repo}*: #{count} new #{var}")
        file.write(commits)
        file.close
      end
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
      "- #{P_YELLOW}%h#{P_NC} %s #{P_GRAY}#{url}/commit/%H#{P_NC}"
    when TYPE_SLACK
      "\`<#{url}/commit/%H|%h\` %s - %an"
    end
  end

  # @param [String] from
  # @param [String] to
  # @param [String] url
  def send_commits(from, to, url)
    logs = Dir[@temp_path+'/*']
    number = logs.size
    if number.zero?
      puts "ERROR: There is no commits between \"#{from}\" and \"#{to}\""
      exit 1
    end
    last_commit = `git --no-pager log --reverse --format="#{commit_format(url)}" --abbrev=7 #{from}..#{to} -1`

    case @_options[:type]
    when TYPE_TERMINAL
      puts "Check commits before #{P_RED}#{@app_name}#{P_NC} deployment."
      puts "(#{P_CYAN}#{from}#{P_NC} <- #{P_CYAN}#{to}#{P_NC}) #{P_GRAY}#{url}/compare/#{from}...#{to}#{P_NC}"
      puts "#{P_YELLOW}Author#{P_NC}: #{number}"
      puts "#{P_BLUE}Last Commit#{P_NC}: #{last_commit}"

      logs.each do |log|
        author = log.chomp[/([\w-]+)\.log/, 1]
        puts "#{P_GREEN}@#{author}#{P_NC}"
        puts File.read(log)
      end
    when TYPE_SLACK
      # not implemented
    end

    FileUtils.rm_rf(@temp_path)
  end
end

Ballantine.start