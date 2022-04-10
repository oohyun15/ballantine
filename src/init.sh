#!/bin/bash
function init() {
  echo "🍹 Init ballantine configuration"

  echo "Q. Set default target branch (ex. production)"
  echo -n "> "
  read -r default_branch

  echo "Q. Set slack webhook (optional)"
  echo -n "> "
  read -r webhook

  rm ~/.blntrc &> /dev/null
  touch ~/.blntrc
  echo "default_branch=$default_branch" >> ~/.blntrc
  echo "webhook=$webhook" >> ~/.blntrc

  exit 0
}
