#!/usr/bin/env bash
# prefix+B: branch off the current project session.
#
# If the project is (or has been converted to) a worktree container, this
# creates/attaches a sibling worktree+session for the chosen branch -
# cancelling the branch picker does nothing at all - leaving the current
# session's checkout untouched. That's the same path prefix+S takes for
# a worktree-container project.
#
# If it isn't (a plain single-checkout project that hasn't been opened
# fresh since this changed), this keeps the original behavior: switches
# the branch in-place, in the one shared working tree vi/tr/ai all
# sit in.

source "$(dirname "$0")/fzf_common.sh"
source "$(dirname "$0")/project_lib.sh"

session=$(tmux display-message -p '#S')

vi_idx=$(project_window_index "$session" vi)
tr_idx=$(project_window_index "$session" tr)
ai_idx=$(project_window_index "$session" ai)

if [ -z "$vi_idx" ] || [ -z "$tr_idx" ] || [ -z "$ai_idx" ]; then
  tmux display-message "Not a project session (needs vi/tr/ai windows)"
  exit 0
fi

dir=$(tmux display-message -p -t "${session}:${vi_idx}" '#{pane_current_path}')
cd "$dir" 2>/dev/null || exit 0

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  tmux display-message "Not a git repo"
  exit 0
}

container=$(dirname "$dir")

if is_worktree_container "$container"; then
  project_name=$(basename "$container")
  main_dir=$(find_main_worktree "$container")

  branch=$(pick_or_create_branch "$main_dir")
  [ -z "$branch" ] && exit 0

  branch_dir=$(basename "$branch")
  worktree_dir="$container/$branch_dir"

  if [ ! -d "$worktree_dir" ]; then
    if git -C "$main_dir" show-ref --verify --quiet "refs/heads/$branch"; then
      git -C "$main_dir" worktree add "$worktree_dir" "$branch"
    elif git -C "$main_dir" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
      git -C "$main_dir" worktree add "$worktree_dir" -b "$branch" --track "origin/$branch"
    else
      git -C "$main_dir" worktree add "$worktree_dir" -b "$branch"
    fi
  fi

  prefix_letter=${session%%-*}
  new_session="${prefix_letter}-${project_name}-${branch_dir}"
  build_project_session "$worktree_dir" "$new_session" "$project_name" "$container"
  exit 0
fi

# plain single-checkout project: original in-place switch behavior
fzf_vim_nav_args " Branch  "
git fetch --quiet --all 2>/dev/null

local_branches=$(git branch --format='%(refname:short)' 2>/dev/null)
remote_branches=$(git branch -r --format='%(refname:short)' 2>/dev/null | grep '^origin/' | sed 's#^origin/##')

branch=$(printf '%s\n%s\n' "$local_branches" "$remote_branches" | sed '/^$/d' | sort -u | fzf \
  --exact \
  --prompt=" Branch  " \
  --border=rounded \
  --height=100% \
  --layout=reverse \
  --info=inline \
  "${FZF_VIM_NAV_ARGS[@]}" \
  --color="$FZF_CATPPUCCIN_COLOR")

[ -z "$branch" ] && exit 0

if git show-ref --verify --quiet "refs/heads/$branch"; then
  git switch "$branch"
else
  git switch -c "$branch" --track "origin/$branch"
fi

"$(dirname "$0")/ai_launch.sh" "$dir" "${session}:${ai_idx}" "$(basename "$dir")"

tmux display-message "${session}: switched to ${branch}"
