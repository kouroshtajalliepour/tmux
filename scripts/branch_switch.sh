#!/usr/bin/env bash
# prefix+B: switch branch for a whole project session at once. Only runs
# when the session has code/term/ai windows (wherever they are) from
# scripts/tmux-sessionizer — those three share one working tree, so
# switching the branch in one place is enough for all of them. Also
# relaunches the ai window onto the new branch's named claude session,
# unless it's already busy running something.

source "$(dirname "$0")/fzf_common.sh"
source "$(dirname "$0")/project_lib.sh"
fzf_vim_nav_args " Branch  "

session=$(tmux display-message -p '#S')

code_idx=$(project_window_index "$session" code)
term_idx=$(project_window_index "$session" term)
ai_idx=$(project_window_index "$session" ai)

if [ -z "$code_idx" ] || [ -z "$term_idx" ] || [ -z "$ai_idx" ]; then
  tmux display-message "Not a project session (needs code/term/ai windows)"
  exit 0
fi

dir=$(tmux display-message -p -t "${session}:${code_idx}" '#{pane_current_path}')
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

"$(dirname "$0")/ai_launch.sh" "$dir" "${session}:${ai_idx}"

tmux display-message "${session}: switched to ${branch}"
