#!/usr/bin/env bash
# Moving between pinned projects (~/.local/state/tmux/pinned-branches.tsv), one row per
# project. Each lands on the branch you used last there.
#   next|prev <session> <client>   prefix+l / prefix+h
#   pick <session> <client>        prefix+F
dir="$(cd "$(dirname "$0")" && pwd)"
source "$dir/project_lib.sh"
source "$dir/fzf_common.sh"

action=$1
current=$(current_session "$2")
[ -n "$3" ] && export TMUX_CLIENT="$3"

mapfile -t projects < <(pinned_projects)
n=${#projects[@]}
if [ "$n" -eq 0 ]; then
  client_msg "No pinned projects yet - prefix+a pins the current session"
  exit 0
fi

here=$(awk -F'\t' -v s="$current" '$1 == s { print $3; exit }' "$PIN_FILE")
idx=-1
for i in "${!projects[@]}"; do
  [ "${projects[$i]}" = "$here" ] && idx=$i && break
done

go_to() {
  "$dir/pins.sh" open "$(project_last_branch "$1")" "$TMUX_CLIENT"
}

case "$action" in
next | prev)
  if [ "$idx" -ge 0 ] && [ "$n" -eq 1 ]; then
    client_msg "Only project: $here"
    exit 0
  fi
  if [ "$action" = prev ]; then
    if [ "$idx" -lt 0 ]; then target=$((n - 1)); else target=$(((idx - 1 + n) % n)); fi
  else
    if [ "$idx" -lt 0 ]; then target=0; else target=$(((idx + 1) % n)); fi
  fi
  go_to "${projects[$target]}" || exit 0
  client_msg "project $((target + 1))/$n: ${projects[$target]}"
  ;;
pick)
  fzf_vim_nav_args " Projects  "
  selected=$(for p in "${projects[@]}"; do
    c=$(awk -F'\t' -v p="$p" '$3 == p' "$PIN_FILE" | wc -l)
    printf '%s\t%s  (%d)\n' "$p" "$p" "$c"
  done | fzf \
    --exact \
    --prompt=" Projects  " \
    --pointer="▶" \
    --border=rounded \
    --height=100% \
    --layout=reverse \
    --info=inline \
    --header="pinned projects  (pinned branches)" \
    --delimiter=$'\t' \
    --with-nth=2 \
    --bind "load:pos($((idx < 0 ? 1 : idx + 1)))" \
    "${FZF_VIM_NAV_ARGS[@]}" \
    --color="$FZF_CATPPUCCIN_COLOR")
  [ -z "$selected" ] && exit 0
  go_to "${selected%%$'\t'*}"
  ;;
esac
