# ballantine
**Ballantine** helps you describe your commits easier and prettier from cli & slack.

![example](https://user-images.githubusercontent.com/52606560/162619226-7275122c-ca55-4cab-b270-552e23149d4c.gif)

or print commits to slack channel using slack option.
```bash
ballantine diff production beta1 -s
```

![image](https://user-images.githubusercontent.com/52606560/180467424-de1e4efd-7016-472e-b376-b6341cf78ab6.png)

# Getting Started

## install
```bash
# add brew repository
$ brew tap oohyun15/ballantine

# install ballantine
$ brew install ballantine
```

## init
```bash
# intialize ballantine configuration
$ ballantine init
```

## how to use
```bash
# return ballantine command lines
$ ballantine

# return commits between production and feature/task-1 branch
$ ballantine diff production feature/task-1

# reutrn commits between defaf88 and a39aa43 commits
$ ballantine diff defaf88 a39aa43

# return commits to slack between production and beta
$ ballantine diff production beta -s

# return ballantine configuration
$ ballantine config
```

## update
```bash
# update ballantine
$ brew upgrade ballantine
```
