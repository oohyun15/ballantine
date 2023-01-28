# frozen_string_literal: true

require "thor"
require "json"
require_relative "string"
require_relative "ballantine/version"
require_relative "ballantine/config"
require_relative "ballantine/author"
require_relative "ballantine/repository"
require_relative "ballantine/commit"
require_relative "ballantine/cli"
require_relative "ballantine/printable"

module Ballantine
  class Error < StandardError; end
  class NotAllowed < Error; end
  class InvalidParameter < Error; end
  class AssertionFailed < Error; end
  class NotImplemented < Error; end
end
