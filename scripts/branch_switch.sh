#!/usr/bin/env bash
# prefix+B: switch branch for a whole project session at once. Only runs
# when the session has the code/term/ai layout from scripts/tmux-sessionizer
# — those three windows share one working tree, so switching the branch in
# one place is enough for all of them.

source "$(dirname "$0")/fzf_common.sh"
fzf_vim_nav_args " Branch  "

session=$(tmux display-message -p '#S')

name1=$(tmux display-message -p -t "${session}:1" '#{window_name}' 2>/dev/null)
name2=$(tmux display-message -p -t "${session}:2" '#{window_name}' 2>/dev/null)
name3=$(tmux display-message -p -t "${session}:3" '#{window_name}' 2>/dev/null)

if [ "$name1" != "code" ] || [ "$name2" != "term" ] || [ "$name3" != "ai" ]; then
  tmux display-message "Not a project session (needs windows 1:code 2:term 3:ai)"
  exit 0
fi

dir=$(tmux display-message -p -t "${session}:1" '#{pane_current_path}')
cd "$dir" 2>/dev/null || exit 0

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  tmux display-message "Not a git repo"
  exit 0
}

git fetch --quiet --all 2>/dev/null

local_branches=$(git branch --format='%(refname:short)' 2>/dev/null)
remote_branches=$(git branch -r --format='%(refname:short)' 2>/dev/null | grep -v 'HEAD' | sed 's#^origin/##')

branch=$(printf '%s\n%s\n' "$local_branches" "$remote_branches" | sed '/^$/d' | sort -u | fzf \
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

tmux display-message "${session}: switched to ${branch}"
