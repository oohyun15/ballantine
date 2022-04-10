#!/bin/bash
function diff_commits () {
  # set arguements
  TYPE=$1
  FROM=$2
  TO=$3
  if [[ $TYPE != 'slack' && $TYPE != 'bash' && $TYPE != 'terminal' ]]; then
    echo "\$1 argument($TYPE) must be of slack, terminal(or bash)"
    exit 1
  fi

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
    SUB_PATH=(`cat .gitmodules | grep path | awk '/path/{print $3}'`)
  else
    SUB_PATH=()
  fi
  MAIN_URL=$(github_url `git config --get remote.origin.url`)
  CUR_BRANCH=`git rev-parse --abbrev-ref HEAD`

  # get commit hash
  git checkout $from -f &> /dev/null
  git pull -f &> /dev/null
  MAIN_FROM=`git --no-pager log -1 --format='%h'`
  SUB_FROM=(`git ls-tree HEAD $SUB_PATH | awk '/commit/{print $3}' | tr '\r\n' ' ' | xargs`)
  git checkout $to -f &> /dev/null
  git pull -f &> /dev/null
  MAIN_TO=`git --no-pager log -1 --format='%h'`
  SUB_TO=(`git ls-tree HEAD $SUB_PATH | awk '/commit/{print $3}' | tr '\r\n' ' ' | xargs`)
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

  curl -X POST --data-urlencode "payload={\"text\":\":check: *$APP_NAME* deployment request by <@${ACTOR}> (\`<$MAIN_URL/tree/$FROM|$FROM>\` <- \`<$MAIN_URL/tree/$TO|$TO>\` <$MAIN_URL/compare/$FROM...$TO|compare>)\n:technologist: Author: $NUMBER\nLast commit: $LAST_COMMIT\",\"attachments\":[${MESSAGE}]}" $WEBHOOK
}

function send_to_terminal () {
  printf "Check commits before ${RED}${APP_NAME}${NC} deployment.\n"
  printf "${YELLOW}Author${NC}: ${NUMBER}\n"
  printf "${BLUE}Last Commit${NC}: ${LAST_COMMIT}\n"

  if [ $NUMBER == 0 ]; then exit; fi
  for log in $TMP_PATH/commit_log/*
  do
    author=`basename $log .log`
    echo -en "${GREEN}@${author}${NC}\n "
    echo -e $(cat $log)
  done
  rm -rf $TMP_PATH/commit_log
}
