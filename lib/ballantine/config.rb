# frozen_string_literal: true

module Ballantine
  class Config
    FILE_BALLANTINE_CONFIG = ".ballantine.json"
    ENV_LOCAL = "local"
    ENV_GLOBAL = "global"
    TYPE_TERMINAL = "terminal"
    TYPE_SLACK = "slack"
    AVAILABLE_ENVIRONMENTS = [
      ENV_LOCAL,
      ENV_GLOBAL,
    ].freeze
    KEY_SLACK_WEBHOOK = "slack_webhook"
    KEY_RAISE_UNCOMMITTED = "raise_uncommitted"
    AVAILABLE_KEYS = [
      KEY_SLACK_WEBHOOK,
      KEY_RAISE_UNCOMMITTED,
    ].freeze

    attr_reader :data, :loaded
    attr_accessor :env, :print_type, :verbose

    class << self
      # @note singleton method
      # @return [Config]
      def instance(...)
        return @_instance if defined?(@_instance)

        @_instance = new(...)
      end
    end

    def initialize
      @env = ENV_LOCAL
      @data = {}
      @loaded = false
      @print_type = TYPE_TERMINAL
      @verbose = false
    end

    # @param [Boolean] force
    # @return [Boolean] result
    def init_file(force: false)
      raise NotAllowed, "#{FILE_BALLANTINE_CONFIG} already exists." if Dir[file_path].any? && !force
      File.write(file_path, JSON.pretty_generate(empty_data))
      @loaded = false
    end

    # @return [Boolean] result
    def load_file
      return false if @loaded
      raise NotAllowed, "Can't find #{FILE_BALLANTINE_CONFIG}" if Dir[file_path].empty?

      JSON.parse(File.read(file_path)).each do |key, value|
        next unless AVAILABLE_KEYS.include?(key)

        @data[key] = sanitize_value(key, value)
      end

      @loaded = true
    end

    # @param [String] key
    # @return [Boolean] result
    def print_data(key)
      load_file unless @loaded

      if key
        raise InvalidParameter, "Key must be within #{AVAILABLE_KEYS}" unless AVAILABLE_KEYS.include?(key)

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
    # @return [Stirng] value
    def set_data(key, value)
      load_file unless @loaded
      raise InvalidParameter, "Key must be within #{AVAILABLE_KEYS}" unless AVAILABLE_KEYS.include?(key)
      @data[key] = sanitize_value(key, value)
      File.write(file_path, JSON.pretty_generate(@data))
      value
    end

    # @param [String] key
    # @return [Stirng] value
    def get_data(key)
      load_file unless @loaded
      @data[key]
    end

    # @return [Boolean]
    def raise_uncommitted? = get_data(KEY_RAISE_UNCOMMITTED)

    private

    def empty_data = AVAILABLE_KEYS.map { |key| [key, nil] }.to_h

    def sanitize_value(key, value)
      case key
      when KEY_RAISE_UNCOMMITTED then value == true || value == "true"
      else value
      end
    end

    def file_path(env = @env)
      case env
      when ENV_LOCAL then "./#{FILE_BALLANTINE_CONFIG}"
      when ENV_GLOBAL then "#{Dir.home}/#{FILE_BALLANTINE_CONFIG}"
      else raise AssertionFailed, "Unknown environment: #{env}"
      end
    end
  end
end
