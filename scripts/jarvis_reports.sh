#!/usr/bin/env bash
# prefix+i: pick reports from ~/.jarvis, newest first, with a preview.
# Type to filter. ctrl-space marks rows, alt-a takes everything the filter
# shows. One report opens normally; several open as one read-only nvim file.
source "$(dirname "$0")/fzf_common.sh"
fzf_vim_nav_args " Reports  "

dir="$HOME/.jarvis"
combined="${XDG_RUNTIME_DIR:-/tmp}/jarvis-combined.md"

names=$(cd "$dir" 2>/dev/null && ls -1t -- *.md 2>/dev/null)
if [ -z "$names" ]; then
  echo "No reports in $dir"
  sleep 1
  exit 0
fi

selected=$(printf '%s\n' "$names" | fzf \
  --multi \
  --exact \
  --prompt=" Reports  " \
  --pointer="▶" \
  --marker="●" \
  --border=rounded \
  --height=100% \
  --layout=reverse \
  --info=inline \
  --header="ctrl-space mark · alt-a all filtered · enter open" \
  --preview="cat -- '$dir'/{}" \
  --preview-window=down,60% \
  "${FZF_VIM_NAV_ARGS[@]}" \
  --bind "ctrl-space:toggle+down" \
  --bind "alt-a:select-all+accept" \
  --color="$FZF_CATPPUCCIN_COLOR")

[ -z "$selected" ] && exit 0

if [ "$(printf '%s\n' "$selected" | wc -l)" -eq 1 ]; then
  exec nvim -- "$dir/$selected"
fi

while IFS= read -r name; do
  printf '# ===== %s =====\n\n' "$name"
  cat -- "$dir/$name"
  printf '\n\n'
done <<<"$selected" >"$combined"

exec nvim -R -- "$combined"
