# frozen_string_literal: true

module Ballantine
  class Commit
    attr_reader :hash, :long_hash, :subject # attributes
    attr_reader :repo, :author # associations

    class << self
      # @param [String] hash
      # @param [Repository] repo
      # @return [Commit]
      def find_or_create_by(hash:, repo:)
        @_collections = {} unless defined?(@_collections)
        index = "#{hash}-#{repo.name}"
        return @_collections[index] unless @_collections[index].nil?

        @_collections[index] = new(hash:, repo:)
      end
    end

    # @param [String] hash
    # @param [Repository] repo
    def initialize(hash:, repo:)
      @hash = hash
      @repo = repo
    end

    # @return [Commit]
    def update(**kwargs)
      # TODO: validate keys and values
      kwargs.each { |key, value| instance_variable_set("@#{key}", value) }
      self
    end

    def url; @url ||= "#{repo.url}/commit/#{long_hash}" end

    # @return [String]
    def slack_message
      "\\\`<#{url}|#{hash}>\\\` #{subject} - #{author.name}"
    end
  end
end
