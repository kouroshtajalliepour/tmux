#!/usr/bin/env bash
# Shared fzf setup for the tmux pickers (sourced, not run directly).

FZF_CATPPUCCIN_COLOR='bg+:#313244,bg:#1e1e2e,fg:#cdd6f4,fg+:#ffffff,hl:#89b4fa,hl+:#89b4fa,border:#89b4fa,prompt:#89b4fa,pointer:#89b4fa,marker:#89b4fa,spinner:#89b4fa,header:#9399b2,info:#9399b2'

# Fills FZF_VIM_NAV_ARGS with:
#   - tab/shift-tab always move the selection down/up
#   - ctrl-c always closes the picker
#   - esc toggles between typing the query and a lightweight vim-motion
#     mode (j/k move, g/G jump top/bottom); it never closes the picker.
#     Enter still accepts in either mode.
# $1: the picker's normal prompt string, restored when leaving nav mode.
fzf_vim_nav_args() {
  local prompt="$1"
  FZF_VIM_NAV_ARGS=(
    --bind "start:unbind(j,k,g,G)"
    --bind "tab:down,shift-tab:up"
    --bind "ctrl-c:abort"
    --bind "j:down"
    --bind "k:up"
    --bind "g:first"
    --bind "G:last"
    --bind "esc:transform:case \"\$FZF_PROMPT\" in *NAV*) printf 'unbind(j,k,g,G)+change-prompt(${prompt})';; *) printf 'rebind(j,k,g,G)+change-prompt( NAV  )';; esac"
  )
}
