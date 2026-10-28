#!/usr/bin/env bash
# Background poller, started once via run-shell -b in project.conf: every
# ~2s, snapshots each Packages/live-websites session's "ai" window (9)
# and diffs it against the previous snapshot.
#   - content changed since last poll -> busy, clear any "done" flag.
#   - content unchanged, but it WAS busy last poll -> touch a "done"
#     flag file.
# theme.conf's window-status-format and branch_picker.sh both just read
# that flag file - the expensive diff-check happens here, once, in the
# background, not on every status-bar redraw or every picker-open.
#
# Guarded against running twice (e.g. after a config reload) via a pidfile.

PIDFILE="$HOME/.cache/tmux-activity-monitor.pid"
DONE_DIR="$HOME/.cache/tmux-session-done"
SNAP_DIR="$HOME/.cache/tmux-session-snapshot"

mkdir -p "$DONE_DIR" "$SNAP_DIR"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  exit 0
fi
echo $$ > "$PIDFILE"

while true; do
  sleep 2

  while IFS= read -r session; do
    [ -z "$session" ] && continue

    pane_id=$(tmux list-panes -t "${session}:9" -F '#{pane_id}' 2>/dev/null | head -1)
    [ -z "$pane_id" ] && continue

    snap_file="$SNAP_DIR/$session"
    done_file="$DONE_DIR/$session"

    current=$(tmux capture-pane -t "$pane_id" -p 2>/dev/null)
    previous=""
    [ -f "$snap_file" ] && previous=$(cat "$snap_file")

    if [ "$current" != "$previous" ]; then
      rm -f "$done_file"
    else
      [ -f "$done_file" ] || touch "$done_file"
    fi
    printf '%s' "$current" > "$snap_file"
  done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep -E '^(j-|l-|lr-)')
done
