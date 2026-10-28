#!/usr/bin/env bash
# prefix+k/l: open the full-screen branch picker (branch_picker.sh)
# scoped to the last-visited project in this category (Packages/
# live-websites), so you see every sibling branch's state before
# jumping, instead of silently landing wherever you left off. Falls
# back to the full project picker (same as prefix+K/L) if there's no
# last-visited project yet.
#
# $1 = category (j or l) $2 = picker root dir $3 = picker session
# prefix $4 = popup title $5 = popup border color
category="$1"
root="$2"
prefix="$3"
title="$4"
color="$5"

project_file="$HOME/.cache/tmux-last-session-project/$category"
last_session_file="$HOME/.cache/tmux-last-session/$category"

if [ -f "$project_file" ] && [ -f "$last_session_file" ]; then
  project_name=$(cat "$project_file")
  last_session=$(cat "$last_session_file")
  # the exact prefix used last time (j/l/lr) - not just the category -
  # since a wrapper-recursed repo (lr-*) needs its own prefix preserved,
  # not collapsed back to the category's plain "l".
  exact_prefix=${last_session%%-*}
  tmux display-popup -w 70% -h 70% -T " $project_name " -S "fg=$color" -E "$(dirname "$0")/branch_picker.sh '$project_name' $exact_prefix"
  exit 0
fi

tmux display-popup -w 70% -h 70% -T "$title" -S "fg=$color" -E "$(dirname "$0")/tmux-sessionizer '$root' $prefix"
