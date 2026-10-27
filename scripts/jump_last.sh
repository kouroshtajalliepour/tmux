#!/usr/bin/env bash
# prefix+j/l: jump straight to the last-visited session in this
# category (Packages/live-websites) if there is one and it still
# exists; otherwise falls back to opening the full picker (same as
# prefix+J/L - the picker records the new last-visited session itself,
# via build_project_session, so this stays up to date automatically).
#
# $1 = category (j or l) $2 = picker root dir $3 = picker session
# prefix $4 = popup title $5 = popup border color
category="$1"
root="$2"
prefix="$3"
title="$4"
color="$5"

last_file="$HOME/.cache/tmux-last-session/$category"

if [ -f "$last_file" ]; then
  last_session=$(cat "$last_file")
  if tmux has-session -t "$last_session" 2>/dev/null; then
    tmux switch-client -t "$last_session"
    exit 0
  fi
fi

tmux display-popup -w 70% -h 70% -T "$title" -S "fg=$color" -E "$(dirname "$0")/tmux-sessionizer '$root' $prefix"
