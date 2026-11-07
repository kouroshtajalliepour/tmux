#!/usr/bin/env bash
# tmux-resurrect post-restore hook. The host session's `main` window should
# always land on $HOME, even if it was saved sitting in some other directory.
name=$(tmux display-message -p "#{host_short}")
name=${name//[.:]/_}
tmux has-session -t "=$name" 2>/dev/null && tmux send-keys -t "$name:main" "cd $HOME" Enter
