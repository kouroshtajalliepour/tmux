#!/usr/bin/env bash
# tmux-resurrect post-restore hook. Fill in any of the 4 main sessions the
# restore didn't bring back, then snap Sys's `main` window back to $HOME,
# even if it was saved sitting in some other directory.
"$HOME/.config/tmux/bootstrap_sys.sh" --force
tmux has-session -t =Sys 2>/dev/null && tmux send-keys -t =Sys:main "cd $HOME" Enter
