#!/usr/bin/env bash
# Shared helpers for the project-session scripts (sourced, not run directly).

# Prints the window index in session $1 whose name is exactly $2, or
# nothing if there isn't one.
project_window_index() {
  tmux list-windows -t "$1" -F '#{window_index} #{window_name}' 2>/dev/null \
    | awk -v n="$2" '$2 == n {print $1; exit}'
}
