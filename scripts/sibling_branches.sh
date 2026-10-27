#!/usr/bin/env bash
# prefix+g: pick a sibling branch of the CURRENT project (the worktree
# container you're already sitting in) and switch straight to its
# session, building it if it doesn't exist yet. Only existing branches
# are listed (not a free-typing branch creator - that's prefix+B's job).
# Only works from a Packages (j-*) or live-websites (l-*/lr-*) session -
# anywhere else, this just says so and does nothing.

source "$(dirname "$0")/fzf_common.sh"
source "$(dirname "$0")/project_lib.sh"
fzf_vim_nav_args " Search  "

session=$(tmux display-message -p '#S')

case "$session" in
j-*|l-*|lr-*) ;;
*)
  tmux display-message "prefix+g only works in a Packages/live-websites session"
  exit 0
  ;;
esac

vi_idx=$(project_window_index "$session" vi)
if [ -z "$vi_idx" ]; then
  tmux display-message "Not a project session (needs a vi window)"
  exit 0
fi

dir=$(tmux display-message -p -t "${session}:${vi_idx}" '#{pane_current_path}')
container=$(dirname "$dir")

if ! is_worktree_container "$container"; then
  tmux display-message "Not a worktree-container project"
  exit 0
fi

project_name=$(basename "$container")
main_dir=$(find_main_worktree "$container")
session_prefix=${session%%-*}

rows=""
while IFS= read -r wt_path; do
  [ -z "$wt_path" ] && continue
  branch=$(git -C "$wt_path" symbolic-ref --short HEAD 2>/dev/null)
  [ -z "$branch" ] && branch=$(git -C "$wt_path" rev-parse --short HEAD 2>/dev/null)
  rows="${rows}${wt_path}"$'\t'"${project_name}:${branch}"$'\n'
done < <(git -C "$main_dir" worktree list --porcelain | awk '/^worktree /{print $2}')

selected_line=$(printf '%s' "$rows" | sed '/^$/d' | fzf \
  --exact \
  --prompt=" Search  " \
  --pointer="▶" \
  --border=rounded \
  --height=100% \
  --layout=reverse \
  --info=inline \
  --header="branches of ${project_name}" \
  --delimiter=$'\t' \
  --with-nth=2 \
  "${FZF_VIM_NAV_ARGS[@]}" \
  --color="bg+:#313244,bg:#1e1e2e,fg:#cdd6f4,fg+:#ffffff,hl:#f38ba8,hl+:#f38ba8,border:#f38ba8,prompt:#f38ba8,pointer:#f38ba8,marker:#f38ba8,spinner:#f38ba8,header:#9399b2,info:#9399b2")

[ -z "$selected_line" ] && exit 0

selected=${selected_line%%$'\t'*}
branch_dir=$(basename "$selected")

new_session="${session_prefix}-${project_name}-${branch_dir}"
build_project_session "$selected" "$new_session" "$project_name" "$container"
