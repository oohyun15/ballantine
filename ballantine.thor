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

    # find main, sub path
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

    # find github url, branch
    main_url = github_url(`git config --get remote.origin.url`.chomp)
    current_branch = `git rev-parse --abbrev-ref HEAD`.chomp

    # get commit hash
    main_from, sub_from = commit_hash(from, sub_path)
    main_to, sub_to = commit_hash(to, sub_path)
  end

  # @param [String] name
  # @return [String] hash
  def check_tag(name)
    # not implemented
  end

  # @param [String] url
  # @return [String] github_url
  def github_url(url)
    # not implemented
  end

  # @param [String] hash
  # @param [Array<String>] sub_path
  # @return [Array(String, Array<String>)] main, sub's hash
  def commit_hash(hash, sub_path = [])
    system "git checkout #{hash} -f &> /dev/null"
    system 'git pull &> /dev/null'
    main_hash = `git --no-pager log -1 --format='%h'`.chomp
    sub_hash =
      if sub_path.any?
        `git ls-tree HEAD #{sub_path.join(' ')}`.split("\n").map{ |line| line.split(' ')[2] }
      else
        []
      end
    [main_hash, sub_hash]
  end
end