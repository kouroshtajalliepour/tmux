#!/bin/bash
# Load this config in the tmux that ships with each prod distro and fail on
# any error - catches options/formats newer than that tmux version.
# Usage: ./test.sh   (needs docker; DOCKER=podman works too)

cd "$(dirname "$0")" || exit 1
fail=0

for img in ubuntu:24.04 quay.io/centos/centos:stream9; do
    ${DOCKER:-docker} run --rm -v "$PWD":/root/.config/tmux:ro "$img" bash -c '
        if ! { apt-get update -qq && apt-get install -yqq tmux git ||
               dnf install -yq tmux git-core; } >/tmp/install.log 2>&1; then
            cat /tmp/install.log
            exit 2
        fi
        git clone -q --depth 1 https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm || exit 2
        tmux -V
        tmux new-session -d &&
            tmux source-file ~/.config/tmux/tmux.conf &&
            [ "$(tmux show -gv status-position)" = bottom ] &&
            tmux has-session -t "=$(tmux display-message -p "#{host_short}" | tr .: __)" &&
            [ "$(tmux list-sessions | wc -l)" = 2 ] &&
            tmux list-keys -T prefix f >/dev/null &&
            ! tmux list-keys -T prefix s >/dev/null 2>&1'
    case $? in
        0) echo "OK           $img" ;;
        2) echo "INSTALL FAIL $img"; fail=1 ;;
        *) echo "CONFIG FAIL  $img"; fail=1 ;;
    esac
done

exit $fail
