# frozen_string_literal: true

require_relative "lib/ballantine/version"

Gem::Specification.new do |spec|
  spec.name = "ballantine"
  spec.version = Ballantine::VERSION
  spec.authors = ["oohyun15"]
  spec.email = ["sakiss4774@gmail.com"]

  spec.summary = "Describe your commits."
  spec.description = "Ballantine helps you describe your commits easier and prettier from cli & slack."
  spec.homepage = "https://github.com/oohyun15/ballantine"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.6"
  spec.add_dependency "thor", "~> 1.2.1"
  spec.add_development_dependency "yard", "~> 0.9.28"

  spec.files = Dir["lib/ballantine.rb"]
  spec.files += Dir["lib/ballantine/*.rb"]
  spec.executables = ["ballantine"]
end