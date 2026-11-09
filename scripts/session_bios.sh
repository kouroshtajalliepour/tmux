#!/usr/bin/env bash
# The bios of a tmux session: what project type it runs. One row per session
# in ~/.jarvis/session-bios.tsv: session, type, port, dir, browser, link.
# :link /admin/users sets the page alt opens for the session.
#
#   :vue 4000 / :vue auto / :unproject   from tmux's prompt, through the aliases and
#                                   hook in conf/project.conf ("hook" below)
#   ask <session> <dir>             on creation: offer it if there's a Vue app
#   apply <session> <port> <dir>    write the row, port empty = next free
#   choose <session> <port> <dirs>  popup: pick one of several apps
source "$(dirname "$0")/preview/lib.sh"
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
BIOS=$PREVIEW_REGISTRY
mkdir -p "$(dirname "$BIOS")"
touch "$BIOS"

# A Vue app we can run: depends on vue, isn't Nuxt, and has a dev script.
is_vue_app() {
  [ -f "$1/package.json" ] && jq -e '
    ((.dependencies // {}) + (.devDependencies // {})) as $d
    | ($d | has("vue")) and (($d | has("nuxt")) | not) and (.scripts.dev != null)
  ' "$1/package.json" >/dev/null 2>&1
}

# Vue apps at or up to 3 levels below $1, one directory per line.
find_vue_apps() {
  if is_vue_app "$1"; then
    printf '%s\n' "$1"
    return
  fi
  find "$1" -maxdepth 3 -name package.json -not -path '*/node_modules/*' -printf '%h\n' 2>/dev/null |
    while IFS= read -r d; do is_vue_app "$d" && printf '%s\n' "$d"; done
}

remove_row() {
  local tmp
  tmp=$(mktemp "$BIOS.XXXX")
  awk -F'\t' -v s="$1" '$1 != s' "$BIOS" >"$tmp" && mv "$tmp" "$BIOS"
}

owner_of_port() {
  awk -F'\t' -v p="$1" '$0 !~ /^#/ && $3 == p { print $1; exit }' "$BIOS"
}

next_free_port() {
  local p=5173
  while [ -n "$(owner_of_port "$p")" ] || port_listening "$p"; do p=$((p + 1)); done
  printf '%s\n' "$p"
}

apply() {
  local session=$1 port=$2 dir=$3 owner
  [ -n "$port" ] || port=$(next_free_port)
  owner=$(owner_of_port "$port")
  if [ -n "$owner" ] && [ "$owner" != "$session" ]; then
    preview_msg "port $port already belongs to $owner"
    return 1
  fi
  local link
  link=$(awk -F'\t' -v s="$session" '$1 == s { print $6; exit }' "$BIOS")
  remove_row "$session"
  printf '%s\tvue\t%s\t%s\tfirefox\t%s\n' "$session" "$port" "$dir" "${link:-/}" >>"$BIOS"
  preview_msg "vue on localhost:$port"
}

# Saves the page alt opens for this session, and takes its tab there once.
set_link() {
  local session=$1 link=$2 port tmp
  port=$(port_for_session "$session")
  if [ -z "$port" ]; then
    preview_msg "this session has no project type yet: :vue 4000"
    return 1
  fi
  # accept a pasted full URL, keeping only its path
  link=$(sed -E 's#^https?://[^/]+##' <<<"$link")
  [ "${link:0:1}" = / ] || link="/$link"
  if [[ "$link" =~ [[:space:]] ]]; then
    preview_msg "not a link: $link"
    return 1
  fi
  tmp=$(mktemp "$BIOS.XXXX")
  awk -F'\t' -v OFS='\t' -v s="$session" -v l="$link" '$1 == s { $6 = l } 1' "$BIOS" >"$tmp" && mv "$tmp" "$BIOS"
  preview_msg "alt opens localhost:$port$link"
  port_listening "$port" && python3 -I "$PREVIEW_TABS" goto "http://localhost:$port$link" >/dev/null 2>&1
  return 0
}

# Finds the app under the given directories and applies it. Several apps ask.
assign() {
  local session=$1 port=$2 base apps=""
  shift 2
  for base in "$@"; do
    [ -n "$base" ] || continue
    apps=$(find_vue_apps "$base")
    [ -n "$apps" ] && break
  done
  if [ -z "$apps" ]; then
    preview_msg "no Vue project found here"
    return 1
  fi
  if [ "$(printf '%s\n' "$apps" | wc -l)" -eq 1 ]; then
    apply "$session" "$port" "$apps"
    return
  fi
  local quoted=""
  while IFS= read -r d; do quoted+=" $(printf '%q' "$d")"; done <<<"$apps"
  tmux display-popup ${TMUX_CLIENT:+-c "$TMUX_CLIENT"} -w 60% -h 40% -T " Which app? " \
    -E "$(printf '%q' "$SELF") choose $(printf '%q' "$session") '$port'$quoted"
}

case "$1" in
hook)
  # hook <session> <pane_path> <client> <@option> [value]
  session=$2 pane=$3 option=$5 value=$6
  [ -n "$4" ] && export TMUX_CLIENT=$4
  case "$option" in
  @link)
    set_link "$session" "$value"
    ;;
  @unproject)
    remove_row "$session"
    preview_msg "no project type on this session now"
    ;;
  @vue)
    [ "$value" = auto ] && value=""
    if [ -n "$value" ] && ! [[ "$value" =~ ^[0-9]+$ && "$value" -ge 1 && "$value" -le 65535 ]]; then
      preview_msg "not a port: $value"
      exit 1
    fi
    assign "$session" "$value" "$pane" "$(tmux show-option -qv -t "$session" @project_dir)"
    ;;
  esac
  ;;
ask)
  # ask <session> <dir>: only for a session with no bios that holds a Vue app
  session=$2 dir=$3
  [ -z "$(port_for_session "$session")" ] || exit 0
  [ -n "$(find_vue_apps "$dir")" ] || exit 0
  # -b: don't hold up whatever is creating the session
  tmux command-prompt -b ${TMUX_CLIENT:+-t "$TMUX_CLIENT"} -p "Vue project? port (enter: next free / esc: no):" \
    "run-shell -b \"$SELF answer $session $dir %%\""
  ;;
answer)
  # answer <session> <dir> [port]
  if [ -n "$4" ] && ! [[ "$4" =~ ^[0-9]+$ && "$4" -ge 1 && "$4" -le 65535 ]]; then
    preview_msg "not a port: $4"
    exit 1
  fi
  assign "$2" "$4" "$3"
  ;;
apply)
  apply "$2" "$3" "$4"
  ;;
choose)
  session=$2 port=$3
  shift 3
  dir=$(printf '%s\n' "$@" | fzf --prompt=" App  " --layout=reverse --height=100% --border=rounded)
  [ -n "$dir" ] && apply "$session" "$port" "$dir"
  ;;
esac
