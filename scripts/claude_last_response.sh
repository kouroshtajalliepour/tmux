#!/usr/bin/env bash
# prefix+G: open the last response of the Claude running in this pane in nvim.
# $1: the pane's shell pid. Claude's registry maps its process to its session.
fail() {
  echo "$1"
  sleep 2
  exit 0
}

pane_pid="$1"
out="${XDG_RUNTIME_DIR:-/tmp}/claude-last-response-${pane_pid}.md"

pid=$(pgrep -P "$pane_pid" -x claude | head -1)
[ -z "$pid" ] && [ "$(ps -o comm= -p "$pane_pid")" = "claude" ] && pid="$pane_pid"
[ -z "$pid" ] && fail "No Claude running in this pane"

session_id=$(jq -r '.sessionId // empty' "$HOME/.claude/sessions/$pid.json" 2>/dev/null)
[ -z "$session_id" ] && fail "Claude session not found for process $pid"

transcript=$(find "$HOME/.claude/projects" -maxdepth 2 -name "$session_id.jsonl" -print -quit)
[ -z "$transcript" ] && fail "No transcript yet for this session"

jq -rs '
  map(select(.type == "assistant" and (.isSidechain | not))
      | .message.content
      | if type == "string" then . else (map(select(.type == "text").text) | join("\n\n")) end
      | select(. != ""))
  | last // empty
' "$transcript" >"$out"

[ -s "$out" ] || fail "No response yet in this session"

exec nvim -R -- "$out"
