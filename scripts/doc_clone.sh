#!/usr/bin/env bash
# prefix+C: clone a GitHub repo into any folder under ~/Documents.
# Three steps: pick the target folder (fzf, fuzzy search), paste the
# GitHub URL, then multi-select which remote branches to actually set
# up as worktrees right away (same logic pclone uses in the shell -
# first picked branch is the real clone, the rest become worktrees
# alongside it). Cancelling any step aborts with nothing created.

source "$(dirname "$0")/fzf_common.sh"
fzf_vim_nav_args " Folder  "

target_dir=$(find "$HOME/Documents" -mindepth 1 -maxdepth 4 -type d -not -path '*/.*' | fzf \
  --exact \
  --prompt=" Folder  " \
  --pointer="▶" \
  --border=rounded \
  --height=100% \
  --layout=reverse \
  --info=inline \
  --header="pick where to clone into" \
  "${FZF_VIM_NAV_ARGS[@]}" \
  --color="$FZF_CATPPUCCIN_COLOR")

[ -z "$target_dir" ] && exit 0

url=$(printf '' | fzf \
  --print-query \
  --prompt=" GitHub URL  " \
  --border=rounded \
  --height=3 \
  --header="paste the repo URL, then Enter" \
  --color="$FZF_CATPPUCCIN_COLOR" \
  --bind "ctrl-c:abort" | head -1)

[ -z "$url" ] && exit 0

project=$(basename "$url" .git)

branches=$(git ls-remote --heads "$url" 2>/dev/null | sed 's#.*refs/heads/##')
if [ -z "$branches" ]; then
  tmux display-message "couldn't list branches on $url"
  exit 0
fi

selected=$(printf '%s\n' "$branches" | fzf \
  --exact \
  --multi \
  --prompt=" Branches  " \
  --pointer="▶" \
  --marker="✓" \
  --border=rounded \
  --height=100% \
  --layout=reverse \
  --info=inline \
  --bind "tab:toggle+down,shift-tab:toggle+up,ctrl-c:abort" \
  --color="$FZF_CATPPUCCIN_COLOR")

[ -z "$selected" ] && exit 0

root="$target_dir/$project"
mkdir -p "$root"
touch "$root/.worktree-root"

main_dir=""
first=1
while IFS= read -r branch; do
  [ -z "$branch" ] && continue
  branch_dir=$(basename "$branch")
  if [ "$first" = 1 ]; then
    git clone -b "$branch" "$url" "$root/$branch_dir" || exit 1
    main_dir="$root/$branch_dir"
    first=0
  else
    git -C "$main_dir" worktree add "$root/$branch_dir" -b "$branch" --track "origin/$branch"
  fi
done <<< "$selected"

tmux display-message "cloned $project -> $root"
