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

    attr_accessor :name, :path, :owner, :commits, :remote_url

    class << self
      # @param [String] name
      # @return [Repository]
      def find_or_create_by(name)
        @_collections = {} unless defined?(@_collections)
        return @_collections[name] unless @_collections[name].nil?

        @_collections[name] = new(name)
      end

      # @return [Array<Repository>]
      def all
        return [] unless defined?(@_collections)

        @_collections.values
      end
    end

    # @param [String] path
    def initialize(path)
      @path = path
      @commits = []

      Dir.chdir(path)
      @remote_url = %x(git config --get remote.origin.url).chomp
      @owner, @name = GITHUB_REGEXES.each do |regex|
        str = remote_url.match(regex)
        break [str[2], str[3]] if str
      end
    end

    # @return [String]
    def url
      "https://github.com/#{owner}/#{repository}"
    end
  end
end
