#!/usr/bin/env bash
# Shared helpers for the project-session scripts (sourced, not run directly).
source "$(dirname "${BASH_SOURCE[0]}")/fzf_common.sh"

# Prints the window index in session $1 whose name is exactly $2, or
# nothing if there isn't one.
project_window_index() {
  tmux list-windows -t "$1" -F '#{window_index} #{window_name}' 2>/dev/null \
    | awk -v n="$2" '$2 == n {print $1; exit}'
}

# True if $1 is a "worktree container": a project folder whose branches
# each live in their own subdirectory, api-generator-system style,
# rather than one shared working tree.
#
# Shape alone can't tell this apart from "a plain folder that happens to
# have exactly one git-repo child" (e.g. ~/Documents/Packages itself,
# sitting right next to vue-kit) - both look identical when there's only
# one branch/checkout so far. So this is true only when EITHER:
#   - a child's .git is a FILE (unambiguous - that's a real linked
#     worktree, e.g. api-generator-system's class-api/docs/...), or
#   - $dir/.worktree-root exists (the explicit marker convert_to_
#     worktree_container and pclone both leave behind, for the common
#     case of a container that's only grown its first branch so far and
#     has no linked worktrees yet to prove it structurally).
is_worktree_container() {
  local dir="$1" child
  [ -e "$dir/.git" ] && return 1
  [ -e "$dir/.worktree-root" ] && return 0
  for child in "$dir"/*/; do
    [ -f "${child}.git" ] && return 0
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
  remote_branches=$(git -C "$main_dir" branch -r --format='%(refname:short)' 2>/dev/null | grep '^origin/' | sed 's#^origin/##')
  candidates=$(printf '%s\n%s\n' "$local_branches" "$remote_branches" | sed '/^$/d' | sort -u)

  result=$(printf '%s\n' "$candidates" | fzf \
    --exact \
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

# Resolves the CURRENT tmux session's project context - used by
# prefix+g/G, both of which only make sense inside a Packages/live-
# websites session. Prints "container\tproject_name\tmain_dir\tprefix"
# on success; on failure, shows why via tmux display-message and
# returns 1 - callers should just `|| exit 0` on this.
resolve_current_project() {
  local session vi_idx dir container project_name main_dir session_prefix
  session=$(tmux display-message -p '#S')

  case "$session" in
  j-*|l-*|lr-*) ;;
  *)
    tmux display-message "Only works in a Packages/live-websites session"
    return 1
    ;;
  esac

  vi_idx=$(project_window_index "$session" vi)
  if [ -z "$vi_idx" ]; then
    tmux display-message "Not a project session (needs a vi window)"
    return 1
  fi

  dir=$(tmux display-message -p -t "${session}:${vi_idx}" '#{pane_current_path}')
  container=$(dirname "$dir")

  if ! is_worktree_container "$container"; then
    tmux display-message "Not a worktree-container project"
    return 1
  fi

  project_name=$(basename "$container")
  main_dir=$(find_main_worktree "$container")
  session_prefix=${session%%-*}

  printf '%s\t%s\t%s\t%s\n' "$container" "$project_name" "$main_dir" "$session_prefix"
}

# Builds (if it doesn't already exist) the standard project window layout
# - 0:repo 7:vi 8:tr 9:ai - in $1, as session $2, and switches to it.
# $3 is the project name (unused now that ai doesn't auto-launch, kept
# for callers/future use). $4 is repo_dir: window 0 ("repo") sits there
# instead of $1, since for a worktree branch that's the container/project
# root, not the specific branch's own worktree directory - defaults to
# $1 when not given (plain non-git dirs have no such distinction).
# Window 9 ("ai") is just an idle shell - it used to auto-launch a claude
# session here, but every caller of this function now is a Packages/
# live-websites session, where that's unwanted noise.
build_project_session() {
  local dir="$1" session="$2" project_name="$3" repo_dir="${4:-$1}"

  tmux has-session -t "$session" 2>/dev/null
  if [ $? != 0 ]; then
    tmux new-session -d -s "$session" -n repo -c "$repo_dir"
    tmux set-option -t "$session" renumber-windows off
    tmux new-window -t "${session}:7" -n vi -c "$dir"
    tmux new-window -t "${session}:8" -n tr -c "$dir"
    tmux new-window -t "${session}:9" -n ai -c "$dir"
    tmux select-window -t "${session}:7"
  fi

  tmux switch-client -t "$session"
}

# One-time conversion of a plain single-checkout repo at $1 into a
# worktree container: the currently checked-out branch's entire contents
# (including .git, uncommitted/untracked files and all - nothing is
# cloned fresh, just moved) go into $1/<branch-dir>/, leaving $1 itself
# as the now-empty container. Then fetches every remote branch and adds
# a worktree for any that doesn't already have one, so the picker list
# is complete from the first open, not just whatever branch you happened
# to be on. Prints the branch directory name you were already on (the
# one the caller should actually open right now).
convert_to_worktree_container() {
  local dir="$1" branch branch_dir tmp main_dir remote_branch other_branch other_dir

  branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null)
  [ -z "$branch" ] && branch=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)
  branch_dir=$(basename "$branch")

  tmp="${dir}.pclone-tmp.$$"
  mv "$dir" "$tmp"
  mkdir "$dir"
  mv "$tmp" "$dir/$branch_dir"
  touch "$dir/.worktree-root"

  main_dir="$dir/$branch_dir"
  git -C "$main_dir" fetch --quiet --all 2>/dev/null

  while IFS= read -r remote_branch; do
    [ -z "$remote_branch" ] && continue
    other_branch="$remote_branch"
    [ "$other_branch" = "$branch" ] && continue
    other_dir="$dir/$(basename "$other_branch")"
    [ -d "$other_dir" ] && continue
    git -C "$main_dir" show-ref --verify --quiet "refs/heads/$other_branch" \
      && git -C "$main_dir" worktree add "$other_dir" "$other_branch" \
      || git -C "$main_dir" worktree add "$other_dir" -b "$other_branch" --track "origin/$other_branch"
  done < <(git -C "$main_dir" branch -r --format='%(refname:short)' 2>/dev/null | grep '^origin/' | sed 's#^origin/##')

  tmux display-message "Converted $(basename "$dir") to worktree layout (branch: ${branch})"
  printf '%s\n' "$branch_dir"
}
