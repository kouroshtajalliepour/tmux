#!/usr/bin/env bash
# prefix+N / prefix+P: jump to the next/previous branch of the project
# you're in (e.g. tmux: master -> production -> master), wrapping around.
# Same branch list and order as branch_picker.sh; a branch whose session
# isn't running gets built on the spot. Only works from a j-/l-/lr-
# session of a worktree-container project.
#
# $1 = next | prev
# $2 = the session the key was pressed in, $3 = that client - the
#      binding passes '#{session_name}' '#{client_name}' (see
#      client_switch in project_lib.sh)

source "$(dirname "$0")/project_lib.sh"

[ -n "$3" ] && export TMUX_CLIENT="$3"
current=$(current_session "$2")
ctx=$(resolve_current_project "$current") || exit 0
IFS=$'\t' read -r container project_name main_dir session_prefix <<< "$ctx"

paths=()
sessions=()
while IFS= read -r wt_path; do
  [ -z "$wt_path" ] && continue
  session="${session_prefix}-${project_name}-$(basename "$wt_path")"
  paths+=("$wt_path")
  sessions+=("${session//[.:]/_}")
done < <(git -C "$main_dir" worktree list --porcelain | awk '/^worktree /{print $2}')

n=${#sessions[@]}
if [ "$n" -lt 2 ]; then
  client_msg "$project_name has no other branches"
  exit 0
fi

idx=0
for i in "${!sessions[@]}"; do
  [ "${sessions[$i]}" = "$current" ] && idx=$i && break
done

if [ "$1" = prev ]; then
  target=$(( (idx - 1 + n) % n ))
else
  target=$(( (idx + 1) % n ))
fi

build_project_session "${paths[$target]}" "${sessions[$target]}" "$project_name" "$container"
