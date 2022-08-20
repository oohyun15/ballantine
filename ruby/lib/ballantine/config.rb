#!/usr/bin/env ruby

module Ballantine
  class Config
    ENV_LOCAL = 'local'
    ENV_GLOBAL = 'global'
    AVAILABLE_ENVIRONMENTS = [
      ENV_LOCAL,
      ENV_GLOBAL
    ].freeze

    KEY_SLACK_WEBHOOK = 'slack_webhook'
    AVAILABLE_KEYS = [
      KEY_SLACK_WEBHOOK
    ].freeze

    FILE_BALLANTINE_CONFIG = '.ballantine.json'

    attr_reader :env, :data, :loaded

    def initialize(env = ENV_LOCAL)
      @env = env
      @data = {}
      @loaded = false
    end

    # @param [Hash] options
    # @return [Boolean] result
    def init_file(**options)
      raise NotAllowed, "#{FILE_BALLANTINE_CONFIG} already exists." if Dir[file_path].any? && !options[:force]

      File.write(file_path, nil)
      @loaded = false
    end

    # @param [Hash] options
    # @return [Boolean] result
    def load_file(**options)
      return false if @loaded
      raise NotAllowed, "Could not find #{FILE_BALLANTINE_CONFIG}" if Dir[file_path].empty?

      JSON.parse(File.read(file_path)).each do |key, value|
        next unless AVAILABLE_KEYS.include?(key)
        @data[key] = value
      end

      @loaded = true
    end

    # @param [String] key
    # @param [Hash] options
    # @return [Boolean] result
    def print_data(key, **options)
      load_file unless @loaded

      if key
        puts @data[key]
      else
        @data.each do |key, value|
          puts "#{key}: #{value}"
        end
      end

      true
    end

    # @param [String] key
    # @param [String] value
    # @param [Hash] options
    # @return [Stirng] value
    def set_data(key, value, **options)
      load_file unless @loaded

      @data[key] = value
      File.write(file_path, JSON.dump(@data))
      value
    end

    private

    def file_path
      case @env
      when ENV_LOCAL then "./#{FILE_BALLANTINE_CONFIG}"
      when ENV_GLOBAL then "#{Dir.home}/#{FILE_BALLANTINE_CONFIG}"
      else raise AssertionFailed, "Unknown environment: #{@env}"
      end
    end
  end
end
