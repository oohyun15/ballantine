# frozen_string_literal: true

module Ballantine
  class Commit
    attr_reader :hash, :message # attributes
    attr_reader :repo, :author # associations

    class << self
      # @param [String] hash
      # @param [Repository] repo
      # @param [String] message
      # @param [Author, NilClass] message
      # @return [Commit]
      def find_or_create_by(hash:, repo:, message: nil, author: nil)
        @_collections = {} unless defined?(@_collections)
        index = "#{hash}-#{repo.name}"
        return @_collections[index] unless @_collections[index].nil?

        @_collections[index] = new(hash:, repo:, message:, author:)
      end
    end

    # @param [String] hash
    # @param [Repository] repo
    # @param [String] message
    # @param [Author] author
    def initialize(hash:, repo:, message:, author:)
      @hash = hash
      @repo = repo
      @message = message
      @author = author
    end
  end
end
