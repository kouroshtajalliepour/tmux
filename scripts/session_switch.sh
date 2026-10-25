#!/usr/bin/env bash
# prefix+s: fuzzy-pick an existing tmux session instead of tmux's built-in
# choose-tree.
source "$(dirname "$0")/fzf_common.sh"
fzf_vim_nav_args " Session  "

current=$(tmux display-message -p '#S')

selected=$(tmux list-sessions -F '#{session_name}' | fzf \
  --prompt=" Session  " \
  --pointer="▶" \
  --border=rounded \
  --height=100% \
  --layout=reverse \
  --info=inline \
  --header="current: ${current}" \
  "${FZF_VIM_NAV_ARGS[@]}" \
  --color="$FZF_CATPPUCCIN_COLOR")

[ -z "$selected" ] && exit 0

tmux switch-client -t "$selected"
