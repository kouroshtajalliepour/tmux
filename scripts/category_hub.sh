#!/usr/bin/env bash
# prefix+m: PlayStation-button-style hub. Press a key for the exact same
# thing the matching direct prefix+<key> binding does (see project.conf) -
# h/H/k/K jump straight to the four fixed sessions (Todos/Infra/Sys/
# Media). j/l jump to the LAST Packages/live-websites session you were
# in, falling back to the picker if there isn't one yet; J/L always
# open the picker directly.
#
#               k  Sys          K  Media
#   h  Todos            l/L  live-websites
#   H  Infra            j/J  Packages

red="\033[1;38;2;17;17;27;48;2;243;139;168m"
peach="\033[1;38;2;17;17;27;48;2;250;179;135m"
blue="\033[1;38;2;17;17;27;48;2;137;180;250m"
mauve="\033[1;38;2;17;17;27;48;2;203;166;247m"
green="\033[1;38;2;17;17;27;48;2;166;227;161m"
pink="\033[1;38;2;17;17;27;48;2;245;194;231m"
reset="\033[0m"

clear
printf '\n\n'
printf '                    %b  k  %b  Sys          %b  K  %b  Media\n\n' "$blue" "$reset" "$pink" "$reset"
printf '      %b  h  %b  Todos            %b  l  %b  live-websites\n\n' "$peach" "$reset" "$green" "$reset"
printf '      %b  H  %b  Infra            %b  j  %b  Packages\n\n\n' "$red" "$reset" "$mauve" "$reset"
printf '  (Shift+j/l always opens the picker instead of your last session)\n'
printf '  press a key, or anything else to cancel: '

read -rsn1 key
printf '\n'

root="$(dirname "$0")"
case "$key" in
h) exec tmux switch-client -t Todos ;;
H) exec tmux switch-client -t Infra ;;
j) exec "$root/jump_last.sh" j "$HOME/Documents/Packages" j " Packages " "#cba6f7" ;;
J) exec "$root/tmux-sessionizer" "$HOME/Documents/Packages" j ;;
k) exec tmux switch-client -t Sys ;;
K) exec tmux switch-client -t Media ;;
l) exec "$root/jump_last.sh" l "$HOME/Documents/Projects/live-websites" l " live-websites " "#a6e3a1" ;;
L) exec "$root/tmux-sessionizer" "$HOME/Documents/Projects/live-websites" l ;;
*) exit 0 ;;
esac
