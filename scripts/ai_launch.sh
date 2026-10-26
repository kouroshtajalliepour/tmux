#!/usr/bin/env bash
# Starts or resumes the right named claude conversation ("project:branch")
# for a project root, in the given tmux window — but only if that window
# is actually idle. Never injects keystrokes into a window that's already
# running something (e.g. a live claude session), since that would type
# into it instead of running a command. $3 is an optional explicit
# project name - needed for worktree branch dirs, where basename($1)
# would just be the branch directory's own name again (e.g. "class-api"),
# not the actual container project's name.
root="$1"
target="$2"
project="${3:-$(basename "$root")}"

cmd=$(tmux display-message -p -t "$target" '#{pane_current_command}' 2>/dev/null)
case "$cmd" in
bash | zsh | sh | "") ;;
*)
  tmux display-message "ai window is busy (running ${cmd}), left it alone"
  exit 0
  ;;
esac

branch=$(git -C "$root" symbolic-ref --short HEAD 2>/dev/null)
[ -z "$branch" ] && branch=$(git -C "$root" rev-parse --short HEAD 2>/dev/null)
name="${project}:${branch:-no-branch}"

marker_dir="$HOME/.cache/tmux-ai-sessions"
mkdir -p "$marker_dir"
marker="$marker_dir/${name//\//_}"

tmux send-keys -t "$target" "cd \"$root\"" Enter

if [ -f "$marker" ]; then
  tmux send-keys -t "$target" "claude --resume \"$name\"" Enter
else
  tmux send-keys -t "$target" "claude --name \"$name\"" Enter
  touch "$marker"
fi
