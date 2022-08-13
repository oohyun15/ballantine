require 'thor'
class Ballantine < Thor
  package_name 'Ballantine'

  desc 'diff', 'diff commits'
  method_options type: :string, aliases: '-t'
  # @param [String] from
  # @param [String] to
  def diff(from, to)
    puts from, to
  end
end