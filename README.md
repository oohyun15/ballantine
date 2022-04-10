# ballantine
describe your commits

![example](https://user-images.githubusercontent.com/52606560/162619226-7275122c-ca55-4cab-b270-552e23149d4c.gif)

# Getting Started

## install
```bash
# add brew repository
$ brew tap oohyun15/ballantine

# install ballantine
$ brew install ballantine
```

## how to use
```bash
# return commits between production and main branch
$ ballantine

# return commits between production and feature/task-1 branch
$ ballantine production feature/task-1

# reutrn commits between defaf88 and a39aa43 commits
$ ballantine defaf88 a39aa43

# return commits to slack between production and beta
$ ballantine -s production beta
```
