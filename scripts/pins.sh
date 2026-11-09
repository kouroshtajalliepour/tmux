#!/usr/bin/env bash
# Pinned-session list + self-destruct (see project.conf for the keys).
# Pins live in ~/.jarvis/pinned-branches.tsv, one per line:
#   session<TAB>project_dir<TAB>project_name<TAB>repo_dir
# (the last three empty for non-project sessions). Pins outlive their
# sessions - project sessions aren't saved across restarts anymore - so
# opening a pin whose session is gone rebuilds it via build_project_session.
#
#   toggle [session] [client]    pin/unpin the session (the binding
#                                passes '#{session_name}' '#{client_name}')
#   pick        prefix+f picker (outside the main 4) over the pins (ctrl-x unpins the row;
#               pins whose directory is gone are pruned on open)
#   destroy [session] [client]   switch to Sys and kill the session
#                                (pins untouched)
#   rows|unpin  internal, used by the picker's reload/ctrl-x
#   open <s> [client]            switch to pin <s>, rebuilding it if
#                                needed (session_cycle.sh, last_session.sh)

source "$(dirname "$0")/project_lib.sh"

# PIN_FILE, MAIN_SESSIONS, is_main_session, pinned and pin_add live in
# project_lib.sh (shared with session_cycle.sh and the pickers).
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# the client that pressed the key, when the binding passed it (see
# client_switch in project_lib.sh)
case "$1" in
toggle|destroy|open|pick) [ -n "$3" ] && export TMUX_CLIENT="$3" ;;
esac

mkdir -p "$(dirname "$PIN_FILE")"
touch "$PIN_FILE"

# Drops pins whose project directory is gone (deleted worktree/branch)
# and whose session isn't running either - nothing left to open or
# rebuild. Pins with no directory (e.g. Sys) are kept.
prune() {
  local session dir
  # awk, not `read` with IFS=tab: tab is IFS whitespace, so read would
  # collapse empty columns and shift the rest left.
  while IFS=$'\x1f' read -r session dir; do
    [ -z "$session" ] && continue
    if [ -n "$dir" ] && [ ! -d "$dir" ] && ! tmux has-session -t "=$session" 2>/dev/null; then
      unpin "$session"
    fi
  done < <(awk -F'\t' '{print $1 "\x1f" $2}' "$PIN_FILE")
}

unpin() {
  local tmp
  tmp=$(mktemp "${PIN_FILE}.XXXX")
  awk -F'\t' -v s="$1" '$1 != s' "$PIN_FILE" > "$tmp" && mv "$tmp" "$PIN_FILE"
}

# Switches to pinned session $1, rebuilding it from its saved dirs if
# it isn't running.
open_pin() {
  local session="$1" dir project_name repo_dir
  if tmux has-session -t "=$session" 2>/dev/null; then
    client_switch "$session"
    return
  fi
  # \x1f, not tab, as the read separator: tab is IFS whitespace, so empty
  # columns (e.g. no project name) would collapse and shift the rest left.
  IFS=$'\x1f' read -r dir project_name repo_dir < <(awk -F'\t' -v s="$session" '$1 == s {print $2 "\x1f" $3 "\x1f" $4}' "$PIN_FILE")
  if [ -n "$dir" ] && [ -d "$dir" ]; then
    build_project_session "$dir" "$session" "$project_name" "$repo_dir"
  else
    client_msg "Pin '$session' isn't running and has no directory to rebuild it from"
    return 1
  fi
}

# Picker rows: "session<TAB>N  label[ *]". Dead pins get a dim ○.
# $1: only this project's pins (all of them when empty).
rows() {
  local i=0 session label marker project
  while IFS=$'\x1f' read -r session project; do
    [ -z "$session" ] && continue
    [ -n "$1" ] && [ "$project" != "$1" ] && continue
    i=$((i + 1))
    label=$(session_label "$session")
    marker=""
    if ! tmux has-session -t "=$session" 2>/dev/null; then
      marker=$' \e[2m○\e[0m'
    elif session_done "$session"; then
      marker=" *"
    fi
    printf '%s\t%d  %s%s\n' "$session" "$i" "$label" "$marker"
  done < <(awk -F'\t' '{print $1 "\x1f" $3}' "$PIN_FILE")
}

case "$1" in
toggle)
  session=$(current_session "$2")
  if pinned "$session"; then
    unpin "$session"
    client_msg "Unpinned $session"
    exit 0
  fi
  dir=$(tmux show-option -qv -t "$session" @project_dir)
  repo_dir=$(tmux show-option -qv -t "$session" @repo_dir)
  project_name=$(tmux show-option -qv -t "$session" @display_name)
  # Sessions built before @project_dir existed: fall back to where the
  # vi window and the session itself were started.
  if [ -z "$dir" ] && vi_idx=$(project_window_index "$session" vi) && [ -n "$vi_idx" ]; then
    dir=$(tmux display-message -p -t "${session}:${vi_idx}" '#{pane_current_path}')
    repo_dir=$(tmux display-message -p -t "$session" '#{session_path}')
  fi
  pin_add "$session" "$dir" "$project_name" "$repo_dir"
  client_msg "Pinned $session"
  ;;

pick)
  prune
  if [ ! -s "$PIN_FILE" ]; then
    tmux display-message "No pinned sessions yet - prefix+a pins the current one"
    exit 0
  fi
  fzf_vim_nav_args " Search  "
  # $2: the session the key was pressed in; the list is limited to its project
  project=$(awk -F'\t' -v s="$2" '$1 == s { print $3; exit }' "$PIN_FILE")

  # A frontend project gets a Code / Web toggle: w in vim-keys mode (esc), or
  # ctrl-w while typing. Code goes to the branch, Web also opens its browser
  # tab on workspace 10 (alt+0), starting its dev server if needed.
  source "$(dirname "$SELF")/preview/lib.sh"
  frontend=""
  if [ -n "$project" ]; then
    while IFS= read -r s; do
      [ -n "$(port_for_session "$s")" ] && frontend=1 && break
    done < <(awk -F'\t' -v p="$project" '$3 == p { print $1 }' "$PIN_FILE")
  fi
  prompt=" Search  "
  header="pinned branches${project:+ of $project}  (ctrl-x unpin)"
  mode_args=()
  if [ -n "$frontend" ]; then
    prompt=" Code  "
    header="esc: vim keys · w or ctrl-w: code / web · ctrl-x unpin"
    keys="j,k,g,G,1,2,3,4,5,6,7,8,9,w"
    toggle="transform:case \"\$FZF_PROMPT\" in *Code*NAV*) printf 'change-prompt( Web NAV  )';; *Web*NAV*) printf 'change-prompt( Code NAV  )';; *Web*) printf 'change-prompt( Code  )';; *) printf 'change-prompt( Web  )';; esac"
    finish="become(printf '%s\t%s\n' \"\$FZF_PROMPT\" {1})"
    mode_args=(
      --bind "start:unbind($keys)"
      --bind "esc:transform:case \"\$FZF_PROMPT\" in *Code*NAV*) printf 'unbind($keys)+change-prompt( Code  )';; *Web*NAV*) printf 'unbind($keys)+change-prompt( Web  )';; *Web*) printf 'rebind($keys)+change-prompt( Web NAV  )';; *) printf 'rebind($keys)+change-prompt( Code NAV  )';; esac"
      --bind "w:$toggle"
      --bind "ctrl-w:$toggle"
      --bind "enter:$finish"
    )
    for n in 1 2 3 4 5 6 7 8 9; do
      mode_args+=(--bind "$n:pos($n)+$finish")
    done
  fi

  selected_line=$(rows "$project" | fzf \
    --ansi \
    --exact \
    --prompt="$prompt" \
    --pointer="▶" \
    --border=rounded \
    --height=100% \
    --layout=reverse \
    --info=inline \
    --header="$header" \
    --delimiter=$'\t' \
    --with-nth=2 \
    --bind "ctrl-x:execute-silent('$SELF' unpin {1})+reload('$SELF' rows '$project')" \
    "${FZF_VIM_NAV_ARGS[@]}" \
    "${mode_args[@]}" \
    --color="bg+:#313244,bg:#1e1e2e,fg:#cdd6f4,fg+:#ffffff,hl:#f38ba8,hl+:#f38ba8,border:#f38ba8,prompt:#f38ba8,pointer:#f38ba8,marker:#f38ba8,spinner:#f38ba8,header:#9399b2,info:#9399b2")
  [ -z "$selected_line" ] && exit 0

  mode=code
  if [ -n "$frontend" ]; then
    case "${selected_line%%$'\t'*}" in *Web*) mode=web ;; esac
    session=${selected_line#*$'\t'}
  else
    session=${selected_line%%$'\t'*}
  fi
  [ -z "$session" ] && exit 0
  # PINS_DRY=<file>: write the action there instead of doing it (for testing)
  [ -n "$PINS_DRY" ] && { echo "$mode $session" >>"$PINS_DRY"; exit 0; }

  open_pin "$session" || exit 0
  if [ "$mode" = web ]; then
    if [ -z "$(port_for_session "$session")" ]; then
      client_msg "$(session_label "$session") has no localhost registered"
      exit 0
    fi
    PREVIEW_GOTO=1 setsid -f "$(dirname "$SELF")/preview.sh" "$session" "" "$TMUX_CLIENT" >/dev/null 2>&1
  fi
  ;;

destroy)
  session=$(current_session "$2")
  if is_main_session "$session"; then
    client_msg "$session is a main session - not destroying it"
    exit 0
  fi
  tmux has-session -t =Sys 2>/dev/null || "$HOME/.config/tmux/bootstrap_sys.sh" --force
  client_switch Sys
  tmux kill-session -t "=$session"
  ;;

rows) rows "$2" ;;
unpin) unpin "$2" ;;
open) open_pin "$2" ;;
esac
