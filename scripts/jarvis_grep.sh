#!/usr/bin/env bash
# prefix+y: copy a ready-to-edit report search to the clipboard and tmux buffer.
cmd="nvim (ls ~/.jarvis/* | grep -i CHANGE_ME)"

printf '%s' "$cmd" | tmux load-buffer -
printf '%s' "$cmd" | xclip -selection clipboard >/dev/null 2>&1
tmux display-message "Copied: $cmd"
