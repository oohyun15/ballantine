# frozen_string_literal: true

module Ballantine
  class CLI < Thor
    FILE_GITMODULES = ".gitmodules"

    TYPE_TERMINAL = "terminal"
    TYPE_SLACK = "slack"

    DEFAULT_LJUST = 80

    attr_reader :send_type, :repo, :sub_repos

    class << self
      def exit_on_failure?; exit(1) end
    end

    package_name "Ballantine"
    option "force", type: :boolean, aliases: "-f", default: false, desc: "Initialize forcely if already initialized."
    desc "init", "Initialize ballantine"
    def init
      conf.init_file(force: options["force"])

      puts "🥃 Initialized ballantine."

      true
    end

    Config::AVAILABLE_ENVIRONMENTS.each { |env| option env, type: :boolean, default: false, desc: "Set envirment to `#{env}'." }
    desc "config [--env] [KEY] [VALUE]", "Set ballantine's configuration"
    def config(key = nil, value = nil)
      # check environment value
      if Config::AVAILABLE_ENVIRONMENTS.map { |key| !options[key] }.reduce(:&)
        raise NotAllowed, "Set environment value (#{Config::AVAILABLE_ENVIRONMENTS.map { |key| "`--#{key}'" }.join(", ")})"
      elsif Config::AVAILABLE_ENVIRONMENTS.map { |key| !!options[key] }.reduce(:&)
        raise NotAllowed, "Environment value must be unique."
      end

      @env = Config::AVAILABLE_ENVIRONMENTS.find { |key| options[key] }
      raise AssertionFailed, "Environment value must exist: #{@env}" if @env.nil?

      value ? conf.set_data(key, value) : conf.print_data(key)
    end

    desc "diff [TARGET] [SOURCE]", "Diff commits between TARGET and SOURCE"
    option TYPE_SLACK, type: :boolean, aliases: "-s", default: false, desc: "Send to slack using slack webhook URL."
    def diff(target, source = %x(git rev-parse --abbrev-ref HEAD).chomp)
      # validate arguments
      validate(target, source, **options)

      # check commits are newest
      system("git pull -f &> /dev/null")

      # init instance variables
      init_variables(**options)

      # find github url, branch
      current_revision = %x(git rev-parse --abbrev-ref HEAD).chomp

      # get commit hash
      from, sub_from = commit_hash(target)
      to, sub_to = commit_hash(source)
      system("git checkout #{current_revision} -f &> /dev/null")

      # check commits
      check_commits(from, to, @repo.url)
      sub_paths.each_with_index do |path, idx|
        next if sub_from[idx] == sub_to[idx]

        Dir.chdir(path)
        sub_url = github_url(%x(git config --get remote.origin.url).chomp)
        check_commits(sub_from[idx], sub_to[idx], sub_url)
        Dir.chdir(main_path)
      end

      # send commits
      send_commits(target, source, from, to, @repo.url)

      exit(0)
    end

    desc "version", "Display version information about ballntine"
    def version
      puts "ballantine version #{Ballantine::VERSION}"

      Ballantine::VERSION
    end

    private

    def conf; @conf ||= Config.new(@env) end

    # @param [String] target
    # @param [String] source
    # @param [Hash] options
    # @return [NilClass] nil
    def validate(target, source, **options)
      if Dir[".git"].empty?
        raise NotAllowed, "ERROR: There is no \".git\" in #{Dir.pwd}."
      end

      if (uncommitted = %x(git diff HEAD --name-only).split("\n")).any?
        raise NotAllowed, "ERROR: Uncommitted file exists. stash or commit uncommitted files.\n#{uncommitted.join("\n")}"
      end

      if target == source
        raise NotAllowed, "ERROR: target(#{target}) and source(#{source}) can't be equal."
      end

      if options[TYPE_SLACK] && !conf.get_data(Config::KEY_SLACK_WEBHOOK)
        raise NotAllowed, "ERROR: Can't find any slack webhook. Set slack webhook using `ballantine config --#{Config::ENV_LOCAL} slack_webhook [YOUR_WEBHOOK]'."
      end

      nil
    end

    # @param [Hash] options
    # @return [Boolean]
    def init_variables(**options)
      @send_type = options[TYPE_SLACK] ? TYPE_SLACK : TYPE_TERMINAL
      @repo = Repository.find_or_create_by(Dir.pwd)
      @sub_repos =
        if Dir[FILE_GITMODULES].any?
          file = File.open(FILE_GITMODULES)
          lines = file.readlines.map(&:chomp)
          file.close
          lines.grep(/path =/).map do |line|
            Repository.find_or_create_by(repo.path + "/" + line[/(?<=path \=).*/, 0].strip)
          end
        else
          []
        end

      Dir.chdir(repo.path)
      true
    end

    # @param [String] name
    # @return [String] hash
    def check_tag(name)
      list = %x(git tag -l).split("\n")
      return name unless list.grep(name).any?

      system("git fetch origin tag #{name} -f &> /dev/null")
      %x(git rev-list -n 1 #{name}).chomp[0...7]
    end

    # @param [String] from
    # @param [String] to
    # @param [String] url
    # @return [NilClass] nil
    def check_commits(from, to, url)
      repo = File.basename(%x(git config --get remote.origin.url).chomp, ".git")
      names = %x(git --no-pager log --pretty=format:"%an" #{from}..#{to}).split("\n").uniq.sort
      authors = names.map { |name| Author.find_or_create_by(name) }
      authors.each do |author|
        format = commit_format(url, ljust: DEFAULT_LJUST - 10)
        commits =
          %x(git --no-pager log --reverse --no-merges --author="#{author.name}" --format="#{format}" --abbrev=7 #{from}..#{to})
            .gsub('"', '\"')
            .gsub(/[\u0080-\u00ff]/, "")
        next if commits.empty?

        author.commits[repo] = commits.split("\n")
      end
      nil
    end

    # TODO: check target, source context
    # @param [String] hash
    # @return [Array(String, Array<String>)] main, sub's hash
    def commit_hash(hash)
      # check argument is tag
      hash = check_tag(hash)

      system("git checkout #{hash} -f &> /dev/null")
      system("git pull &> /dev/null")
      main_hash = %x(git --no-pager log -1 --format='%h').chomp
      sub_hash =
        if sub_repos.any?
          %x(git ls-tree HEAD #{sub_repos.map(&:path).join(" ")}).split("\n").map { |line| line.split(" ")[2] }
        else
          []
        end

      [main_hash, sub_hash]
    end

    # @param [String] url
    # @param [String] format
    # @param [Integer] ljust
    def commit_format(url, ljust: DEFAULT_LJUST)
      case send_type
      when TYPE_TERMINAL
        " - " + "%h".yellow + " %<(#{ljust})%s " + "#{url}/commit/%H".gray
      when TYPE_SLACK
        "\\\`<#{url}/commit/%H|%h>\\\` %s - %an"
      else raise AssertionFailed, "Unknown send type: #{send_type}"
      end
    end

    # @param [String] target
    # @param [String] source
    # @param [String] from
    # @param [String] to
    # @param [String] url
    # @return [NilClass] nil
    def send_commits(target, source, from, to, url)
      authors = Author.all
      if authors.empty?
        raise ArgumentError, "ERROR: There is no commits between \"#{target}\" and \"#{source}\""
      end

      number = authors.size
      last_commit = %x(git --no-pager log --reverse --format="#{commit_format(url, ljust: DEFAULT_LJUST - 22)}" --abbrev=7 #{from}..#{to} -1).strip

      case send_type
      when TYPE_TERMINAL
        puts "Check commits before #{repo.name.red} deployment. (#{target.cyan} <- #{source.cyan})".ljust(DEFAULT_LJUST + 34) + " #{url}/compare/#{from}...#{to}".gray
        puts "Author".yellow + ": #{number}"
        puts "Last commit".blue + ": #{last_commit}"
        authors.map(&:print_commits)
      when TYPE_SLACK
        # set message for each author
        messages = authors.map(&:serialize_commits)
        actor = %x(git config user.name).chomp

        # send message to slack
        require "net/http"
        require "uri"
        uri = URI.parse(conf.get_data(Config::KEY_SLACK_WEBHOOK))
        request = Net::HTTP::Post.new(uri)
        request.content_type = "application/json"
        request.body = JSON.dump({
          "text" => ":white_check_mark: *#{repo.name}* deployment request by <@#{actor}> (\`<#{url}/tree/#{from}|#{target}>\` <- \`<#{url}/tree/#{to}|#{source}>\` <#{url}/compare/#{from}...#{to}|compare>)\n:technologist: Author: #{number}\nLast commit: #{last_commit}",
          "attachments" => messages,
        })
        req_options = { use_ssl: uri.scheme == "https" }
        response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
          http.request(request)
        end
        puts response.message
      else
        raise AssertionFailed, "Unknown send type: #{send_type}"
      end
    end
  end
end
