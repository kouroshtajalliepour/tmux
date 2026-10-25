#!/usr/bin/env bash
# prefix+s: fuzzy-pick an existing tmux session instead of tmux's built-in
# choose-tree.
current=$(tmux display-message -p '#S')

selected=$(tmux list-sessions -F '#{session_name}' | fzf \
  --prompt=" Session  " \
  --pointer="▶" \
  --border=rounded \
  --height=100% \
  --layout=reverse \
  --info=inline \
  --header="current: ${current}" \
  --color="bg+:#313244,bg:#1e1e2e,fg:#cdd6f4,fg+:#ffffff,hl:#cba6f7,hl+:#cba6f7,border:#cba6f7,prompt:#cba6f7,pointer:#cba6f7,marker:#cba6f7,spinner:#cba6f7,header:#9399b2,info:#9399b2")

[ -z "$selected" ] && exit 0

tmux switch-client -t "$selected"
