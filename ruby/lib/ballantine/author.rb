# frozen_string_literal: true

module Ballantine
  class Author
    attr_reader :name, :commits_hash

    class << self
      # @param [String] name
      # @return [Author] author
      def find_or_create_by(name:)
        @_collections = {} unless defined?(@_collections)
        return @_collections[name] unless @_collections[name].nil?

        @_collections[name] = new(name:)
      end

      # @return [Array<Author>] authors
      def all
        return [] unless defined?(@_collections)

        @_collections.sort.map(&:last) # sort and take values
      end
    end

    # @param [String] name
    def initialize(name:)
      @name = name
      @commits_hash = {}
    end

    # @return [Boolean]
    def print_commits
      puts "\n" + "@#{name}".green
      commits_hash.each do |repo_name, commits|
        count, word = retrieve_count_and_word(commits)
        puts " > #{repo_name.blue}: #{count} new #{word}\n"
        puts commits.map(&:message)
      end

      true
    end

    # returns an array to use slack attachments field
    # reference: https://api.slack.com/messaging/composing/layouts#building-attachments
    # @return [Hash] result
    def serialize_commits
      message = commits_hash.map do |repo_name, commits|
        count, word = retrieve_count_and_word(commits)
        "*#{repo_name}*: #{count} new #{word}\n#{commits.map(&:message).join("\n")}"
      end.join("\n")

      {
        "text" => "- <@#{name}>\n#{message}",
        "color" => "#00B86A", # green
      }
    end

    private

    # @param [Array<Commit>] commits
    # @param [Array(Integer, String)] count, word
    def retrieve_count_and_word(commits)
      count = commits.size
      word = count == 1 ? "commit" : "commits"
      [count, word]
    end
  end
end
