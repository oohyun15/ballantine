#!/bin/bash
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