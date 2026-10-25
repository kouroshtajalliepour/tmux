#!/usr/bin/env bash
# prefix+s: fuzzy-pick a window across your saved sessions (not just the
# session itself), shown as "session/window" — so you can search by
# window name too, and land directly on it. Project sessions (p-*) are
# excluded entirely here, since they're ad-hoc and rebuilt on demand by
# tmux-sessionizer, not part of the saved roster; reach those via
# prefix+S or prefix+B instead.
source "$(dirname "$0")/fzf_common.sh"
fzf_vim_nav_args " Window  "

current=$(tmux display-message -p '#S')

rows=$(tmux list-windows -a -F '#{session_name}	#{window_index}	#{window_name}	#{window_active}' \
  | awk -F'\t' '$1 !~ /^p-/' \
  | awk -F'\t' '{active = ($4 == 1) ? " (active)" : ""; printf "%s:%s\t%s/%s%s\n", $1, $2, $1, $3, active}')

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
