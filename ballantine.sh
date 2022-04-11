#!/bin/bash

NC='\033[0m'
GRAY='\033[1;30m'
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'

# function definition start

function init() {
  echo "🍹 Init ballantine configuration"

  echo "Q. Set default target branch (ex. production)"
  echo -n "> "
  read -r target_branch

  echo "Q. Set slack webhook (optional)"
  echo -n "> "
  read -r blnt_webhook

  rm ~/.blntrc &> /dev/null
  touch ~/.blntrc
  echo "target_branch=$target_branch" >> ~/.blntrc
  echo "blnt_webhook=$blnt_webhook" >> ~/.blntrc
  source ~/.blntrc &> /dev/null
  echo
  print_env
}

function manual() {
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
}

function print_env() {
  printf "target branch: ${GREEN}${target_branch}${NC}\n"
  if [ -n "$blnt_webhook" ]; then
    printf "slack webhook: ${GRAY}${blnt_webhook}${NC}\n"
  else
    printf "slack webhook: ${GRAY}undefined${NC}\n"
  fi
}

# reference: https://github.com/desktop/desktop/blob/a7bca44088b105a04714dc4628f4af50f6f179c3/app/src/lib/remote-parsing.ts#L27-L44
function github_url () {
  regexes=(
    '^https?://(.+)/(.+)/(.+)\.git/?$' # protocol: https -> https://github.com/oohyun15/ballantine.git | https://github.com/oohyun15/ballantine.git/
    '^https?://(.+)/(.+)/(.+)/?$'      # protocol: https -> https://github.com/oohyun15/ballantine | https://github.com/oohyun15/ballantine/
    '^git@(.+):(.+)/(.+)\.git$'        # protocol: ssh   -> git@github.com:oohyun15/ballantine.git
    '^git@(.+):(.+)/(.+)/?$'           # protocol: ssh   -> git@github.com:oohyun15/ballantine | git@github.com:oohyun15/ballantine/
    '^git:(.+)/(.+)/(.+)\.git$'        # protocol: ssh   -> git:github.com/oohyun15/ballantine.git
    '^git:(.+)/(.+)/(.+)/?$'           # protocol: ssh   -> git:github.com/oohyun15/ballantine | git:github.com/oohyun15/ballantine/
    '^ssh://git@(.+)/(.+)/(.+)\.git$'  # protocol: ssh   -> ssh://git@github.com/oohyun15/ballantine.git
  )

  for regex in "${regexes[@]}"; do
    if [[ "$1" =~ $regex ]]; then
      owner=${BASH_REMATCH[2]}
      repository=${BASH_REMATCH[3]}
      break
    fi
  done

  echo "https://github.com/${owner}/${repository}"
}

function diff_commits () {
  # set arguements
  TYPE=$1
  FROM=$2
  TO=$3

  # check arguement is tag
  local from=$(check_tag $FROM)
  local to=$(check_tag $TO)

  # stash uncommitted codes & check commits are newest
  git stash save &> /dev/null
  git pull -f &> /dev/null
  TMP_PATH='/tmp'
  mkdir $TMP_PATH/commit_log &> /dev/null
  MAIN_PATH=`pwd`
  if test -f '.gitmodules'; then
    SUB_PATH=(`cat .gitmodules | grep path | awk '/path/{print $3}' | sort -u`)
  else
    SUB_PATH=()
  fi
  MAIN_URL=$(github_url `git config --get remote.origin.url`)
  CUR_BRANCH=`git rev-parse --abbrev-ref HEAD`

  # get commit hash
  git checkout $from -f &> /dev/null
  git pull -f &> /dev/null
  MAIN_FROM=`git --no-pager log -1 --format='%h'`
  SUB_FROM=(`git ls-tree HEAD ${SUB_PATH[@]} | awk '/commit/{print $3}' | tr '\r\n' ' ' | xargs`)
  git checkout $to -f &> /dev/null
  git pull -f &> /dev/null
  MAIN_TO=`git --no-pager log -1 --format='%h'`
  SUB_TO=(`git ls-tree HEAD ${SUB_PATH[@]} | awk '/commit/{print $3}' | tr '\r\n' ' ' | xargs`)
  git checkout $CUR_BRANCH -f &> /dev/null
  # check main application's commits
  check_commits $MAIN_FROM $MAIN_TO $MAIN_URL

  # check submodules' commits
  LENGTH=${#SUB_PATH[@]}
  for ((i=0; i<${LENGTH}; i++)); do
    if [[ "${SUB_FROM[$i]}" == "${SUB_TO[$i]}" ]]; then continue; fi
    cd ${SUB_PATH[$i]}
    SUB_URL=$(github_url `git config --get remote.origin.url`)
    check_commits ${SUB_FROM[$i]} ${SUB_TO[$i]} $SUB_URL
    cd ../../..
  done

  # unstash uncommitted codes
  git stash apply &> /dev/null

  NUMBER=`ls $TMP_PATH/commit_log | wc -l | xargs`
  LAST_COMMIT=$(git --no-pager log --reverse --format="$(commit_format $MAIN_URL)" --abbrev=7 $MAIN_FROM..$MAIN_TO -1 | sed -e 's/"/\\"/g')

  if [ $NUMBER == 0 ]; then
    echo "ERROR: there is no commits between $FROM and $TO"
    exit 1
  fi

  # send slack to commit logs
  if [ $TYPE == 'slack' ]; then
    send_to_slack
  elif [[ $TYPE == 'bash' || $TYPE == 'terminal' ]]; then
    send_to_terminal
  fi
}

function check_tag () {
  if [[ `git tag -l | grep $1` ]]; then
    git fetch origin tag $1 -f &> /dev/null
    hash=`git rev-list -n 1 $1`
    hash=${hash:0:7}
  else
    hash=$1
  fi
  echo $hash
}

function commit_format () {
  local url=$1

  if [ $TYPE == 'slack' ]; then
    echo "\`<$url/commit/%H|%h>\` %s - %an"
  elif [[ $TYPE == 'bash' || $TYPE == 'terminal' ]]; then
    echo "- ${YELLOW}%h${NC} %s ${GRAY}${url}/commit/%H${NC}\n"
  fi
}

function check_commits () {
  local from=$1
  local to=$2
  local url=$3
  local repo=$(basename -s .git `git config --get remote.origin.url`)
  local authors=($(git --no-pager log --pretty=format:"%an" $from..$to | sed -e 's/ /-/g' | tr '\r\n' ' '))

  IFS=" " read -r -a authors <<< "$(tr ' ' '\n' <<< "${authors[@]}" | sort -u | tr '\n' ' ')"
  for author in ${authors[@]}; do
    local file="$TMP_PATH/commit_log/$author.log"
    local format=$(commit_format $url)
    local commits=$(git --no-pager log --reverse --no-merges --author=$author --format="$format" --abbrev=7 $from..$to | sed -e 's/"/\\"/g')

    if [ -z "$commits" ]; then continue; fi
    local count=$(echo "$commits" | wc -l | xargs)
    if [ $count == 1 ]; then var='commit'; else var='commits'; fi

    if [ $TYPE == 'slack' ]; then
      echo "*$repo*: $count new $var" >> $file
      echo "$commits" >> $file
      echo "" >> $file
    elif [[ $TYPE == 'bash' || $TYPE == 'terminal' ]]; then
      echo "> ${BLUE}$repo${NC}: $count new $var\n" >> $file
      echo "$commits" >> $file
    fi
  done
}

function send_to_slack () {
  # set message each author
  for log in $TMP_PATH/commit_log/*
  do
    author=`basename $log .log`
    MESSAGE+="{\"text\":\"- <@$author>\n$(cat $log)\",\"color\": \"#00B86A\"},"
  done

  # check script actor
  if [ -z ${GITHUB_ACTOR+x} ]; then
    ACTOR=`git config user.name`
  else
    ACTOR=$GITHUB_ACTOR
  fi
  ACTOR=`echo $ACTOR | sed -e 's/ /-/g'`
  rm -rf $TMP_PATH/commit_log

  curl -X POST --data-urlencode "payload={\"text\":\":check: *$APP_NAME* deployment request by <@${ACTOR}> (\`<$MAIN_URL/tree/$FROM|$FROM>\` <- \`<$MAIN_URL/tree/$TO|$TO>\` <$MAIN_URL/compare/$FROM...$TO|compare>)\n:technologist: Author: $NUMBER\nLast commit: $LAST_COMMIT\",\"attachments\":[${MESSAGE}]}" $blnt_webhook
}

function send_to_terminal () {
  printf "Check commits before ${RED}${APP_NAME}${NC} deployment.\n"
  printf "${YELLOW}Author${NC}: ${NUMBER}\n"
  printf "${BLUE}Last Commit${NC}: ${LAST_COMMIT}\n"

  for log in $TMP_PATH/commit_log/*
  do
    author=`basename $log .log`
    echo -en "${GREEN}@${author}${NC}\n "
    echo -e $(cat $log)
  done
  rm -rf $TMP_PATH/commit_log
}

# function definition end

if [[ $1 == 'init' ]]; then
  init
  exit 0
fi

source ~/.blntrc &> /dev/null
type='terminal'
while getopts "hos" opt; do
  case $opt in
    h)
      manual
      exit 0
      ;;
    o)
      print_env
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

if ! [ -d ".git" ]; then
  echo "ERROR: There is no \".git\" directory in `pwd`."
  exit 1
fi

APP_NAME=$(basename -s .git `git config --get remote.origin.url`)
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ -n "$1" ]; then from=$1; else from=$target_branch; fi
if [ -n "$2" ]; then to=$2; else to=$current_branch; fi
if [ -z "$from" ]; then
  echo "ERROR: target branch is required. run \`ballantine init\` or set target branch to argument."
  exit 1
fi
diff_commits $type $from $to
