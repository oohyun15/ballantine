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
    AVAILABLE_KEYS = [
      KEY_SLACK_WEBHOOK,
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

    # @param [Hash] options
    # @return [Boolean] result
    def init_file(**options)
      raise NotAllowed, "#{FILE_BALLANTINE_CONFIG} already exists." if Dir[file_path].any? && !options[:force]

      File.write(file_path, {})
      @loaded = false
    end

    # @param [Hash] options
    # @return [Boolean] result
    def load_file(**options)
      return false if @loaded
      raise NotAllowed, "Can't find #{FILE_BALLANTINE_CONFIG}" if Dir[file_path].empty?

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
    # @param [Hash] options
    # @return [Stirng] value
    def set_data(key, value, **options)
      load_file unless @loaded

      @data[key] = value
      File.write(file_path, JSON.dump(@data))
      value
    end

    # @param [String] key
    # @param [Hash] options
    # @return [Stirng] value
    def get_data(key, **options)
      load_file unless @loaded
      @data[key]
    end

    # @param [Binding] binding
    # @return [NilClass]
    def print_log(binding)
      method = caller(1..1)[0][/`([^']*)'/, 1]
      puts [
        "#{binding.receiver.class.name}##{method}",
        binding.receiver.method(method).parameters.map { |_, arg| arg }.map { |arg| "#{arg}:#{binding.local_variable_get(arg)}" }.join(" "),
      ].join(" ")
    end

    private

    def file_path(env = @env)
      case env
      when ENV_LOCAL then "./#{FILE_BALLANTINE_CONFIG}"
      when ENV_GLOBAL then "#{Dir.home}/#{FILE_BALLANTINE_CONFIG}"
      else raise AssertionFailed, "Unknown environment: #{env}"
      end
    end
  end
end
