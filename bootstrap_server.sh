#!/bin/bash
# production: the one session this branch has, named after the machine:
# tmux's #{host_short} (the hostname up to the first "."), with "." and ":"
# turned into "_", since tmux reads them as window/pane separators. Made
# when the tmux server boots (run from conf/project.conf); prefix+f
# searches its windows.
name=$(tmux display-message -p "#{host_short}")
name=${name//[.:]/_}
if ! tmux has-session -t "=$name" 2>/dev/null; then
    tmux new-session -d -s "$name" -n main -c "$HOME"
fi
