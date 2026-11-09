#!/usr/bin/env bash
# prefix+w: the frontend branches with a dev server running, as
# "branch : localhost:port", down the left edge. Enter opens that branch's
# tab in the preview browser on workspace 11.
# $1: the current session. $2: the client that pressed the key.
# PROJECT_LIST_DRY=<file> writes the action there instead of doing it (for testing).
dir="$(cd "$(dirname "$0")" && pwd)"
source "$dir/fzf_common.sh"
source "$dir/preview/lib.sh"
fzf_vim_nav_args " Frontends  "

current=$1
client=$2

rows=""
pos=1
i=0
while IFS=$'\t' read -r session kind port path _; do
  case "$session" in '' | \#*) continue ;; esac
  [ -x "$dir/preview/$kind.sh" ] || continue
  port_listening "$port" || continue
  i=$((i + 1))
  [ "$session" = "$current" ] && pos=$i
  branch=$(git -C "$path" symbolic-ref --short HEAD 2>/dev/null)
  rows+="${session}"$'\t'"${branch:-${session#*-}} : localhost:${port}"$'\n'
done <"$PREVIEW_REGISTRY"

if [ -z "$rows" ]; then
  echo "No frontend running"
  sleep 1
  exit 0
fi

selected=$(printf '%s' "$rows" | fzf \
  --exact \
  --prompt=" Frontends  " \
  --pointer="▶" \
  --border=rounded \
  --height=100% \
  --layout=reverse \
  --info=inline \
  --header="enter: open in the browser on 11" \
  --delimiter=$'\t' \
  --with-nth=2.. \
  --bind "load:pos($pos)" \
  "${FZF_VIM_NAV_ARGS[@]}" \
  --color="$FZF_CATPPUCCIN_COLOR")

session=${selected%%$'\t'*}
[ -z "$session" ] && exit 0
[ -n "$PROJECT_LIST_DRY" ] && { echo "browser $session" >>"$PROJECT_LIST_DRY"; exit 0; }
setsid -f "$dir/preview.sh" "$session" "" "$client" >/dev/null 2>&1
