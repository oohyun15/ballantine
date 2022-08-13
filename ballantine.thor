require 'thor'
class Ballantine < Thor
  GIT_MODULES = '.gitmodules'

  package_name 'Ballantine'

  desc 'diff', 'diff commits'
  method_options type: :string, aliases: '-t'
  # @param [String] from
  # @param [String] to
  def diff(from, to)
    # check argument is tag
    from = check_tag(from)
    to = check_tag(to)

    # check commits are newest
    system 'git pull -f &> /dev/null'
    temp_path = Dir.mktmpdir
    main_path = Dir.pwd
    sub_path =
      if Dir[GIT_MODULES].any?
        file = File.open(GIT_MODULES)
        lines = file.readlines.map(&:chomp)
        file.close
        lines.grep(/path =/).map{ |line| line[/(?<=path \=).*/, 0].strip }.sort
      else
        []
      end

  end

  # @param [String] name
  # @return [String] hash
  def check_tag(name)
  end
end