#!/usr/bin/env bash
# prefix+j / prefix+k: next / previous session, depending on where you are:
#   - in one of the main 4 (Sys/Infra/Media/Todos): cycle the main 4
#   - anywhere else: cycle your pinned sessions (pins.sh, prefix+f) in pin
#     order, skipping the main 4 - running or not. A pin that isn't
#     running (e.g. right after a boot - only the main 4 are restored) is
#     started on arrival, rebuilt from its saved directory. Pins whose
#     directory is gone are skipped.
# Wraps around both ways. From a session that isn't in the list, next
# goes to the first entry and prev to the last. Shows "pin 2/5: name" /
# "main 1/4: Sys" after the switch, plus "(started)" when it had to
# build the session.
#
# $1 = next | prev
# $2 = the session the key was pressed in, $3 = that client - the
#      binding passes '#{session_name}' '#{client_name}' (see
#      client_switch in project_lib.sh)

source "$(dirname "$0")/project_lib.sh"

[ -n "$3" ] && export TMUX_CLIENT="$3"
current=$(current_session "$2")

list=()
if is_main_session "$current"; then
  kind=main
  for s in $MAIN_SESSIONS; do
    tmux has-session -t "=$s" 2>/dev/null && list+=("$s")
  done
else
  kind=pin
  if [ -f "$PIN_FILE" ]; then
    while IFS=$'\x1f' read -r s dir; do
      [ -z "$s" ] && continue
      is_main_session "$s" && continue
      if tmux has-session -t "=$s" 2>/dev/null || { [ -n "$dir" ] && [ -d "$dir" ]; }; then
        list+=("$s")
      fi
    done < <(awk -F'\t' '{print $1 "\x1f" $2}' "$PIN_FILE")
  fi
fi

n=${#list[@]}
if [ "$n" -eq 0 ]; then
  client_msg "No pins yet - prefix+a pins the current session"
  exit 0
fi

idx=-1
for i in "${!list[@]}"; do
  [ "${list[$i]}" = "$current" ] && idx=$i && break
done

if [ "$idx" -ge 0 ] && [ "$n" -eq 1 ]; then
  client_msg "Only $kind: $current"
  exit 0
fi

if [ "$1" = prev ]; then
  if [ "$idx" -lt 0 ]; then target=$((n - 1)); else target=$(((idx - 1 + n) % n)); fi
else
  if [ "$idx" -lt 0 ]; then target=0; else target=$(((idx + 1) % n)); fi
fi

session=${list[$target]}
label=$(session_label "$session")

if tmux has-session -t "=$session" 2>/dev/null; then
  client_switch "$session"
  client_msg "$kind $((target + 1))/$n: $label"
else
  "$(dirname "$0")/pins.sh" open "$session" "$TMUX_CLIENT" || exit 0
  client_msg "$kind $((target + 1))/$n: $label (started)"
fi
