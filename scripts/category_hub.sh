#!/usr/bin/env bash
# shellcheck disable=SC2154 # the *_block arrays are set by build_block's nameref, not visible to shellcheck
# prefix+m: full-screen, game-controller-style hub (like tmux's own
# clock-mode, but a D-pad instead of a clock). Each direction is one repo
# category under ~/Documents/repos, as one solid block of its session
# color - the plain letter opens the branch picker for that category's
# last project (or its project picker if there isn't one yet), the Shift
# letter always opens the project picker:
#   k/K Packages (mauve)   l/L Live (green)
#   h/H Training (yellow)  j/J Infra repos (teal)
# plus a row for the 4 main sessions: 1 Sys, 2 Infra, 3 Media, 4 Todos.
# It sizes itself to the screen (see "layout" below), so it also fits the
# small alt+` drop-down. prefix+H/J/K/L are the same pickers without the
# hub. Sessions opened
# through any of them are pinned automatically.
red="\033[1;38;2;17;17;27;48;2;243;139;168m"
peach="\033[1;38;2;17;17;27;48;2;250;179;135m"
blue="\033[1;38;2;17;17;27;48;2;137;180;250m"
mauve="\033[1;38;2;17;17;27;48;2;203;166;247m"
green="\033[1;38;2;17;17;27;48;2;166;227;161m"
pink="\033[1;38;2;17;17;27;48;2;245;194;231m"
teal="\033[1;38;2;17;17;27;48;2;148;226;213m"
yellow="\033[1;38;2;17;17;27;48;2;249;226;175m"
reset="\033[0m"

# ---- layout: fits whatever the popup gives it (full screen on a laptop,
# the small alt+` drop-down, ...). Picks the biggest block height that
# fits - 4 lines, then 2, then 1 - and narrows the blocks / gap on narrow
# screens; on a tiny one it falls back to a plain list. Nothing may
# overflow: an overflowing popup scrolls and the top (k) row disappears.
cols=$(tput cols 2>/dev/null || echo 80)
lines=$(tput lines 2>/dev/null || echo 24)

BW=29   # block width
gap=8   # between the left and right column
if [ "$cols" -lt $((2 * BW + gap + 2)) ]; then
  gap=4
  BW=$(((cols - gap - 2) / 2))
fi
# the key line inside each block, longest that fits
w=$((BW - 2))
if [ "$w" -ge 25 ]; then keyfmt="%s: branches  %s: pick repo"
elif [ "$w" -ge 18 ]; then keyfmt="%s branches · %s repo"
else keyfmt="%s · %s"; fi

# hint line, longest that fits
for hint in \
  "h/j/k/l = that category's last project's branches · H/J/K/L = project picker · 1-4 = main session · any other key cancels" \
  "hjkl: last project's branches · HJKL: pickers · 1-4: main · other: cancel" \
  "hjkl branches · HJKL pickers · 1-4 main"; do
  [ "${#hint}" -le $((cols - 2)) ] && break
done

# 3 rows of blocks (3*BH) + blanks after top/middle/bottom (3)
# + main-session row + blank + hint = 3*BH + 6
BH=0
if [ "$BW" -ge 14 ]; then
  for h in 4 2 1; do
    [ $((3 * h + 6)) -le "$lines" ] && { BH=$h; break; }
  done
fi

# Fills the array named by $1 with one block's BH lines: the category
# name, then its two keys (lowercase = last project's branches, Shift =
# project picker).
# $2=color $3=key $4=title
build_block() {
  local -n out="$1"
  local color="$2" key="$3" title="$4" keys
  # shellcheck disable=SC2059 # keyfmt is our own format string
  keys=$(printf "$keyfmt" "$key" "${key^^}")
  out=()
  case "$BH" in
  4)
    out+=("$(printf "%b%${BW}s%b" "$color" "" "$reset")")
    out+=("$(printf "%b  %-${w}.${w}s%b" "$color" "$title" "$reset")")
    out+=("$(printf "%b  %-${w}.${w}s%b" "$color" "$keys" "$reset")")
    out+=("$(printf "%b%${BW}s%b" "$color" "" "$reset")")
    ;;
  2)
    out+=("$(printf "%b  %-${w}.${w}s%b" "$color" "$title" "$reset")")
    out+=("$(printf "%b  %-${w}.${w}s%b" "$color" "$keys" "$reset")")
    ;;
  1)
    out+=("$(printf "%b %-$((BW - 1)).$((BW - 1))s%b" "$color" "$title  ${key}/${key^^}" "$reset")")
    ;;
  esac
}

center_pad=$(((cols - BW) / 2)); [ "$center_pad" -lt 0 ] && center_pad=0
left_col_pad=$(((cols - 2 * BW - gap) / 2)); [ "$left_col_pad" -lt 0 ] && left_col_pad=0

# one block, centered
print_center() {
  local -n blk="$1"
  local l
  for l in "${blk[@]}"; do printf "%${center_pad}s%s\n" "" "$l"; done
}

# two blocks side by side
print_pair() {
  local -n a="$1" b="$2"
  local i
  for ((i = 0; i < BH; i++)); do printf "%${left_col_pad}s%s%${gap}s%s\n" "" "${a[$i]}" "" "${b[$i]}"; done
}

if [ "$cols" -ge 42 ]; then
  chips="$(printf "%b 1 Sys %b  %b 2 Infra %b  %b 3 Media %b  %b 4 Todos %b" "$blue" "$reset" "$red" "$reset" "$pink" "$reset" "$peach" "$reset")"
  chips_w=40
else
  chips="$(printf "%b1 Sys%b %b2 Inf%b %b3 Med%b %b4 Tod%b" "$blue" "$reset" "$red" "$reset" "$pink" "$reset" "$peach" "$reset")"
  chips_w=23
fi
chips_pad=$(((cols - chips_w) / 2)); [ "$chips_pad" -lt 0 ] && chips_pad=0
hint_pad=$(((cols - ${#hint}) / 2)); [ "$hint_pad" -lt 0 ] && hint_pad=0

clear
if [ "$BH" -eq 0 ]; then
  # too small for blocks: a plain list
  printf '%b k/K %b Packages\n' "$mauve" "$reset"
  printf '%b l/L %b Live\n' "$green" "$reset"
  printf '%b h/H %b Training\n' "$yellow" "$reset"
  printf '%b j/J %b Infra\n' "$teal" "$reset"
  printf '%s\n' "$chips"
else
  build_block pkg_block "$mauve" "k" "Packages"
  build_block training_block "$yellow" "h" "Training"
  build_block live_block "$green" "l" "Live"
  build_block infra_block "$teal" "j" "Infra"

  top_gap=$(((lines - (3 * BH + 6)) / 2)); [ "$top_gap" -lt 0 ] && top_gap=0
  for ((i = 0; i < top_gap; i++)); do printf '\n'; done

  # top: k/K (Packages), centered - next to Live on the right, the way
  # k sits next to l on the keyboard
  print_center pkg_block
  printf '\n'
  # middle: h/H Training left, l/L Live right
  print_pair training_block live_block
  printf '\n'
  # bottom: j/J Infra repos, centered
  print_center infra_block
  printf '\n'
  printf "%${chips_pad}s%s\n\n" "" "$chips"
  printf "%${hint_pad}s%s" "" "$hint"
fi

read -rsn1 key
clear

root="$(dirname "$0")"
repos="$HOME/Documents/repos"
case "$key" in
1) exec tmux switch-client -t =Sys ;;
2) exec tmux switch-client -t =Infra ;;
3) exec tmux switch-client -t =Media ;;
4) exec tmux switch-client -t =Todos ;;
h) exec "$root/jump_last.sh" t "$repos/training" t " Training " "#f9e2af" ;;
H) exec "$root/training_picker.sh" "$repos/training" ;;
j) exec "$root/jump_last.sh" i "$repos/infra" i " Infra " "#94e2d5" ;;
J) exec "$root/tmux-sessionizer" "$repos/infra" i ;;
k) exec "$root/jump_last.sh" j "$repos/packages" j " Packages " "#cba6f7" ;;
K) exec "$root/tmux-sessionizer" "$repos/packages" j ;;
l) exec "$root/jump_last.sh" l "$repos/live" l " Live " "#a6e3a1" ;;
L) exec "$root/tmux-sessionizer" "$repos/live" l ;;
*) exit 0 ;;
esac
