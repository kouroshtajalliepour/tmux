#!/usr/bin/env bash
# prefix+p: switch between the last main session (Sys/Infra/Media/Todos)
# and the last code session (j-/l-/lr-) you were in. From a main session
# it goes back to your last code session (or the first pin, started if
# needed, when there's none yet - e.g. after a boot); from anywhere else it goes back
# to your last main session (Sys if there's none yet).
#
#   record <session>   client-session-changed hook (project.conf): remember
#                      <session> as the last main or last code session
#   toggle [session] [client]
#                      prefix+p (the binding passes '#{session_name}'
#                      '#{client_name}' - see client_switch in project_lib.sh)
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
    is_code_session "$2" && tmux set-option -g @last_code "$2"
  fi
  ;;

toggle)
  [ -n "$3" ] && export TMUX_CLIENT="$3"
  current=$(current_session "$2")
  # remember where we're leaving from too, in case the hook never saw us
  # arrive (e.g. sessions entered before this config was loaded)
  "$0" record "$current"
  if is_main_session "$current"; then
    target=$(tmux show-option -gqv @last_code)
    # no recent code session (e.g. right after a boot), or it's gone and
    # no longer pinned: go to the first pin instead
    if [ -z "$target" ] || { ! tmux has-session -t "=$target" 2>/dev/null && ! pinned "$target"; }; then
      if ! target=$(first_pin); then
        client_msg "No pins yet - prefix+a pins the current session"
        exit 0
      fi
    fi
    # not running? start it, like picking it in prefix+f
    if ! tmux has-session -t "=$target" 2>/dev/null; then
      exec "$(dirname "$0")/pins.sh" open "$target" "$TMUX_CLIENT"
    fi
  else
    target=$(tmux show-option -gqv @last_main)
    tmux has-session -t "=${target:-Sys}" 2>/dev/null || target=Sys
    target=${target:-Sys}
  fi
  client_switch "$target"
  ;;
esac
