#!/usr/bin/env ruby

class Author
  attr_accessor :name, :commits

  class << self
    # @param [String] name
    # @return [Author] author
    def find_or_create_by(name)
      @@_collections = {} unless defined?(@@_collections)
      return @@_collections[name] unless @@_collections[name].nil?
      @@_collections[name] = new(name)
    end

    # @return [Array<Author>] authors
    def all
      return [] unless defined?(@@_collections)
      @@_collections.sort.map(&:last) # sort and take values
    end
  end

  # @param [String] name
  def initialize(name)
    @name = name
    @commits = {}
  end

  # @return [NilClass] nil
  def print_commits
    puts "\n@" + name.green
    @commits.each do |repo, lists|
      count, word = retrieve_count_and_word(lists)
      puts " > #{repo.blue}: #{count} new #{word}\n"
      puts lists
    end
    nil
  end

  # returns an array to use slack attachments field
  # reference: https://api.slack.com/messaging/composing/layouts#building-attachments
  # @return [Hash] result
  def serialize_commits
    message =
      @commits.map do |repo, lists|
        count, word = retrieve_count_and_word(lists)
        "*#{repo}*: #{count} new #{word}\n#{lists.join("\n")}"
      end.join("\n")

    results = {
      'text' => "- <@#{name}>\n#{message}",
      'color' => '#00B86A', # green
    }
  end

  private

  # @param [Array<String>] lists
  # @param [Array(Integer, String)] count, word
  def retrieve_count_and_word(lists)
    count = lists.size
    word = count == 1 ? 'commit' : 'commits'
    [count, word]
  end
end
