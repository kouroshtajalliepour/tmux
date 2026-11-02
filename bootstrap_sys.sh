#!/bin/bash
# Makes sure the 4 main sessions (Sys, Infra, Media, Todos) exist. Only
# creates the ones that are missing, so it's safe to run any time.
#
# At config load (no args) it stays out of the way when there's a
# tmux-resurrect save to restore from - creating sessions before the
# restore would stop resurrect from restoring their saved panes. The
# post-restore hook (post_restore.sh) and pins.sh's destroy call it with
# --force instead, to fill in anything the restore didn't bring back.

if [ "$1" != "--force" ] && [ -e "$HOME/.local/share/tmux/resurrect/last" ]; then
  exit 0
fi

if ! tmux has-session -t =Sys 2>/dev/null; then
  tmux new-session -d -s Sys -n main -c "$HOME"
  tmux new-window -t =Sys: -n vpn
  tmux new-window -t =Sys: -n networking
  tmux new-window -t =Sys: -n ssh
  tmux new-window -t =Sys: -n logs
fi

tmux has-session -t =Infra 2>/dev/null || tmux new-session -d -s Infra -c "$HOME"
tmux has-session -t =Media 2>/dev/null || tmux new-session -d -s Media -c "$HOME"
if ! tmux has-session -t =Todos 2>/dev/null; then
  todos_dir="$HOME/Todos"
  [ -d "$todos_dir" ] || todos_dir="$HOME"
  tmux new-session -d -s Todos -c "$todos_dir"
fi
