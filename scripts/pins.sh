#!/usr/bin/env bash
# Pinned-session list + self-destruct (see project.conf for the keys).
# Pins live in ~/.cache/tmux-pinned, one per line:
#   session<TAB>project_dir<TAB>project_name<TAB>repo_dir
# (the last three empty for non-project sessions). Pins outlive their
# sessions - project sessions aren't saved across restarts anymore - so
# opening a pin whose session is gone rebuilds it via build_project_session.
#
#   toggle      pin/unpin the current session
#   pick        prefix+f picker (outside the main 4) over the pins (ctrl-x unpins the row;
#               pins whose directory is gone are pruned on open)
#   destroy     switch to Sys and kill the current session (pins untouched)
#   rows|unpin  internal, used by the picker's reload/ctrl-x
#   open <s>    switch to pin <s>, rebuilding it if needed (last_session.sh)

source "$(dirname "$0")/project_lib.sh"

# PIN_FILE, MAIN_SESSIONS, is_main_session, pinned and pin_add live in
# project_lib.sh (shared with session_cycle.sh and the pickers).
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

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
    tmux switch-client -t "=$session"
    return
  fi
  IFS=$'\t' read -r _ dir project_name repo_dir < <(awk -F'\t' -v s="$session" '$1 == s' "$PIN_FILE")
  if [ -n "$dir" ] && [ -d "$dir" ]; then
    build_project_session "$dir" "$session" "$project_name" "$repo_dir"
  else
    tmux display-message "Pin '$session' isn't running and has no directory to rebuild it from"
  fi
}

# Picker rows: "session<TAB>N  label[ *]". Dead pins get a dim ○.
rows() {
  local i=0 session label marker
  while IFS=$'\t' read -r session _; do
    [ -z "$session" ] && continue
    i=$((i + 1))
    case "$session" in
    j-*|l-*|lr-*) label="${session#*-}" ;;
    *) label="$session" ;;
    esac
    marker=""
    if ! tmux has-session -t "=$session" 2>/dev/null; then
      marker=$' \e[2m○\e[0m'
    elif session_done "$session"; then
      marker=" *"
    fi
    printf '%s\t%d  %s%s\n' "$session" "$i" "$label" "$marker"
  done < "$PIN_FILE"
}

case "$1" in
toggle)
  session=$(tmux display-message -p '#S')
  if pinned "$session"; then
    unpin "$session"
    tmux display-message "Unpinned $session"
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
  tmux display-message "Pinned $session"
  ;;

pick)
  prune
  if [ ! -s "$PIN_FILE" ]; then
    tmux display-message "No pinned sessions yet - prefix+a pins the current one"
    exit 0
  fi
  fzf_vim_nav_args " Search  "
  selected_line=$(rows | fzf \
    --ansi \
    --exact \
    --prompt=" Search  " \
    --pointer="▶" \
    --border=rounded \
    --height=100% \
    --layout=reverse \
    --info=inline \
    --header="pinned sessions  (ctrl-x unpin)" \
    --delimiter=$'\t' \
    --with-nth=2 \
    --bind "ctrl-x:execute-silent('$SELF' unpin {1})+reload('$SELF' rows)" \
    "${FZF_VIM_NAV_ARGS[@]}" \
    --color="bg+:#313244,bg:#1e1e2e,fg:#cdd6f4,fg+:#ffffff,hl:#f38ba8,hl+:#f38ba8,border:#f38ba8,prompt:#f38ba8,pointer:#f38ba8,marker:#f38ba8,spinner:#f38ba8,header:#9399b2,info:#9399b2")
  [ -z "$selected_line" ] && exit 0
  open_pin "${selected_line%%$'\t'*}"
  ;;

destroy)
  session=$(tmux display-message -p '#S')
  if is_main_session "$session"; then
    tmux display-message "$session is a main session - not destroying it"
    exit 0
  fi
  tmux has-session -t =Sys 2>/dev/null || "$HOME/.config/tmux/bootstrap_sys.sh" --force
  tmux switch-client -t =Sys
  tmux kill-session -t "=$session"
  ;;

rows) rows ;;
unpin) unpin "$2" ;;
open) open_pin "$2" ;;
esac
