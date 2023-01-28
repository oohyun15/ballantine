# frozen_string_literal: true

module Ballantine
  class Commit
    attr_reader :hash, :long_hash, :subject, :url # attributes
    attr_reader :repo, :author # associations

    class << self
      # @param [String] hash
      # @param [String] long_hash
      # @param [String] subject
      # @param [Repository] repo
      # @param [Author, NilClass] subject
      # @return [Commit]
      def find_or_create_by(hash:, long_hash: nil, subject: nil, repo:, author: nil)
        @_collections = {} unless defined?(@_collections)
        index = "#{hash}-#{repo.name}"
        return @_collections[index] unless @_collections[index].nil?

        @_collections[index] = new(hash:, long_hash:, subject:, repo:, author:)
      end
    end

    # @param [String] hash
    # @param [String] long_hash
    # @param [String] subject
    # @param [Repository] repo
    # @param [Author] author
    def initialize(hash:, long_hash:, subject:, repo:, author:)
      @hash = hash
      @long_hash = long_hash
      @subject = subject
      @repo = repo
      @author = author
      @url = "#{repo.url}/commit/#{long_hash}"
    end

    # @return [String]
    def slack_message
      "\\\`<#{url}|#{hash}>\\\` #{subject} - #{author.name}"
    end
  end
end
