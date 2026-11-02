#!/usr/bin/env bash
# prefix+p: switch between the last main session (Sys/Infra/Media/Todos)
# and the last code session (j-/l-/lr-) you were in. From a main session
# it goes back to your last code session; from anywhere else it goes back
# to your last main session (Sys if there's none yet).
#
#   record <session>   client-session-changed hook (project.conf): remember
#                      <session> as the last main or last code session
#   toggle             prefix+p
#
# Kept in global options @last_main / @last_code, so they reset with the
# server.

source "$(dirname "$0")/project_lib.sh"

case "$1" in
record)
  [ -n "$2" ] || exit 0
  if is_main_session "$2"; then
    tmux set-option -g @last_main "$2"
  else
    case "$2" in j-*|l-*|lr-*) tmux set-option -g @last_code "$2" ;; esac
  fi
  ;;

toggle)
  current=$(tmux display-message -p '#S')
  # remember where we're leaving from too, in case the hook never saw us
  # arrive (e.g. sessions entered before this config was loaded)
  "$0" record "$current"
  if is_main_session "$current"; then
    target=$(tmux show-option -gqv @last_code)
    if [ -z "$target" ]; then
      tmux display-message "No recent code session - prefix+f lists your pins"
      exit 0
    fi
    # closed since? rebuild it if it's pinned, like picking it in prefix+f
    if ! tmux has-session -t "=$target" 2>/dev/null; then
      if pinned "$target"; then
        exec "$(dirname "$0")/pins.sh" open "$target"
      fi
      tmux display-message "$target isn't running anymore - prefix+f lists your pins"
      exit 0
    fi
  else
    target=$(tmux show-option -gqv @last_main)
    tmux has-session -t "=${target:-Sys}" 2>/dev/null || target=Sys
    target=${target:-Sys}
  fi
  tmux switch-client -t "=$target"
  ;;
esac
