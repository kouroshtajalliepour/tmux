#!/usr/bin/env bash
# The i3 alt+` drop-down terminal (~/.config/i3/scripts/toggle_scratch.sh
# launches alacritty with `dropdown.sh attach`). It remembers which
# session you last chose for it:
#   - a session already chosen (and running): it attaches straight there
#   - nothing chosen yet (or it isn't running anymore): it attaches to Sys
#     and opens the prefix+m hub on top, so you pick one
#   - whatever the drop-down's client switches to from then on (hub,
#     pickers, pins, prefix+j/k) becomes its session - the
#     client-session-changed hook in project.conf calls `record`. To
#     choose again, press prefix+m inside the drop-down.
# It's a plain attach to the real session (no grouped copy), so a
# drop-down on Sys mirrors the main terminal's Sys.
#
#   attach                       what the drop-down terminal runs
#   record <client_tty> <name>   hook: remember <name> if <client_tty> is
#                                the drop-down's client

STATE="$HOME/.cache/tmux-dropdown-session"
ROOT="$(cd "$(dirname "$0")" && pwd)"

case "$1" in
attach)
  # The tty this script runs on is the one the tmux client below will
  # report as #{client_tty} - that's how `record` tells the drop-down
  # apart from the main terminal. Needs a running server with Sys in it:
  # start one normally first (the config load lets resurrect/continuum
  # restore Sys with its saved panes), and only force-create Sys if it
  # still isn't there after a few seconds.
  if ! tmux has-session -t =Sys 2>/dev/null; then
    tmux start-server
    for _ in $(seq 1 30); do
      tmux has-session -t =Sys 2>/dev/null && break
      sleep 0.1
    done
    tmux has-session -t =Sys 2>/dev/null || "$HOME/.config/tmux/bootstrap_sys.sh" --force
  fi
  tmux set-option -g @dropdown_client "$(tty)"

  target=""
  [ -f "$STATE" ] && target=$(cat "$STATE")
  if [ -n "$target" ] && tmux has-session -t "=$target" 2>/dev/null; then
    exec tmux attach-session -t "=$target"
  fi
  exec tmux attach-session -t =Sys \; display-popup -B -w 100% -h 100% -E "$ROOT/category_hub.sh"
  ;;

record)
  [ -n "$2" ] && [ -n "$3" ] || exit 0
  [ "$2" = "$(tmux show-option -gqv @dropdown_client)" ] || exit 0
  mkdir -p "$(dirname "$STATE")"
  printf '%s' "$3" > "$STATE"
  ;;
esac
