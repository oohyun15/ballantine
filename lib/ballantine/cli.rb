# frozen_string_literal: true

module Ballantine
  class CLI < Thor
    include Printable

    attr_reader :repo

    class << self
      def exit_on_failure? = exit(1)
    end

    package_name "Ballantine"
    option "force", type: :boolean, aliases: "-f", default: false, desc: "Initialize forcely if already initialized."
    desc "init", "Initialize ballantine"
    def init
      Config.instance.init_file(force: options["force"])

      puts "🥃 Initialized ballantine."

      true
    end

    Config::AVAILABLE_ENVIRONMENTS.each { |env| option env, type: :boolean, default: false, desc: "Set envirment to `#{env}'." }
    option "verbose", type: :boolean, default: false, desc: "Print a progress."
    desc "config [--env] [KEY] [VALUE]", "Set ballantine's configuration"
    def config(key = nil, value = nil)
      Config.instance.verbose = options["verbose"]
      puts "$ ballantine config #{key} #{value}" if Config.instance.verbose

      # check environment value
      if Config::AVAILABLE_ENVIRONMENTS.map { |key| !options[key] }.reduce(:&)
        raise NotAllowed, "Set environment value (#{Config::AVAILABLE_ENVIRONMENTS.map { |key| "`--#{key}'" }.join(", ")})"
      elsif Config::AVAILABLE_ENVIRONMENTS.map { |key| !!options[key] }.reduce(:&)
        raise NotAllowed, "Environment value must be unique."
      end

      env = Config::AVAILABLE_ENVIRONMENTS.find { |key| options[key] }
      raise AssertionFailed, "Environment value must exist: #{env}" if env.nil?

      Config.instance.env = env
      value ? Config.instance.set_data(key, value) : Config.instance.print_data(key)

      true
    end

    option "verbose", type: :boolean, default: false, desc: "Print a progress."
    option Config::TYPE_SLACK, type: :boolean, aliases: "-s", default: false, desc: "Send to slack using slack webhook URL."
    desc "diff [TARGET] [SOURCE]", "Diff commits between TARGET and SOURCE"
    def diff(target, source = %x(git rev-parse --abbrev-ref HEAD).chomp)
      Config.instance.verbose = options["verbose"]
      puts "$ ballantine diff #{target} #{source}" if Config.instance.verbose

      # retrieve uncommitted files
      uncommitted = retrieve_uncommitted

      # validate arguments
      validate(target, source, uncommitted, **options)

      with_stash(uncommitted) do
        # init instance variables
        init_variables(target, source, **options)

        # check commits
        check_commits

        # print commits
        print_commits(target, source)
      end
    end

    desc "version", "Display version information about ballntine"
    def version
      puts "ballantine version #{Ballantine::VERSION}"

      Ballantine::VERSION
    end

    private

    # @param [String] target
    # @param [String] source
    # @param [Array<String>] uncommitted
    # @param [Hash] options
    # @return [NilClass] nil
    def validate(target, source, uncommitted, **options)
      if Dir[".git"].empty?
        raise NotAllowed, "ERROR: There is no \".git\" in #{Dir.pwd}."
      end

      if uncommitted.any? && Config.instance.raise_uncommitted?
        raise NotAllowed, "ERROR: Uncommitted file exists. stash or commit uncommitted files.\n\t#{uncommitted.join("\n\t")}"
      end

      if target == source
        raise NotAllowed, "ERROR: target(#{target}) and source(#{source}) can't be equal."
      end

      if options[Config::TYPE_SLACK] && !Config.instance.get_data(Config::KEY_SLACK_WEBHOOK)
        raise NotAllowed, "ERROR: Can't find any slack webhook. Set slack webhook using `ballantine config --#{Config::ENV_LOCAL} slack_webhook [YOUR_WEBHOOK]'."
      end

      nil
    end

    # @param [String] target
    # @param [String] source
    # @param [Hash] options
    # @return [Boolean]
    def init_variables(target, source, **options)
      # check commits are newest
      system("git pull -f &> /dev/null")

      Config.instance.print_type = options[Config::TYPE_SLACK] ? Config::TYPE_SLACK : Config::TYPE_TERMINAL
      @repo = Repository.find_or_create_by(
        path: Dir.pwd,
        remote_url: %x(git config --get remote.origin.url).chomp,
      )

      # init repo
      repo.init_variables(target, source)
      true
    end

    # @return [Boolean]
    def check_commits
      repo.check_commits
      true
    end

    # @param [String] target
    # @param [String] source
    # @return [Boolean]
    def print_commits(target, source)
      authors = Author.all
      if authors.empty?
        raise ArgumentError, "ERROR: There is no commits between \"#{target}\" and \"#{source}\""
      end

      number = authors.size

      case Config.instance.print_type
      when Config::TYPE_TERMINAL
        puts_r "Check commits before #{repo.name.red} deployment. (#{target.cyan}...#{source.cyan})", "#{repo.url}/compare/#{repo.from.hash}...#{repo.to.hash}".gray
        puts "Author".yellow + ": #{number}"
        puts_r "#{"Last commit".blue}: #{repo.to.hash.yellow} #{repo.to.subject}", repo.to.url.gray
        authors.map(&:print_commits)
      when Config::TYPE_SLACK
        # set message for each author
        messages = authors.map(&:slack_message)
        actor = %x(git config user.name).chomp

        # send message to slack
        require "net/http"
        require "uri"
        uri = URI.parse(Config.instance.get_data(Config::KEY_SLACK_WEBHOOK))
        request = Net::HTTP::Post.new(uri)
        request.content_type = "application/json"
        request.body = JSON.dump({
          "text" => ":white_check_mark: *#{repo.name}* deployment request by <@#{actor}>" \
            " (\`<#{repo.url}/tree/#{repo.from.hash}|#{target}>\`<#{repo.url}/compare/#{repo.from.hash}...#{repo.to.hash}|...>\`<#{repo.url}/tree/#{repo.to.hash}|#{source}>\`)" \
            "\n:technologist: Author: #{number}\nLast commit: #{repo.to.slack_message}",
          "attachments" => messages,
        })
        req_options = { use_ssl: uri.scheme == "https" }
        response = Net::HTTP.start(uri.hostname, uri.port, req_options) { |http| http.request(request) }
        puts response.message
      else
        raise AssertionFailed, "Unknown print type: #{Config.instance.print_type}"
      end

      true
    end

    # @param [Array<String>] uncommitted
    # @return [Boolean]
    def with_stash(uncommitted)
      if uncommitted.any? && !Config.instance.raise_uncommitted?
        save_stash
        yield
        restore_stash
      else
        yield
      end
      true
    end

    # @return [Array<String>]
    def retrieve_uncommitted
      %x(git diff HEAD --name-only).split("\n")
    end

    # @return [Boolean]
    def save_stash
      %x(git stash save &> /dev/null)
      true
    end

    # @return [Boolean]
    def restore_stash
      %x(git stash apply &> /dev/null)
      true
    end
  end
end
