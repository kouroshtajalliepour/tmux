#!/usr/bin/env bash
# prefix+m k/l (the hub, category_hub.sh): open the full-screen branch
# picker (branch_picker.sh) scoped to the last-visited project in this
# category (Packages/live-websites), so you see every sibling branch's
# state before jumping, instead of silently landing wherever you left
# off. Falls back to the full project picker (same as prefix+K/L) if
# there's no last-visited project yet.
#
# Runs the picker right here, in the current terminal, not in a new
# display-popup: the hub is already a popup, and tmux won't open a popup
# on top of another one - that's why hub k/l used to just close without
# showing anything. The picker fills the hub's full-screen popup instead,
# the same way hub K/L do.
#
# $1 = category (j or l) $2 = picker root dir $3 = picker session
# prefix. $4/$5 (popup title/border color) are still accepted from the
# hub's call but unused now that there's no popup of its own.
category="$1"
root="$2"
prefix="$3"

project_file="$HOME/.cache/tmux-last-session-project/$category"
last_session_file="$HOME/.cache/tmux-last-session/$category"

if [ -f "$project_file" ] && [ -f "$last_session_file" ]; then
  project_name=$(cat "$project_file")
  last_session=$(cat "$last_session_file")
  # the exact prefix used last time (j/l/lr) - not just the category -
  # since a wrapper-recursed repo (lr-*) needs its own prefix preserved,
  # not collapsed back to the category's plain "l".
  exact_prefix=${last_session%%-*}
  exec "$(dirname "$0")/branch_picker.sh" "$project_name" "$exact_prefix"
fi

exec "$(dirname "$0")/tmux-sessionizer" "$root" "$prefix"
