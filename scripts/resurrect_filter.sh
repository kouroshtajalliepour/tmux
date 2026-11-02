#!/usr/bin/env bash
# tmux-resurrect post-save-layout hook ($1 = the save file just written):
# strips every session except the 4 main ones (Sys, Infra, Media, Todos)
# so a restart only brings those back. Project sessions are rebuilt on
# demand from the pickers/pins anyway - restoring them all at boot just
# burned RAM. The "state" line (which session the client was on) is
# pointed at Sys if it named a dropped session.
file=$(readlink -f "$1")
[ -f "$file" ] || exit 0

tmp=$(mktemp "${file}.XXXX")
awk -F'\t' -v OFS='\t' '
  function keep(s) { return s == "Sys" || s == "Infra" || s == "Media" || s == "Todos" }
  $1 == "pane" || $1 == "window" || $1 == "grouped_session" { if (keep($2)) print; next }
  $1 == "state" { if (!keep($2)) $2 = "Sys"; if (!keep($3)) $3 = "Sys"; print; next }
  { print }
' "$file" > "$tmp" && chmod 644 "$tmp" && mv "$tmp" "$file"
