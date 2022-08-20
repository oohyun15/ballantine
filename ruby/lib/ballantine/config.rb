#!/usr/bin/env ruby

class Conf
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
    load_conf
  end

  private

  def load_conf
    return false if @loaded
    return false if Dir[file_path].empty?

    JSON.parse(File.read(file_path)).each do |key, value|
      next unless AVAILABLE_KEYS.include?(key)
      @data[key] = value
    end

    @loaded = true
  end

  def file_path
    case @env
    when ENV_LOCAL then "./#{FILE_BALLANTINE_CONFIG}"
    when ENV_GLOBAL then "#{Dir.home}/#{FILE_BALLANTINE_CONFIG}"
    else raise AssertionFailed, "Unknown environment: #{@env}"
    end
  end
end
