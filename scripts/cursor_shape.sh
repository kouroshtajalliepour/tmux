#!/usr/bin/env bash
# Called from the pane-mode-changed / pane-focus-in hooks. Switches the
# terminal cursor to a block while a pane is in copy-mode (or any other
# tmux "mode"), and back to a blinking bar otherwise.
tty="$1"
in_mode="$2"

[ -w "$tty" ] || exit 0

if [ "$in_mode" = "1" ]; then
  printf '\e[1 q' > "$tty" # blinking block
else
  printf '\e[5 q' > "$tty" # blinking bar
fi
