#!/usr/bin/env bash
# Shared helpers for the project-session scripts (sourced, not run directly).
source "$(dirname "${BASH_SOURCE[0]}")/fzf_common.sh"

# Prints the window index in session $1 whose name is exactly $2, or
# nothing if there isn't one.
project_window_index() {
  tmux list-windows -t "$1" -F '#{window_index} #{window_name}' 2>/dev/null \
    | awk -v n="$2" '$2 == n {print $1; exit}'
}

# True if $1 has no .git of its own but at least one child directory does
# (either a real .git directory - a full checkout - or a .git file - a
# linked worktree). That's a "worktree container": a project folder whose
# branches each live in their own subdirectory, api-generator-system
# style, rather than one shared working tree.
is_worktree_container() {
  local dir="$1" child
  [ -e "$dir/.git" ] && return 1
  for child in "$dir"/*/; do
    [ -e "${child}.git" ] && return 0
  done
  return 1
}

# Prints the one child of a worktree container whose .git is a real
# directory (the main checkout - every linked worktree's .git is a text
# file pointing back at this one). Git commands for the container
# (fetch, worktree add, branch listing) run against this directory.
find_main_worktree() {
  local container="$1" child
  for child in "$container"/*/; do
    [ -d "${child}.git" ] && { printf '%s\n' "${child%/}"; return 0; }
  done
  return 1
}

# fzf-pick a branch of the repo at $1 (local or remote), or type a brand
# new name to create one. Prints the chosen/typed branch name on success;
# prints nothing and returns non-zero if the picker was cancelled
# (Escape/Ctrl-C) - callers must treat that as "do nothing at all".
pick_or_create_branch() {
  local main_dir="$1"
  fzf_vim_nav_args " Branch  "

  git -C "$main_dir" fetch --quiet --all 2>/dev/null

  local local_branches remote_branches candidates result status query selected
  local_branches=$(git -C "$main_dir" branch --format='%(refname:short)' 2>/dev/null)
  remote_branches=$(git -C "$main_dir" branch -r --format='%(refname:short)' 2>/dev/null | grep -v 'HEAD' | sed 's#^origin/##')
  candidates=$(printf '%s\n%s\n' "$local_branches" "$remote_branches" | sed '/^$/d' | sort -u)

  result=$(printf '%s\n' "$candidates" | fzf \
    --prompt=" Branch  " \
    --border=rounded \
    --height=100% \
    --layout=reverse \
    --info=inline \
    --print-query \
    "${FZF_VIM_NAV_ARGS[@]}" \
    --color="$FZF_CATPPUCCIN_COLOR")
  status=$?

  [ "$status" -eq 130 ] && return 1

  query=$(printf '%s\n' "$result" | sed -n '1p')
  selected=$(printf '%s\n' "$result" | sed -n '2p')

  if [ -n "$selected" ]; then
    printf '%s\n' "$selected"
  elif [ -n "$query" ]; then
    printf '%s\n' "$query"
  else
    return 1
  fi
}

# Builds (if it doesn't already exist) the standard project window layout
# - 0:main 7:code 8:term 9:ai - in $1, as session $2, and switches to it.
# $3 is the project name shown in the ai window's claude session name
# (see ai_launch.sh - for a worktree branch dir this is the container's
# name, not the branch directory's own name).
build_project_session() {
  local dir="$1" session="$2" project_name="$3"

  tmux has-session -t "$session" 2>/dev/null
  if [ $? != 0 ]; then
    tmux new-session -d -s "$session" -n main -c "$dir"
    tmux set-option -t "$session" renumber-windows off
    tmux new-window -t "${session}:7" -n code -c "$dir"
    tmux new-window -t "${session}:8" -n term -c "$dir"
    tmux new-window -t "${session}:9" -n ai -c "$dir"
    "$(dirname "${BASH_SOURCE[0]}")/ai_launch.sh" "$dir" "${session}:9" "$project_name"
    tmux select-window -t "${session}:7"
  fi

  tmux switch-client -t "$session"
}

# One-time conversion of a plain single-checkout repo at $1 into a
# worktree container: the currently checked-out branch's entire contents
# (including .git, uncommitted/untracked files and all - nothing is
# cloned fresh, just moved) go into $1/<branch-dir>/, leaving $1 itself
# as the now-empty container. Prints the branch directory name.
convert_to_worktree_container() {
  local dir="$1" branch branch_dir tmp

  branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null)
  [ -z "$branch" ] && branch=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)
  branch_dir=$(basename "$branch")

  tmp="${dir}.pclone-tmp.$$"
  mv "$dir" "$tmp"
  mkdir "$dir"
  mv "$tmp" "$dir/$branch_dir"

  tmux display-message "Converted $(basename "$dir") to worktree layout (branch: ${branch})"
  printf '%s\n' "$branch_dir"
}
