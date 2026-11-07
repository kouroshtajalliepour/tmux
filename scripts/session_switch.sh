#!/usr/bin/env bash
# prefix+f: fuzzy-pick a window by name across the sessions (on production
# that's just the host session). Only the window name is shown, so it reads like a
# flat list of everything open.
source "$(dirname "$0")/fzf_common.sh"
fzf_vim_nav_args " Search  "

current=$(tmux display-message -p '#S')

rows=$(tmux list-windows -a -F '#{session_name}	#{window_index}	#{window_name}	#{window_active}' \
  | awk -F'\t' '$1 !~ /^p-/' \
  | awk -F'\t' '{active = ($4 == 1) ? " (active)" : ""; printf "%s:%s\t%s%s\n", $1, $2, $3, active}')

selected=$(printf '%s\n' "$rows" | fzf \
  --exact \
  --prompt=" Search  " \
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
