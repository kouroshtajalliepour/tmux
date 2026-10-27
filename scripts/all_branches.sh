#!/usr/bin/env bash
# prefix+G: like prefix+g, but lists EVERY remote branch of the current
# project too, not just ones already cloned as a local worktree.
# Picking one that isn't cloned yet creates the worktree first (prints
# "cloning..." while it does, then whatever git itself prints), then
# opens its session same as if it already existed. Only works from a
# Packages (j-*) or live-websites (l-*/lr-*) session.

source "$(dirname "$0")/fzf_common.sh"
source "$(dirname "$0")/project_lib.sh"
fzf_vim_nav_args " Search  "

ctx=$(resolve_current_project) || exit 0
IFS=$'\t' read -r container project_name main_dir session_prefix <<< "$ctx"

git -C "$main_dir" fetch --quiet --all 2>/dev/null

rows=""
cloned_branches=""
while IFS= read -r wt_path; do
  [ -z "$wt_path" ] && continue
  branch=$(git -C "$wt_path" symbolic-ref --short HEAD 2>/dev/null)
  [ -z "$branch" ] && branch=$(git -C "$wt_path" rev-parse --short HEAD 2>/dev/null)
  cloned_branches="${cloned_branches}${branch}"$'\n'
  rows="${rows}${branch}"$'\n'
done < <(git -C "$main_dir" worktree list --porcelain | awk '/^worktree /{print $2}')

while IFS= read -r remote_branch; do
  [ -z "$remote_branch" ] && continue
  printf '%s\n' "$cloned_branches" | grep -qxF "$remote_branch" && continue
  rows="${rows}${remote_branch}"$'\n'
done < <(git -C "$main_dir" branch -r --format='%(refname:short)' 2>/dev/null | grep '^origin/' | sed 's#^origin/##')

selected=$(printf '%s' "$rows" | sed '/^$/d' | sort -u | fzf \
  --exact \
  --prompt=" Search  " \
  --pointer="▶" \
  --border=rounded \
  --height=100% \
  --layout=reverse \
  --info=inline \
  --header="all branches of ${project_name}" \
  "${FZF_VIM_NAV_ARGS[@]}" \
  --color="bg+:#313244,bg:#1e1e2e,fg:#cdd6f4,fg+:#ffffff,hl:#f38ba8,hl+:#f38ba8,border:#f38ba8,prompt:#f38ba8,pointer:#f38ba8,marker:#f38ba8,spinner:#f38ba8,header:#9399b2,info:#9399b2")

[ -z "$selected" ] && exit 0

branch_dir=$(basename "$selected")
worktree_dir="$container/$branch_dir"

if [ ! -d "$worktree_dir" ]; then
  echo "cloning..."
  if git -C "$main_dir" show-ref --verify --quiet "refs/heads/$selected"; then
    git -C "$main_dir" worktree add "$worktree_dir" "$selected"
  else
    git -C "$main_dir" worktree add "$worktree_dir" -b "$selected" --track "origin/$selected"
  fi
fi

new_session="${session_prefix}-${project_name}-${branch_dir}"
build_project_session "$worktree_dir" "$new_session" "$project_name" "$container"
