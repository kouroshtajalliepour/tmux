#!/usr/bin/env bash
# The lone alt tap (scripts/alt_toggle.sh) and prefix+o (tmux): show the
# project you're in, on workspace 10 (alt+0).
#
# The project is the tmux session: $1 when tmux passes it (prefix+o),
# otherwise the session of the tmux client you used last (the alt tap). It's
# looked up in ~/.jarvis/session-bios.tsv - one row per session:
#   <session> <TAB> <kind> <TAB> <args...>
# and handed to scripts/preview/<kind>.sh (vue today; a Unity project
# would be a unity.sh). A session with no row isn't a previewable
# project: the alt tap does nothing, prefix+o ($2 = --picker) opens the port
# picker instead.
dir="$(cd "$(dirname "$0")" && pwd)"
# $3: the tmux client that pressed prefix+o, so messages and the popup land on it
[ -n "$3" ] && export TMUX_CLIENT=$3
source "$dir/preview/lib.sh"

session=$1
if [ -z "$session" ]; then
  session=$(tmux list-clients -F '#{client_activity} #{session_name}' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
fi
[ -z "$session" ] && exit 0

row=$(awk -F'\t' -v s="$session" '$1 == s && $0 !~ /^#/' "$PREVIEW_REGISTRY" 2>/dev/null | head -1)
if [ -z "$row" ]; then
  [ "$2" = "--picker" ] && tmux display-popup ${TMUX_CLIENT:+-c "$TMUX_CLIENT"} -w 60% -h 50% -T " Open port " -E "$dir/port_open.sh"
  exit 0
fi

IFS=$'\t' read -r -a fields <<<"$row"
kind=${fields[1]}
if [ ! -x "$dir/preview/$kind.sh" ]; then
  preview_msg "preview: no handler for kind '$kind' ($session)"
  exit 1
fi
exec "$dir/preview/$kind.sh" "$session" "${fields[@]:2}"
