#!/usr/bin/env bash
# tmux-resurrect post-restore hook. The `sys` session's `main` window should
# always land on $HOME, even if it was saved sitting in some other directory.
tmux has-session -t sys 2>/dev/null && tmux send-keys -t sys:main "cd $HOME" Enter
