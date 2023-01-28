# frozen_string_literal: true

module Ballantine
  class Repository
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
    FILE_GITMODULES = ".gitmodules"
    DEFAULT_LJUST = 70
    PARSER_TOKEN = "!#!#"

    attr_reader :name, :path, :owner, :url, :from, :to, :format # attributes
    attr_reader :main_repo, :sub_repos, :commits # associations

    class << self
      # @param [String] path
      # @param [String] remote_url
      # @return [Repository]
      def find_or_create_by(path:, remote_url: nil)
        @_collections = {} unless defined?(@_collections)
        return @_collections[path] unless @_collections[path].nil?

        @_collections[path] = new(path:, remote_url:)
      end

      # @return [Array<Repository>]
      def all
        return [] unless defined?(@_collections)

        @_collections.values
      end
    end

    # @param [String] path
    # @param [String] remote_url
    def initialize(path:, remote_url:)
      @path = path
      @commits = []
      @sub_repos = retrieve_sub_repos
      @owner, @name = GITHUB_REGEXES.each do |regex|
        str = remote_url.match(regex)
        break [str[2], str[3]] if str
      end
      @url = "https://github.com/#{owner}/#{name}"
      @format = check_format
    end

    # @param [String] target
    # @param [String] source
    # @return [Boolean]
    def init_variables(target, source)
      current_revision = %x(git rev-parse --abbrev-ref HEAD).chomp

      foo = lambda do |hash, context|
        hash = check_tag(hash)
        system("git checkout #{hash} -f &> /dev/null")
        system("git pull &> /dev/null")

        hash = %x(git --no-pager log -1 --format='%h').chomp
        commit = Commit.find_or_create_by(
          hash: hash,
          repo: self,
        )
        instance_variable_set("@#{context}", commit)

        if sub_repos.any?
          %x(git ls-tree HEAD #{sub_repos.map(&:path).join(" ")}).split("\n").map do |line|
            _, _, sub_hash, sub_path = line.split(" ")
            sub_repo = Repository.find_or_create_by(
              path: path + "/" + sub_path,
            )
            sub_commit = Commit.find_or_create_by(
              hash: sub_hash,
              repo: sub_repo,
            )
            sub_repo.instance_variable_set("@#{context}", sub_commit)
          end
        end
      end

      foo.call(target, "from")
      foo.call(source, "to")

      system("git checkout #{current_revision} -f &> /dev/null")

      true
    end

    # @return [Boolean]
    def check_commits
      authors = retrieve_authors
      authors.each do |author|
        commits = retrieve_commits(author)
        next if commits.empty?

        author.commits_hash[name] = commits
        # TODO: append `commits` to `repo.commits`
      end

      if sub_repos.any?
        sub_repos.each do |sub_repo|
          next if sub_repo.from.hash == sub_repo.to.hash

          Dir.chdir(sub_repo.path)
          sub_repo.check_commits
        end
        Dir.chdir(path)
      end

      true
    end

    # @return [String]
    def print_last_commit
      %x(git --no-pager log --reverse --format="#{check_format(ljust: DEFAULT_LJUST - 12)}" --abbrev=7 #{from.hash}..#{to.hash} -1).strip
    end

    private

    def conf; Config.instance end

    # @param [String] name
    # @return [String] hash
    def check_tag(name)
      list = %x(git tag -l).split("\n")
      return name unless list.grep(name).any?

      system("git fetch origin tag #{name} -f &> /dev/null")
      %x(git rev-list -n 1 #{name}).chomp[0...7]
    end

    # @param [Integer] ljust
    # @return [String]
    def check_format(ljust: DEFAULT_LJUST)
      case conf.print_type
      when Config::TYPE_TERMINAL
        " - " + "%h".yellow + " %<(#{ljust})%s " + "#{url}/commit/%H".gray
      when Config::TYPE_SLACK
        "\\\`<#{url}/commit/%H|%h>\\\` %s - %an"
      else
        raise AssertionFailed, "Unknown send type: #{conf.print_type}"
      end
    end

    # @return [Array<Repository>]
    def retrieve_sub_repos
      gitmodule = path + "/" + FILE_GITMODULES
      return [] unless Dir[gitmodule].any?

      file = File.open(gitmodule)
      resp = file.read
      file.close

      resp.split(/\[submodule.*\]/)
        .select { |line| line.match?(/path = /) }
        .sort
        .map do |line|
          line = line.strip
          repo = Repository.find_or_create_by(
            path: path + "/" + line.match(/path = (.*)/)[1],
            remote_url: line.match(/url = (.*)/)[1],
          )
          repo.instance_variable_set("@main_repo", self)
          repo
        end
    end

    # @return [Array<Author>]
    def retrieve_authors
      %x(git --no-pager log --pretty=format:"%an" #{from.hash}..#{to.hash})
        .split("\n").uniq.sort
        .map { |name| Author.find_or_create_by(name:) }
    end

    # @param [Author] author
    # @return [Array<Commit>]
    def retrieve_commits(author)
      results =
        %x(git --no-pager log --reverse --no-merges --author="#{author.name}" --format="%h#{PARSER_TOKEN}#{format}" --abbrev=7 #{from.hash}..#{to.hash})
          .gsub('"', '\"')
          .gsub(/[\u0080-\u00ff]/, "")
          .split("\n")

      results.map do |result|
        hash, message = result.split(PARSER_TOKEN)
        Commit.find_or_create_by(
          hash: hash,
          repo: self,
          message: message,
          author: author,
        )
      end
    end
  end
end
