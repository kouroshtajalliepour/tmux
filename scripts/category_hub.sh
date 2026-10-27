#!/usr/bin/env bash
# prefix+m: full-screen, game-controller-style hub (like tmux's own
# clock-mode, but a D-pad instead of a clock). Every destination is a
# solid block of its real session color - up/down/left/right each have
# a plain-letter block (jump to last session, or open the picker if
# there isn't one yet) and a Shift-letter block (always open the picker
# / always jump to the fixed session) stacked on top of each other.
# Pressing a key does the exact same thing the matching direct
# prefix+<key> binding does (see project.conf). k/K trigger Packages
# (not j/J) since k sits right next to l on the keyboard, same as
# live-websites - Packages sessions still use the "j-" name prefix
# either way, only the key that reaches them changed.

red="\033[1;38;2;17;17;27;48;2;243;139;168m"
peach="\033[1;38;2;17;17;27;48;2;250;179;135m"
blue="\033[1;38;2;17;17;27;48;2;137;180;250m"
mauve="\033[1;38;2;17;17;27;48;2;203;166;247m"
green="\033[1;38;2;17;17;27;48;2;166;227;161m"
pink="\033[1;38;2;17;17;27;48;2;245;194;231m"
reset="\033[0m"

BW=22  # block width

# Prints one block's 4 lines into the array named by $1 (nameref).
# $2=color $3=key $4=label
build_block() {
  local -n out="$1"
  local color="$2" key="$3" label="$4"
  out=()
  out+=("$(printf "%b%${BW}s%b" "$color" "" "$reset")")
  out+=("$(printf "%b  %-$((BW - 2))s%b" "$color" "$key" "$reset")")
  out+=("$(printf "%b  %-$((BW - 2))s%b" "$color" "$label" "$reset")")
  out+=("$(printf "%b%${BW}s%b" "$color" "" "$reset")")
}

# Prints two blocks (by array name) stacked, each centered at column $3
# within a field of width $4.
print_stack() {
  local -n top="$1"
  local -n bottom="$2"
  local pad="$3"
  local i
  for i in 0 1 2 3; do printf "%${pad}s%s\n" "" "${top[$i]}"; done
  for i in 0 1 2 3; do printf "%${pad}s%s\n" "" "${bottom[$i]}"; done
}

cols=$(tput cols 2>/dev/null || echo 80)
lines=$(tput lines 2>/dev/null || echo 24)
center_pad=$(((cols - BW) / 2))
[ "$center_pad" -lt 0 ] && center_pad=0
gap=10
left_col_pad=$(((cols - 2 * BW - gap) / 2))
[ "$left_col_pad" -lt 0 ] && left_col_pad=0

build_block sys_block "$blue" "j" "Sys"
build_block media_block "$pink" "J" "Media"
build_block h_block "$peach" "h" "Todos (last)"
build_block H_block "$red" "H" "Infra"
build_block l_block "$green" "l" "live-web (last)"
build_block L_block "$green" "L" "live-web (pick)"
build_block pkg_last_block "$mauve" "k" "Packages (last)"
build_block pkg_pick_block "$mauve" "K" "Packages (pick)"

clear
top_gap=$(((lines - 26) / 2))
[ "$top_gap" -lt 0 ] && top_gap=0
for ((i = 0; i < top_gap; i++)); do printf '\n'; done

# top: k/K (Packages), centered - keeps it next to live-websites on the
# right, matching k sitting right next to l on the keyboard
print_stack pkg_last_block pkg_pick_block "$center_pad"
printf '\n'

# middle: h/H on the left, l/L on the right, same rows, side by side
for i in 0 1 2 3; do printf "%${left_col_pad}s%s%${gap}s%s\n" "" "${h_block[$i]}" "" "${l_block[$i]}"; done
for i in 0 1 2 3; do printf "%${left_col_pad}s%s%${gap}s%s\n" "" "${H_block[$i]}" "" "${L_block[$i]}"; done
printf '\n'

# bottom: j/J (Sys/Media), centered
print_stack sys_block media_block "$center_pad"
printf '\n'
printf '  press h/H/j/J/k/K/l/L, or anything else to cancel\n'
printf '  (plain letter = last session or picker if none yet; Shift = always the picker/fixed jump)\n'

read -rsn1 key
clear

root="$(dirname "$0")"
case "$key" in
h) exec tmux switch-client -t Todos ;;
H) exec tmux switch-client -t Infra ;;
j) exec tmux switch-client -t Sys ;;
J) exec tmux switch-client -t Media ;;
k) exec "$root/jump_last.sh" j "$HOME/Documents/Packages" j " Packages " "#cba6f7" ;;
K) exec "$root/tmux-sessionizer" "$HOME/Documents/Packages" j ;;
l) exec "$root/jump_last.sh" l "$HOME/Documents/Projects/live-websites" l " live-websites " "#a6e3a1" ;;
L) exec "$root/tmux-sessionizer" "$HOME/Documents/Projects/live-websites" l ;;
*) exit 0 ;;
esac
