#!/bin/bash

tmux has-session -t sys 2>/dev/null

if [ $? != 0 ]; then
    tmux new-session -d -s sys -n main

    tmux new-window -t sys -n vpn
    tmux new-window -t sys -n networking
    tmux new-window -t sys -n ssh
    tmux new-window -t sys -n logs
fi
