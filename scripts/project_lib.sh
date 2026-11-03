#!/usr/bin/env bash
# Shared helpers for the project-session scripts (sourced, not run directly).
source "$(dirname "${BASH_SOURCE[0]}")/fzf_common.sh"

# Key bindings pass the client that pressed the key ('#{client_name}')
# and scripts export it as TMUX_CLIENT. A script started by run-shell has
# no client of its own, so a bare switch-client / display-message (or
# display-message -p '#S') makes tmux guess one - with the main terminal
# and the alt+` drop-down both attached it can pick the wrong one (that's
# how prefix+a once unpinned a different session). These two aim at
# TMUX_CLIENT when it's set and behave as before otherwise.
client_switch() {
  tmux switch-client ${TMUX_CLIENT:+-c "$TMUX_CLIENT"} -t "=$1"
}

client_msg() {
  tmux display-message ${TMUX_CLIENT:+-c "$TMUX_CLIENT"} "$1"
}

# The session the key was pressed in: $1 if the binding passed it
# ('#{session_name}'), else tmux's own guess.
current_session() {
  if [ -n "$1" ]; then printf '%s\n' "$1"; else tmux display-message -p '#S'; fi
}

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

# Resolves the CURRENT tmux session's project context - used by
# branch_picker.sh, which only makes sense inside a Packages/live-
# websites session. Prints "container\tproject_name\tmain_dir\tprefix"
# on success; on failure, shows why via tmux display-message and
# returns 1 - callers should just `|| exit 0` on this. $1 (optional):
# the session to use instead of tmux's guess (see current_session).
resolve_current_project() {
  local session vi_idx dir container project_name main_dir session_prefix
  session=$(current_session "$1")

  case "$session" in
  j-*|l-*|lr-*) ;;
  *)
    client_msg "Only works in a Packages/live-websites session"
    return 1
    ;;
  esac

  vi_idx=$(project_window_index "$session" vi)
  if [ -z "$vi_idx" ]; then
    client_msg "Not a project session (needs a vi window)"
    return 1
  fi

  dir=$(tmux display-message -p -t "${session}:${vi_idx}" '#{pane_current_path}')
  container=$(dirname "$dir")

  if ! is_worktree_container "$container"; then
    client_msg "Not a worktree-container project"
    return 1
  fi

  project_name=$(basename "$container")
  main_dir=$(find_main_worktree "$container")
  session_prefix=${session%%-*}

  printf '%s\t%s\t%s\t%s\n' "$container" "$project_name" "$main_dir" "$session_prefix"
}

# True if any window of session $1 has activity_monitor.sh's @done flag
# (it was busy, then went still while you weren't looking at it).
session_done() {
  tmux list-windows -t "=$1" -F '#{@done}' 2>/dev/null | grep -q 1
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
# Repo name for branch dir $1: the worktree container's name if $1 is one
# of its branches (".../tmux/master" -> "tmux"), else $1's own name. Used
# for @display_name (the status bar's left pill) when a caller - e.g. an
# old pin saved without a project name - doesn't pass one.
project_display_name() {
  local parent
  parent=$(dirname "$1")
  if is_worktree_container "$parent"; then basename "$parent"; else basename "$1"; fi
}

build_project_session() {
  local dir="$1" session="$2" project_name="${3:-$(project_display_name "$1")}" repo_dir="${4:-$1}"
  # tmux reads "." and ":" in a target as window/pane ("release-0.1.0" -> pane "1.0"), so a
  # session named with them can't be switched to: use "_" like branch_picker.sh does
  session=${session//[.:]/_}

  tmux has-session -t "=$session" 2>/dev/null
  # shellcheck disable=SC2181 # the has-session call above is the condition; checking inline would obscure it
  if [ $? != 0 ]; then
    tmux new-session -d -s "$session" -n repo -c "$repo_dir"
    tmux set-option -t "$session" renumber-windows off
    tmux new-window -t "${session}:7" -n vi -c "$dir"
    tmux new-window -t "${session}:8" -n tr -c "$dir"
    tmux new-window -t "${session}:9" -n ai -c "$dir"
    tmux select-window -t "${session}:7"
  fi

  # Left side of the status bar shows this instead of the raw session
  # name ("j-api-generator-system-develop") - just the project name, no
  # prefix, no branch (the branch already shows on the right via
  # git_status.sh, no need to repeat it on the left too).
  if [ -n "$project_name" ]; then
    tmux set-option -t "$session" @display_name "$project_name"
  fi

  # Everything needed to rebuild this exact session later - pins.sh
  # stores these when you pin it, so a pinned session that's since been
  # killed (or never restored after a restart) can be rebuilt on demand.
  tmux set-option -t "$session" @project_dir "$dir"
  tmux set-option -t "$session" @repo_dir "$repo_dir"

  client_switch "$session"

  # Remember this as the last-visited session for its category (j, or
  # l/lr both collapse to "l"), so prefix+j/l can jump straight back
  # here next time instead of opening the picker - see jump_last.sh.
  local category="${session%%-*}"
  [ "$category" = "lr" ] && category="l"
  mkdir -p "$HOME/.cache/tmux-last-session"
  printf '%s' "$session" > "$HOME/.cache/tmux-last-session/$category"

  # Also remember which PROJECT that was (not just the session name) -
  # jump_last.sh needs this directly, since session names can't be split
  # back into project_name/branch_dir unambiguously (either can contain
  # hyphens).
  if [ -n "$project_name" ]; then
    mkdir -p "$HOME/.cache/tmux-last-session-project"
    printf '%s' "$project_name" > "$HOME/.cache/tmux-last-session-project/$category"
  fi

  # Remember this as the last branch worked on for THIS project (keyed
  # by project name, e.g. api-generator-system, mavidahome-backend) -
  # lets the main picker collapse a multi-branch project down to one
  # row that reopens wherever you left off, instead of listing every
  # branch (that's prefix+k/l's job now).
  if [ -n "$project_name" ]; then
    mkdir -p "$HOME/.cache/tmux-last-branch"
    printf '%s' "$dir" > "$HOME/.cache/tmux-last-branch/$project_name"
  fi
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
    # shellcheck disable=SC2015 # intentional: branch-exists-locally vs. needs-tracking-branch, not error handling
    git -C "$main_dir" show-ref --verify --quiet "refs/heads/$other_branch" \
      && git -C "$main_dir" worktree add "$other_dir" "$other_branch" \
      || git -C "$main_dir" worktree add "$other_dir" -b "$other_branch" --track "origin/$other_branch"
  done < <(git -C "$main_dir" branch -r --format='%(refname:short)' 2>/dev/null | grep '^origin/' | sed 's#^origin/##')

  tmux display-message "Converted $(basename "$dir") to worktree layout (branch: ${branch})"
  printf '%s\n' "$branch_dir"
}

# The 4 hand-maintained sessions (see bootstrap_sys.sh). prefix+j/k
# cycles these when you're in one of them (session_cycle.sh), and they're
# never auto-killed by pins.sh destroy.
MAIN_SESSIONS="Sys Infra Media Todos"

is_main_session() {
  case " $MAIN_SESSIONS " in *" $1 "*) return 0 ;; esac
  return 1
}

# Pinned sessions (pins.sh, prefix+f/a). One per line:
#   session<TAB>project_dir<TAB>project_name<TAB>repo_dir
PIN_FILE="$HOME/.cache/tmux-pinned"

pinned() {
  [ -f "$PIN_FILE" ] || return 1
  awk -F'\t' -v s="$1" '$1 == s {found = 1} END {exit !found}' "$PIN_FILE"
}

# Pins session $1 (dir $2, project name $3, repo dir $4) unless it's
# already pinned. Same "." / ":" -> "_" rule as build_project_session,
# so the pin names the session tmux actually has. The pickers
# (tmux-sessionizer, branch_picker.sh) call this right after building a
# session, so anything opened through prefix+m k/l or prefix+K/L is
# pinned automatically.
pin_add() {
  local session="${1//[.:]/_}"
  mkdir -p "$(dirname "$PIN_FILE")"
  touch "$PIN_FILE"
  pinned "$session" && return 0
  printf '%s\t%s\t%s\t%s\n' "$session" "$2" "$3" "$4" >> "$PIN_FILE"
}
