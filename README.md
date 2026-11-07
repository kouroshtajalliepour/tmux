# tmux (production branch)

The stripped-down variant of this tmux config, for machines that don't need
the project switcher on `master`. It keeps the look (Catppuccin Mocha) and a
single fuzzy session switcher; everything else is plain tmux.

Compared to `master`:

- prefix is `Ctrl+s` instead of `Ctrl+b`
- status bar on the bottom instead of the top
- one session, named after the machine's short hostname (tmux's `#{host_short}`,
  with `.`/`:` turned into `_`), made on boot by `bootstrap_server.sh`. None of
  master's personal sessions (Sys, Media, Todos, Infra), and no category
  pickers, hub, pins or branch switching
- `prefix+f` searches the windows, like master's `f` in its main
  sessions; `prefix+s` is unbound, like on master
- copy-mode `y` copies over SSH with OSC 52 (`set-clipboard on`), no xclip
- tmux-continuum's auto-restore is off, since resurrect's save file isn't
  branch-scoped

## Install

This repo lives at `~/Documents/Packages/tmux/<branch>/` (one git worktree
per branch - this one is `production/`). tmux itself only ever reads
`~/.config/tmux`, which is a symlink to whichever branch the machine uses:

```sh
ln -sfn ~/Documents/Packages/tmux/production ~/.config/tmux
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

Start it with `tmux new -A -s "$(uname -n | cut -d. -f1)"` (a bare `tmux`
would add a second, numbered session next to it). Then `prefix+I` inside
tmux to install the plugins. Every path in the
config is written as `~/.config/tmux/...`, so it follows the symlink.

Expects `fzf` (window search) and `git` (status bar). fish becomes the
default shell if it's at `/usr/bin/fish`; otherwise the login shell is used.
`./test.sh` loads the config in the tmux of Ubuntu 24.04 and CentOS Stream 9
(needs docker or podman).

## Keybindings

| Key | Action |
|---|---|
| `prefix+f` | Fuzzy search over the windows |
| `prefix+h/j/k/l` | Move between panes |
| `y` (copy-mode-vi) | Copy selection to the system clipboard |

## Structure

- `tmux.conf` - entry point, sources `conf/` and starts tpm.
- `conf/` - the config split by concern: `general.conf` (options, prefix,
  plugins), `bindings.conf`, `theme.conf`, `project.conf` (the host
  session and the `f` binding).
- `bootstrap_server.sh` - makes the host session when tmux starts.
- `scripts/` - what the config calls: `session_switch.sh` (+
  `fzf_common.sh` for shared fzf styling), `git_status.sh` (status bar),
  `cursor_shape.sh`, `post_restore.sh`. master's picker scripts aren't on
  this branch.
- Plugins (tpm, tmux-resurrect, tmux-continuum) are installed by tpm into
  `~/.tmux/plugins/`, not part of this repo.

## CI

GitHub Actions runs shellcheck against `scripts/*.sh` and
`bootstrap_server.sh`. Security scanning is handled separately by the Snyk
GitHub App.
