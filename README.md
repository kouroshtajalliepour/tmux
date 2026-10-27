# tmux

A git-worktree-aware project switcher built on top of tmux - not a plugin,
a set of scripts and config that turn tmux into a session manager for how I
actually work: lots of repos, lots of branches, each one wanting its own
editor/terminal/AI windows, reachable in one or two keystrokes without ever
typing a `cd`.

Themed throughout in Catppuccin Mocha, color-coded by category so you always
know what kind of session you're in from the status bar alone.

## The model

Sessions fall into two kinds:

- **Dynamic project sessions** (Packages, live-websites) - picked from a
  directory tree via `scripts/tmux-sessionizer`, one row per project. A
  project that has grown multiple branches is a *worktree container*: each
  branch lives in its own subdirectory as a real `git worktree`, not a
  single checkout you keep switching inside. Picking a project reopens
  whichever branch you last worked on there; picking a *specific* branch is
  a separate command (`prefix+g`), not the main list's job.
- **Fixed sessions** (Sys, Media, Todos, Infra) - four hand-maintained
  sessions you jump straight to, kept alive across restarts by
  tmux-resurrect/continuum.

Every project session gets the same window layout: `0:repo` (anchored at
the project root), `7:vi`, `8:tr`, `9:ai` - built by
`scripts/project_lib.sh`'s `build_project_session`. Windows 1-6 are left
free for whatever you add yourself.

## Keybindings

| Key | Destination |
|---|---|
| `prefix+h` / `prefix+H` | Todos / Infra (fixed) |
| `prefix+j` / `prefix+J` | Sys / Media (fixed) |
| `prefix+k` | Packages - last-visited session, or the picker if none yet |
| `prefix+K` | Packages picker, always |
| `prefix+l` | live-websites - last-visited session, or the picker if none yet |
| `prefix+L` | live-websites picker, always |
| `prefix+g` | Switch to an already-cloned sibling branch of the current project |
| `prefix+m` | Full-screen D-pad hub - the above, as one screen |
| `prefix+s` | Fuzzy session switcher |
| `prefix+v` | tmux's own built-in session tree |

## Structure

- `conf/` - the actual tmux config, split by concern (`project.conf`,
  `theme.conf`, `general.conf`, `bindings.conf`).
- `scripts/` - everything project.conf shells out to. `project_lib.sh` holds
  the shared worktree/session logic; `tmux-sessionizer`, `category_hub.sh`,
  `sibling_branches.sh`, `jump_last.sh`, `session_switch.sh` are the
  individual pickers; `fzf_common.sh` centralizes the fzf styling and
  vim-motion nav mode shared by all of them.
- `plugins/` - vendored (tpm, tmux-resurrect, tmux-continuum) - not mine,
  not covered by this repo's CI.

## A couple of the harder bugs along the way

- fzf's `--nth` indexes the line *after* `--with-nth` has already
  transformed it, not the original row - silently broke every picker's
  filtering until the hidden search field was dropped in favor of
  filtering the displayed text directly.
- tmux doesn't recursively re-expand a stored `@option`'s own `#{...}`
  content - session/window colors never actually rendered until read back
  with the `#{E:@option}` twice-expand modifier instead of the bare form.

## CI

GitHub Actions runs shellcheck against `scripts/*.sh` and
`bootstrap_sys.sh` on every push (vendored `plugins/` code is excluded).
Security scanning is handled separately by the Snyk GitHub App.
