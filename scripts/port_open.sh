#!/usr/bin/env bash
# prefix+O (and prefix+o outside a known project): pick a localhost port -
# the ones your own processes listen on, labelled with the project and
# branch they were started from - or type one, and show it in the preview
# browser on workspace 11 (scripts/preview/lib.sh).
source "$(dirname "$0")/fzf_common.sh"
source "$(dirname "$0")/preview/lib.sh"
fzf_vim_nav_args " Port  "

# "port<TAB>label" for each port a process of yours listens on locally
rows() {
  ss -ltnpH 2>/dev/null | awk '
    $4 ~ /^(127\.0\.0\.1|0\.0\.0\.0|\[::1\]|\[::\]|\*):[0-9]+$/ && match($0, /pid=[0-9]+/) {
      port = $4; sub(/.*:/, "", port)
      pid = substr($0, RSTART + 4, RLENGTH - 4)
      cmd = $0; sub(/.*users:\(\("/, "", cmd); sub(/".*/, "", cmd)
      print port "\t" pid "\t" cmd
    }' | sort -u -t$'\t' -k1,1n | while IFS=$'\t' read -r port pid cmd; do
    cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null)
    label=$cmd
    # ~/Documents/repos/<category>/<project>/<branch>/... -> "<project> <branch>"
    if [[ $cwd =~ ^$HOME/Documents/repos/[^/]+/([^/]+)/([^/]+) ]]; then
      label="${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
      rest=${cwd#"$HOME/Documents/repos/"*/*/*/}
      [ "$rest" != "$cwd" ] && [ -n "$rest" ] && label="$label  ($(basename "$rest"))"
    fi
    printf '%s\t%s\n' "$port" "$label"
  done
}

[ "$1" = "--rows" ] && { rows; exit 0; }

out=$(rows | fzf \
  --print-query \
  --prompt=" Port  " \
  --pointer="▶" \
  --border=rounded \
  --height=100% \
  --layout=reverse \
  --info=inline \
  --header="pick a dev server, or type a port and Enter" \
  --delimiter=$'\t' \
  "${FZF_VIM_NAV_ARGS[@]}" \
  --color="$FZF_CATPPUCCIN_COLOR")
# 130 = Esc/ctrl-c; 1 = no row matched, which is fine when a port was typed
[ $? -eq 130 ] && exit 0

query=$(sed -n 1p <<<"$out")
picked=$(sed -n 2p <<<"$out")
if [ -n "$picked" ]; then
  port=${picked%%$'\t'*}
else
  port=${query//[^0-9]/}
fi
[[ $port =~ ^[0-9]+$ ]] && [ "$port" -le 65535 ] || exit 0

open_in_preview "http://localhost:$port/"
