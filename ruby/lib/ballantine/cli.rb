# frozen_string_literal: true

module Ballantine
  class CLI < Thor
    attr_reader :repo

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
    option Config::TYPE_SLACK, type: :boolean, aliases: "-s", default: false, desc: "Send to slack using slack webhook URL."
    def diff(target, source = %x(git rev-parse --abbrev-ref HEAD).chomp)
      # validate arguments
      validate(target, source, **options)

      # check commits are newest
      system("git pull -f &> /dev/null")

      # init instance variables
      init_variables(target, source, **options)

      # check commits
      check_commits(**options)

      # print commits
      print_commits(target, source, **options)

      exit(0)
    end

    desc "version", "Display version information about ballntine"
    def version
      puts "ballantine version #{Ballantine::VERSION}"

      Ballantine::VERSION
    end

    private

    def conf; Config.instance(@env) end

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

      if options[Config::TYPE_SLACK] && !conf.get_data(Config::KEY_SLACK_WEBHOOK)
        raise NotAllowed, "ERROR: Can't find any slack webhook. Set slack webhook using `ballantine config --#{Config::ENV_LOCAL} slack_webhook [YOUR_WEBHOOK]'."
      end

      nil
    end

    # @param [String] target
    # @param [String] source
    # @param [Hash] options
    # @return [Boolean]
    def init_variables(target, source, **options)
      conf.print_type = options[Config::TYPE_SLACK] ? Config::TYPE_SLACK : Config::TYPE_TERMINAL
      @repo = Repository.find_or_create_by(
        path: Dir.pwd,
        remote_url: %x(git config --get remote.origin.url).chomp,
      )

      # init repo
      repo.init_variables(target, source)
      true
    end

    # @param [Hash] options
    # @return [Boolean]
    def check_commits(**options)
      repo.check_commits

      true
    end

    # @param [String] target
    # @param [String] source
    # @param [Hash] options
    # @return [Boolean]
    def print_commits(target, source, **options)
      authors = Author.all
      if authors.empty?
        raise ArgumentError, "ERROR: There is no commits between \"#{target}\" and \"#{source}\""
      end

      number = authors.size
      last_commit = repo.print_last_commit

      case conf.print_type
      when Config::TYPE_TERMINAL
        puts "Check commits before #{repo.name.red} deployment. (#{target.cyan} <- #{source.cyan})".ljust(Repository::DEFAULT_LJUST + 44) + " #{repo.url}/compare/#{repo.from.hash}...#{repo.to.hash}".gray
        puts "Author".yellow + ": #{number}"
        puts "Last commit".blue + ": #{last_commit}"
        authors.map(&:print_commits)
      when Config::TYPE_SLACK
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
          "text" => ":white_check_mark: *#{repo.name}* deployment request by <@#{actor}>" \
            " (\`<#{repo.url}/tree/#{repo.from.hash}|#{target}>\` <- \`<#{repo.url}/tree/#{repo.to.hash}|#{source}>\` <#{repo.url}/compare/#{repo.from.hash}...#{repo.to.hash}|compare>)" \
            "\n:technologist: Author: #{number}\nLast commit: #{last_commit}",
          "attachments" => messages,
        })
        req_options = { use_ssl: uri.scheme == "https" }
        response = Net::HTTP.start(uri.hostname, uri.port, req_options) { |http| http.request(request) }
        puts response.message
      else
        raise AssertionFailed, "Unknown send type: #{conf.print_type}"
      end

      true
    end
  end
end
