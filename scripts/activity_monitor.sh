#!/usr/bin/env bash
# Background poller, started once via run-shell -b in project.conf. Every
# ~2s it snapshots every pane of every Packages/live-websites session
# (j-/l-/lr-) and works out a busy -> done transition per pane:
#   - content changed on BUSY_POLLS polls in a row -> busy (something is
#     actually animating/streaming, not just a one-off redraw).
#   - busy, then unchanged for IDLE_POLLS polls -> done: sets the window
#     option @done, unless that window is on screen right now (you
#     already watched it finish).
#   - a pane resize re-baselines instead of counting as movement.
# theme.conf's window-status-format reads @done directly (#{?@done,*,}),
# the pickers read it via project_lib.sh's session_done, and the
# pane-focus-in hook in theme.conf unsets it once you focus the window.
#
# Guarded against running twice (e.g. after a config reload) via a
# pidfile, and exits on its own once the tmux server is gone, so the next
# server start gets a fresh copy.

PIDFILE="$HOME/.cache/tmux-activity-monitor.pid"
POLL=2
BUSY_POLLS=2
IDLE_POLLS=2

mkdir -p "$(dirname "$PIDFILE")"
if [ -f "$PIDFILE" ]; then
  old=$(cat "$PIDFILE")
  if [ -n "$old" ] && kill -0 "$old" 2>/dev/null \
    && grep -q activity_monitor "/proc/$old/cmdline" 2>/dev/null; then
    exit 0
  fi
fi
echo $$ > "$PIDFILE"

declare -A content size changed idle busy seen

while sleep "$POLL"; do
  panes=$(tmux list-panes -a -F '#{session_name}	#{pane_id}	#{window_id}	#{pane_width}x#{pane_height}	#{?#{&&:#{session_attached},#{window_active}},1,0}' 2>/dev/null) || exit 0

  seen=()
  while IFS=$'\t' read -r session pane win sz visible; do
    case "$session" in
    j-*|l-*|lr-*) ;;
    *) continue ;;
    esac
    seen[$pane]=1

    now=$(tmux capture-pane -p -t "$pane" 2>/dev/null) || continue

    if [ "${size[$pane]}" != "$sz" ]; then
      size[$pane]=$sz
      content[$pane]=$now
      changed[$pane]=0
      idle[$pane]=0
      continue
    fi

    if [ "$now" != "${content[$pane]}" ]; then
      content[$pane]=$now
      changed[$pane]=$(( ${changed[$pane]:-0} + 1 ))
      idle[$pane]=0
      if [ "${changed[$pane]}" -ge "$BUSY_POLLS" ] && [ "${busy[$pane]}" != 1 ]; then
        busy[$pane]=1
        tmux set-option -wu -t "$win" @done 2>/dev/null
      fi
    else
      changed[$pane]=0
      idle[$pane]=$(( ${idle[$pane]:-0} + 1 ))
      if [ "${busy[$pane]}" = 1 ] && [ "${idle[$pane]}" -ge "$IDLE_POLLS" ]; then
        busy[$pane]=0
        [ "$visible" = 1 ] || tmux set-option -w -t "$win" @done 1 2>/dev/null
      fi
    fi
  done <<< "$panes"

  # Forget panes that have since closed.
  for pane in "${!size[@]}"; do
    [ -n "${seen[$pane]}" ] && continue
    unset "size[$pane]" "content[$pane]" "changed[$pane]" "idle[$pane]" "busy[$pane]"
  done
done
