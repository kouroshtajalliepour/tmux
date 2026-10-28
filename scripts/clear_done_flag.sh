#!/usr/bin/env bash
# pane-focus-in hook (see project.conf): if you just focused window 9
# ("ai") of a Packages/live-websites session, clear that session's
# "done" marker from activity_monitor.sh - you've seen it now.
session="$1"
window_index="$2"

[ "$window_index" = "9" ] || exit 0

case "$session" in
j-*|l-*|lr-*) rm -f "$HOME/.cache/tmux-session-done/$session" ;;
esac
