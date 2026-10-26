#!/usr/bin/env bash
# prefix+S: PlayStation-button-style hub. Press h/j/k/l to jump into that
# category's project picker (same tmux-sessionizer logic everywhere,
# just scoped to a different root directory + session-name prefix
# letter per category - colors stay tied to the letter, not what it
# currently points to).
#
#               k  Sys
#   h  Config          l  live-websites
#               j  Packages

red="\033[1;38;2;17;17;27;48;2;243;139;168m"
peach="\033[1;38;2;17;17;27;48;2;250;179;135m"
blue="\033[1;38;2;17;17;27;48;2;137;180;250m"
mauve="\033[1;38;2;17;17;27;48;2;203;166;247m"
reset="\033[0m"

clear
printf '\n\n'
printf '                    %b  k  %b  Sys\n\n' "$blue" "$reset"
printf '      %b  h  %b  Config          %b  l  %b  live-websites\n\n' "$red" "$reset" "$mauve" "$reset"
printf '                    %b  j  %b  Packages\n\n\n' "$peach" "$reset"
printf '  press h / j / k / l, or anything else to cancel: '

read -rsn1 key
printf '\n'

root="$(dirname "$0")"
case "$key" in
h) exec "$root/tmux-sessionizer" "$HOME/.config" h ;;
j) exec "$root/tmux-sessionizer" "$HOME/Documents/Packages" j ;;
k) exec "$root/tmux-sessionizer" "$HOME/Documents/Infra" k ;;
l) exec "$root/tmux-sessionizer" "$HOME/Documents/Projects/live-websites" l ;;
*) exit 0 ;;
esac
