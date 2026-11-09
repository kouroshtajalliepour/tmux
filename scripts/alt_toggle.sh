#!/usr/bin/env bash
# A lone tap of left alt (keyd sends F13 = XF86Tools; i3 binds it here):
#   on 11 (the preview)     -> the terminal on 1, on the project of the tab
#                              you're looking at, same pane as you left it
#   not on workspace 1      -> the terminal on 1
#   on 1, frontend project  -> its preview on 11 (scripts/preview.sh)
#   on 1, anything else     -> nothing
dir="$(cd "$(dirname "$0")" && pwd)"
ws=$(i3-msg -t get_workspaces | python3 -c 'import json,sys; print(next((w["name"] for w in json.load(sys.stdin) if w["focused"]), ""))')

# Point the terminal at the project of the preview's active tab, if it has one.
follow_active_tab() {
  source "$dir/preview/lib.sh"
  local url port session client
  url=$(python3 -I "$PREVIEW_TABS" active 2>/dev/null) || return 0
  port=${url#*://}
  port=${port%%/*}
  [ "$port" = "${port##*:}" ] && return 0
  port=${port##*:}
  session=$(session_for_port "$port")
  [ -n "$session" ] || return 0
  tmux has-session -t "=$session" 2>/dev/null || return 0
  client=$(tmux list-clients -F '#{client_activity} #{client_name}' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
  [ -n "$client" ] && tmux switch-client -c "$client" -t "=$session"
}

if [ "$ws" = 11 ]; then
  follow_active_tab
  i3-msg -q workspace number 1
elif [ "$ws" != 1 ]; then
  i3-msg -q workspace number 1
else
  exec "$dir/preview.sh"
fi
