#!/usr/bin/env bash
# prefix+S: PlayStation-button-style hub. Press h/j/k/l to jump into that
# category's project picker (same worktree-aware tmux-sessionizer logic
# everywhere, just scoped to a different root directory + session-name
# prefix letter per category - see the prefix+h/j/k/l bindings in
# project.conf for the direct-access versions of the same four).
#
#               k  Infra
#   h  Config          l  Packages
#               j  Projects

red="\033[1;38;2;17;17;27;48;2;243;139;168m"
peach="\033[1;38;2;17;17;27;48;2;250;179;135m"
blue="\033[1;38;2;17;17;27;48;2;137;180;250m"
mauve="\033[1;38;2;17;17;27;48;2;203;166;247m"
reset="\033[0m"

clear
printf '\n\n'
printf '                    %b  k  %b  Infra\n\n' "$blue" "$reset"
printf '      %b  h  %b  Config          %b  l  %b  Packages\n\n' "$red" "$reset" "$mauve" "$reset"
printf '                    %b  j  %b  Projects\n\n\n' "$peach" "$reset"
printf '  press h / j / k / l, or anything else to cancel: '

read -rsn1 key
printf '\n'

root="$(dirname "$0")"
case "$key" in
h) exec "$root/tmux-sessionizer" "$HOME/.config" h ;;
j) exec "$root/tmux-sessionizer" "$HOME/Documents/Projects" j ;;
k) exec "$root/tmux-sessionizer" "$HOME/Documents/Infra" k ;;
l) exec "$root/tmux-sessionizer" "$HOME/Documents/Packages" l ;;
*) exit 0 ;;
esac
