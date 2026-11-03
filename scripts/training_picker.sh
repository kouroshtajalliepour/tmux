#!/usr/bin/env bash
# prefix+H / hub H: Training - the people Kourosh mentors, one folder each
# under ~/Documents/repos/training/<Person>/ (dashes in the folder name
# show as spaces: Tarokh-Bostani -> "Tarokh Bostani"). Pick the person,
# then tmux-sessionizer lists their repos - same project picker as
# Packages/Live/Infra, with session prefix "t" and the person in front of
# the project name (t-Tarokh-Bostani-mavida-recreation-master). A plain
# repo is converted to a worktree container the first time it's opened,
# like everywhere else.
#
# $1 = training root (default ~/Documents/repos/training)

source "$(dirname "$0")/fzf_common.sh"
fzf_vim_nav_args " Person  "

ROOT="${1:-$HOME/Documents/repos/training}"
accent="#f9e2af"

rows=""
i=0
for d in "$ROOT"/*/; do
  [ -d "$d" ] || continue
  i=$((i + 1))
  person=$(basename "$d")
  rows="${rows}${person}"$'\t'"$(printf '%d  %s' "$i" "${person//-/ }")"$'\n'
done

if [ -z "$rows" ]; then
  tmux display-message "No one in $ROOT yet"
  exit 0
fi

selected=$(printf '%s' "$rows" | sed '/^$/d' | fzf \
  --exact \
  --prompt=" Person  " \
  --pointer="▶" \
  --border=rounded \
  --height=100% \
  --layout=reverse \
  --info=inline \
  --header="training" \
  --delimiter=$'\t' \
  --with-nth=2 \
  "${FZF_VIM_NAV_ARGS[@]}" \
  --color="bg+:#313244,bg:#1e1e2e,fg:#cdd6f4,fg+:#ffffff,hl:${accent},hl+:${accent},border:${accent},prompt:${accent},pointer:${accent},marker:${accent},spinner:${accent},header:#9399b2,info:#9399b2")

[ -z "$selected" ] && exit 0
person=${selected%%$'\t'*}
exec "$(dirname "$0")/tmux-sessionizer" "$ROOT/$person" t "$person"
