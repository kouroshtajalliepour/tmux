#!/usr/bin/env bash
# prefix+j / prefix+k: next / previous session, depending on where you are:
#   - in one of the main 4 (Sys/Infra/Media/Todos): cycle the main 4
#   - anywhere else: cycle the pinned sessions (pins.sh, prefix+g) that
#     are running, in pin order, skipping the main 4
# Wraps around both ways. From a session that isn't in the list, next
# goes to the first entry and prev to the last. Shows "pin 2/5: name" /
# "main 1/4: Sys" after the switch.
#
# $1 = next | prev

source "$(dirname "$0")/project_lib.sh"

current=$(tmux display-message -p '#S')

list=()
if is_main_session "$current"; then
  kind=main
  for s in $MAIN_SESSIONS; do
    tmux has-session -t "=$s" 2>/dev/null && list+=("$s")
  done
else
  kind=pin
  if [ -f "$PIN_FILE" ]; then
    while IFS= read -r s; do
      [ -z "$s" ] && continue
      is_main_session "$s" && continue
      tmux has-session -t "=$s" 2>/dev/null && list+=("$s")
    done < <(awk -F'\t' '{print $1}' "$PIN_FILE")
  fi
fi

n=${#list[@]}
if [ "$n" -eq 0 ]; then
  tmux display-message "No running pins - prefix+a pins the current session"
  exit 0
fi

idx=-1
for i in "${!list[@]}"; do
  [ "${list[$i]}" = "$current" ] && idx=$i && break
done

if [ "$idx" -ge 0 ] && [ "$n" -eq 1 ]; then
  tmux display-message "Only $kind running: $current"
  exit 0
fi

if [ "$1" = prev ]; then
  if [ "$idx" -lt 0 ]; then target=$((n - 1)); else target=$(((idx - 1 + n) % n)); fi
else
  if [ "$idx" -lt 0 ]; then target=0; else target=$(((idx + 1) % n)); fi
fi

session=${list[$target]}
case "$session" in
j-*|l-*|lr-*) label="${session#*-}" ;;
*) label="$session" ;;
esac

tmux switch-client -t "=$session"
tmux display-message "$kind $((target + 1))/$n: $label"
