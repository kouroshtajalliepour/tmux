#!/usr/bin/env bash
# Shared fzf setup for the tmux pickers (sourced, not run directly).

FZF_CATPPUCCIN_COLOR='bg+:#313244,bg:#1e1e2e,fg:#cdd6f4,fg+:#ffffff,hl:#cba6f7,hl+:#cba6f7,border:#cba6f7,prompt:#cba6f7,pointer:#cba6f7,marker:#cba6f7,spinner:#cba6f7,header:#9399b2,info:#9399b2'

# Fills FZF_VIM_NAV_ARGS with:
#   - tab/shift-tab always move the selection down/up
#   - a lightweight vim-motion mode: esc switches from typing the query
#     into navigating with j/k (move) and g/G (top/bottom); i switches
#     back to typing. Enter still accepts either way.
# $1: the picker's normal prompt string, restored when leaving nav mode.
fzf_vim_nav_args() {
  local prompt="$1"
  FZF_VIM_NAV_ARGS=(
    --bind "start:unbind(j,k,g,G,i)"
    --bind "tab:down,shift-tab:up"
    --bind "j:down"
    --bind "k:up"
    --bind "g:first"
    --bind "G:last"
    --bind "esc:unbind(esc)+rebind(j,k,g,G,i)+change-prompt( NAV  )"
    --bind "i:unbind(j,k,g,G,i)+rebind(esc)+change-prompt(${prompt})"
  )
}
