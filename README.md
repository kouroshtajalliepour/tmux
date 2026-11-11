# tmux

A git-worktree-aware project switcher built on top of tmux - not a plugin,
a set of scripts and config that turn tmux into a session manager for how I
actually work: lots of repos, lots of branches, each one wanting its own
editor/terminal/AI windows, reachable in one or two keystrokes without ever
typing a `cd`.

Themed throughout in Catppuccin Mocha, color-coded by category so you always
know what kind of session you're in from the status bar alone.

> **`production` branch**: a stripped-down variant for machines that don't
> need the project-switcher - just `prefix+s` (session switcher), no
> category pickers, no auto-created sessions, status bar on the bottom,
> prefix is `Ctrl+s` instead of `Ctrl+b`.

## The model

Sessions fall into two kinds:

- **Dynamic project sessions** - one category per folder under
  `~/Documents/repos/`: `packages/` (Packages, `j-*`, mauve), `live/`
  (Live, `l-*`/`lr-*`, green), `infra/` (Infra, `i-*`, teal) and
  `training/` (Training, `t-*`, yellow - one folder per person mentored,
  `training/<Person>/<repo>`, picked person first). Picked from that
  directory via `scripts/tmux-sessionizer`, one row per project. A
  project that has grown multiple branches is a *worktree container*: each
  branch lives in its own subdirectory as a real `git worktree`, not a
  single checkout you keep switching inside. Picking a project reopens
  whichever branch you last worked on there; picking a *specific* branch is
  a separate command (the hub's h/j/k/l), not the main list's job.
  These are **not** saved across restarts - they're rebuilt on demand, so
  boot only pays for the four fixed sessions.
- **Fixed sessions** (Sys, Media, Todos, Infra) - four sessions you jump
  straight to. `bootstrap_sys.sh` creates any that are missing, and
  tmux-resurrect/continuum keep their contents across restarts (a
  post-save hook, `scripts/resurrect_filter.sh`, strips everything else
  from each save).

Any session can be **pinned** (`prefix+a`); `prefix+f` from a code session lists the pinned branches of its project, and `prefix+F` the pinned projects. Pins outlive their sessions -
opening one that isn't running rebuilds it. Anything opened through the
repo pickers is pinned automatically, and a pin whose
project directory is gone (and whose session isn't running) is dropped
the next time that list opens. `prefix+j`/`prefix+k` cycle a project's pinned branches and `prefix+h`/`prefix+l` move between projects,
starting any that aren't running (handy right after a boot). `prefix+X` self-destructs the current session and drops you back
on Sys.

The status bar's left pill shows a project session by its repo name
(`tmux`, not `j-tmux-master`).

The i3 **alt+\` drop-down** (`~/.config/i3/scripts/toggle_scratch.sh` ->
`scripts/dropdown.sh`) remembers the session you last chose in it: the
first time it opens the `prefix+m` hub, and wherever you go from there
becomes its session. Press `prefix+m` inside it to choose again. It's
the real session, not a copy, so it mirrors the main terminal.

A window gets a trailing `*` in the status bar (and its session a `*` in
the pickers) when something in it was busy - output moving for a few
seconds - and then went still while you weren't looking at it.
`scripts/activity_monitor.sh` polls for this in the background; focusing
the window clears it.

Every project session gets the same window layout: `0:repo` (anchored at
the project root), `7:vi`, `8:tr`, `9:ai` - built by
`scripts/project_lib.sh`'s `build_project_session`. Windows 1-6 are left
free for whatever you add yourself.

## Keybindings

| Key | Destination |
|---|---|
| `prefix+h` / `prefix+l` | Previous / next pinned project, landing on the branch used last. Every project's active branches are pinned in `~/.local/state/tmux/pinned-branches.tsv` |
| `:vue 4000` / `:vue auto` / `:unproject` | Set this session's bios: a Vue project on that port, on the next free port, or none (`~/.local/state/tmux/session-bios.tsv`) |
| `:link /admin/users` | The page alt opens for this session. Takes its tab there once; after that alt never reloads it |
| `prefix+j` / `prefix+k` | Next / previous session: the main 4 when you're in one of them, otherwise your pins (main 4 skipped), starting any that aren't running |
| `prefix+K` / `prefix+L` | Packages / Live project picker |
| `prefix+J` | Infra project picker |
| `prefix+H` | Training: pick the person, then their repo |
| `prefix+f` | Find: in the main 4, a window of the main 4; anywhere else, the pinned sessions (`ctrl-x` unpins) |
| `prefix+F` | The other find: in the main 4, the pinned sessions; anywhere else, a window of the main 4 |
| `prefix+p` | Back and forth between the last main session and the last code session |
| `prefix+n` | tmux's own find-window |
| `prefix+a` | Pin/unpin the current session |
| `prefix+N` / `prefix+P` | Next / previous branch of the current project |
| `prefix+X` | Kill the current session, back to Sys |
| `prefix+m` | Full-screen D-pad hub - k/K Packages, l/L Live, j/J Infra, h/H Training (plain letter: the last project's branches; Shift: the project picker), 1-4 the main sessions. Sizes itself to the screen (fits the alt+\` drop-down) |
| `prefix+v` | tmux's own built-in session tree |

## Structure

- `conf/` - the actual tmux config, split by concern (`project.conf`,
  `theme.conf`, `general.conf`, `bindings.conf`).
- `scripts/` - everything project.conf shells out to. `project_lib.sh` holds
  the shared worktree/session logic; `tmux-sessionizer`, `category_hub.sh`,
  `branch_picker.sh`, `jump_last.sh`, `session_switch.sh`, `pins.sh`,
  `training_picker.sh` (person first) are
  the individual pickers (`branch_cycle.sh` is prefix+N/P, `session_cycle.sh`
  prefix+j/k, `last_session.sh` prefix+p, `dropdown.sh` the alt+\` drop-down); `fzf_common.sh` centralizes the fzf styling and
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
