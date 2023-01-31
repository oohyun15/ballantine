# ballantine

**Ballantine** helps you describe your commits easier and prettier from cli & slack.

![image](https://user-images.githubusercontent.com/52606560/215847624-ee8a7262-69f9-4278-8416-a346f88c2594.png)

or send commits to slack channel using slack option (`--slack`).

![image](https://user-images.githubusercontent.com/52606560/215847055-16a71030-f24a-42cd-bf76-78d5ee483dc7.png)

## Getting Started

### install

- Homebrew

```bash
# add brew repository
$ brew tap oohyun15/ballantine

# install ballantine
$ brew install ballantine
```

- RubyGems

```bash
# install ballantine
$ gem install ballantine
```

### init

```bash
# intialize ballantine configuration
$ ballantine init
```

### how to use

```bash
# return ballantine command lines
$ ballantine

# return ballantine configuration
$ ballantine config

# return commits between production and feature/task-1 branch
$ ballantine diff production feature/task-1

# reutrn commits between defaf88 and a39aa43 commits
$ ballantine diff defaf88 a39aa43

# return commits to slack between production and beta
$ ballantine diff production beta --slack

# return ballantine [COMMAND] options
$ ballantine help diff
```

### update

- Homebrew

```bash
# update ballantine
$ brew upgrade ballantine
```

- RubyGems

```bash
# update ballantine
$ gem update ballantine
```
