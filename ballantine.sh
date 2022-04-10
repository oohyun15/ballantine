#!/bin/bash
NC='\033[0m'
GRAY='\033[1;30m'
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
APP_NAME=$(basename -s .git `git config --get remote.origin.url`)

if [[ $1 == 'init' ]]; then
  source src/init.sh
  init
fi

source ~/.blntrc
source src/diff_commits.sh

type='terminal'
while getopts "hos" opt; do
  case $opt in
    h)
      echo "[commands]"
      echo "ballantine init               : initialize ballantine configuration"
      echo "ballantine                    : check commits between \$target_branch and \$current_branch."
      echo "ballantine production main    : check commits between \`production\` and \`main\` branch."
      echo "ballantine -s production main : send to slack commits between \`production\` and \`main\` branch."

      echo
      echo "[options]"
      echo "-h: help"
      echo "-o: check ballantine option values."
      echo "-s: send to slack using slack webhook URL."
      exit 0
      ;;
    o)
      echo "target branch: $target_branch"
      echo "slack webhook: $webhook"
      exit 0
      ;;
    s)
      type='slack'
      shift
      ;;
    \?)
      exit 1
  esac
done

current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ -n "$1" ]; then from=$1; else from=$target_branch; fi
if [ -n "$2" ]; then to=$2; else to=$current_branch; fi
if [ -z "$from" ]; then
  echo "target branch is required. run \`ballantine init\` or set target branch to argument."
  exit 1
fi
diff_commits $type $from $to
