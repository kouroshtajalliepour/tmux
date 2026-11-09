#!/usr/bin/env bash
# Project type "vue": <session> <port> <dir>. Starts the dev server in
# window 6 "dev" of that session when nothing listens on the port yet,
# waits for it (up to 30 s), then shows http://localhost:<port>/ in the
# preview browser.
source "$(dirname "$0")/lib.sh"
session=$1 port=$2 dir=$3
name=${session#*-}

if ! port_listening "$port"; then
  if ! tmux list-windows -t "=$session" -F '#{window_name}' 2>/dev/null | grep -qx dev; then
    if [ ! -d "$dir" ]; then
      preview_msg "preview: $dir doesn't exist ($session)"
      exit 1
    fi
    tmux new-window -d -t "=$session:6" -n dev -c "$dir" "pnpm dev --port $port --strictPort; exec \$SHELL" 2>/dev/null ||
      tmux new-window -d -t "=$session:" -n dev -c "$dir" "pnpm dev --port $port --strictPort; exec \$SHELL"
  fi
  preview_msg "starting $name on $port..."
  for _ in $(seq 60); do
    port_listening "$port" && break
    sleep 0.5
  done
  if ! port_listening "$port"; then
    preview_msg "$name didn't come up on $port in 30 s - check its window 6 (dev)"
    exit 1
  fi
fi

open_in_preview "http://localhost:$port/"
