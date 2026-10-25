#!/usr/bin/env bash
# prefix+s: fuzzy-pick a window across all sessions (not just the session
# itself), shown as "index-session/window", e.g. "1-sys/network" — so you
# can search by window name too, and land directly on it. Project
# sessions' (p-*) boilerplate code/term/ai windows are hidden here since
# they're always the same and just add noise; reach those via prefix+S or
# prefix+B instead. A project's main window and any extra windows you add
# yourself still show up normally.
source "$(dirname "$0")/fzf_common.sh"
fzf_vim_nav_args " Window  "

current=$(tmux display-message -p '#S')

rows=$(tmux list-windows -a -F '#{session_name}	#{window_index}	#{window_name}	#{window_active}' \
  | awk -F'\t' '!( $1 ~ /^p-/ && ($3 == "code" || $3 == "term" || $3 == "ai") )' \
  | awk -F'\t' '{active = ($4 == 1) ? " (active)" : ""; printf "%s:%s\t%s-%s/%s%s\n", $1, $2, $2, $1, $3, active}')

selected=$(printf '%s\n' "$rows" | fzf \
  --prompt=" Window  " \
  --pointer="▶" \
  --border=rounded \
  --height=100% \
  --layout=reverse \
  --info=inline \
  --header="current: ${current}" \
  --delimiter=$'\t' \
  --with-nth=2.. \
  "${FZF_VIM_NAV_ARGS[@]}" \
  --color="$FZF_CATPPUCCIN_COLOR")

[ -z "$selected" ] && exit 0

target=${selected%%$'\t'*}
session=${target%%:*}
index=${target##*:}

tmux switch-client -t "$session"
tmux select-window -t "${session}:${index}"
