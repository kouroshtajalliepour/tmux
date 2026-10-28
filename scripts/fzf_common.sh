#!/usr/bin/env bash
# Shared fzf setup for the tmux pickers (sourced, not run directly).

# shellcheck disable=SC2034 # used by scripts that source this file, not here
FZF_CATPPUCCIN_COLOR='bg+:#313244,bg:#1e1e2e,fg:#cdd6f4,fg+:#ffffff,hl:#89b4fa,hl+:#89b4fa,border:#89b4fa,prompt:#89b4fa,pointer:#89b4fa,marker:#89b4fa,spinner:#89b4fa,header:#9399b2,info:#9399b2'

# Fills FZF_VIM_NAV_ARGS with:
#   - tab/shift-tab always move the selection down/up
#   - ctrl-c always closes the picker
#   - esc toggles between typing the query and a lightweight vim-motion
#     mode (j/k move, g/G jump top/bottom, 1-9 jump straight to and
#     accept the Nth visible row); it never closes the picker. Enter
#     still accepts in either mode.
# $1: the picker's normal prompt string, restored when leaving nav mode.
#
# --with-shell "bash -c" matters: fzf runs transform/execute actions via
# $SHELL -c, and since fish is now tmux's default-shell, $SHELL is fish
# inside every pane - fish can't parse the bash case/esac below (or any
# bash-specific syntax) and silently no-ops, which is why the esc toggle
# (and anything like it) stopped working. Verified: without this flag,
# `echo one; echo two` still ran (valid in both shells), but case/esac and
# if/then/fi never did. This flag makes fzf run these commands through
# bash regardless of the pane's actual shell.
fzf_vim_nav_args() {
  local prompt="$1"
  # shellcheck disable=SC2034 # read by the caller that sourced this file, not here
  FZF_VIM_NAV_ARGS=(
    --with-shell "bash -c"
    --bind "start:unbind(j,k,g,G,1,2,3,4,5,6,7,8,9)"
    --bind "tab:down,shift-tab:up"
    --bind "ctrl-c:abort"
    --bind "j:down"
    --bind "k:up"
    --bind "g:first"
    --bind "G:last"
    --bind "1:pos(1)+accept"
    --bind "2:pos(2)+accept"
    --bind "3:pos(3)+accept"
    --bind "4:pos(4)+accept"
    --bind "5:pos(5)+accept"
    --bind "6:pos(6)+accept"
    --bind "7:pos(7)+accept"
    --bind "8:pos(8)+accept"
    --bind "9:pos(9)+accept"
    --bind "esc:transform:case \"\$FZF_PROMPT\" in *NAV*) printf 'unbind(j,k,g,G,1,2,3,4,5,6,7,8,9)+change-prompt(${prompt})';; *) printf 'rebind(j,k,g,G,1,2,3,4,5,6,7,8,9)+change-prompt( NAV  )';; esac"
  )
}
