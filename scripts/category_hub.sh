#!/usr/bin/env bash
# prefix+m: PlayStation-button-style hub. Press a key for the exact same
# thing the matching direct prefix+<key> binding does (see project.conf) -
# h/H/k/K jump straight to the four fixed sessions (Todos/Infra/Sys/
# Media), j/l open their picker (same worktree-aware tmux-sessionizer,
# scoped to a different root directory + session-name prefix letter
# each).
#
#               k  Sys          K  Media
#   h  Todos            l  live-websites
#   H  Infra            j  Packages

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
printf '  press a key, or anything else to cancel: '

read -rsn1 key
printf '\n'

root="$(dirname "$0")"
case "$key" in
h) exec tmux switch-client -t Todos ;;
H) exec tmux switch-client -t Infra ;;
j) exec "$root/tmux-sessionizer" "$HOME/Documents/Packages" j ;;
k) exec tmux switch-client -t Sys ;;
K) exec tmux switch-client -t Media ;;
l) exec "$root/tmux-sessionizer" "$HOME/Documents/Projects/live-websites" l ;;
*) exit 0 ;;
esac
