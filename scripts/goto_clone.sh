#!/usr/bin/env bash
# prefix+n: jump to the Sys session's "Documents" window and run the
# generalized cloner there (same as prefix+C - pick a folder under
# ~/Documents, paste the URL, multi-select which branches to worktree).
# Overrides tmux's default next-window binding.
tmux switch-client -t Sys
tmux select-window -t Sys:Documents
tmux send-keys -t Sys:Documents "~/.config/tmux/scripts/doc_clone.sh" Enter
