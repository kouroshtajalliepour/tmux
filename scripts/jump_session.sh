#!/usr/bin/env bash
# prefix+<N>: jump straight to whichever saved session is named "N-..."
# (0-media, 1-Sys, 2-Docs, 3-ssh, ...). No-op if that number isn't in use,
# so it's safe even for numbers you haven't assigned a session to yet.
n="$1"
target=$(tmux list-sessions -F '#{session_name}' | grep -i "^${n}-" | head -1)
[ -n "$target" ] && tmux switch-client -t "$target"
