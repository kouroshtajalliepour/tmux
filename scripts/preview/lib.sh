#!/usr/bin/env bash
# Shared by the preview scripts (sourced, not run). The preview browser is
# a separate Firefox (profile "dev", window class firefox-dev) that i3
# keeps on workspace 11, with one tab per project. It has no key of its
# own: the lone alt tap (scripts/alt_toggle.sh), prefix+o and prefix+w take
# you there, showing the project's tab (tabs.py, over the local Marionette port).

PREVIEW_WS=11
PREVIEW_CLASS=firefox-dev
PREVIEW_PROFILE=dev
PREVIEW_REGISTRY=${PREVIEW_REGISTRY:-$HOME/.jarvis/session-bios.tsv}
PREVIEW_TABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tabs.py"

preview_msg() {
  tmux display-message ${TMUX_CLIENT:+-c "$TMUX_CLIENT"} "$1" 2>/dev/null || notify-send "preview" "$1"
}

port_listening() {
  ss -ltnH "( sport = :$1 )" 2>/dev/null | grep -q .
}

# Firefox's profiles.ini lives in either place depending on the version
firefox_has_profile() {
  local ini
  for ini in "$HOME/.config/mozilla/firefox/profiles.ini" "$HOME/.mozilla/firefox/profiles.ini"; do
    grep -qx "Name=$1" "$ini" 2>/dev/null && return 0
  done
  return 1
}

# Show $1 in the preview browser on workspace 11, in that project's own tab.
# An existing tab is only focused, never reloaded, so the page keeps its state.
open_in_preview() {
  local url=$1 win
  # PREVIEW_NO_OPEN=1: stop before touching the screen (for testing)
  [ -n "$PREVIEW_NO_OPEN" ] && { echo "would open $url"; return 0; }
  if ! command -v xdotool >/dev/null; then
    preview_msg "the preview needs xdotool: sudo pacman -S xdotool"
    return 1
  fi
  win=$(xdotool search --class "$PREVIEW_CLASS" 2>/dev/null | tail -1)
  i3-msg -q workspace number "$PREVIEW_WS"
  if [ -n "$win" ]; then
    xdotool windowactivate "$win"
    python3 -I "$PREVIEW_TABS" show "$url" >/dev/null 2>&1
    case $? in
    0) ;;
    3) preview_msg "preview: close the preview Firefox once so it restarts with tab control" ;;
    *) preview_msg "preview: couldn't switch to the tab for $url" ;;
    esac
  else
    firefox_has_profile "$PREVIEW_PROFILE" || firefox -CreateProfile "$PREVIEW_PROFILE" >/dev/null 2>&1
    setsid -f firefox --new-instance -P "$PREVIEW_PROFILE" --class "$PREVIEW_CLASS" --marionette "$url" >/dev/null 2>&1
  fi
}

# The session whose preview runs on port $1, from the registry.
session_for_port() {
  awk -F'\t' -v p="$1" '$0 !~ /^#/ && $3 == p { print $1; exit }' "$PREVIEW_REGISTRY" 2>/dev/null
}

# The port of the registered preview for session $1.
port_for_session() {
  awk -F'\t' -v s="$1" '$0 !~ /^#/ && $1 == s { print $3; exit }' "$PREVIEW_REGISTRY" 2>/dev/null
}
