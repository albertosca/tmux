# tmux config

- 🇺🇸 [English](README.md)
- 🇧🇷 [Português](README.pt.md)

[![CI](https://github.com/albertosca/tmux/actions/workflows/ci.yml/badge.svg)](https://github.com/albertosca/tmux/actions/workflows/ci.yml)
[![ShellCheck](https://github.com/albertosca/tmux/actions/workflows/lint.yml/badge.svg)](https://github.com/albertosca/tmux/actions/workflows/lint.yml)

My personal tmux config, on the XDG path (`~/.config/tmux/`). tmux 3.1+ picks `tmux.conf` up from here automatically — no `~/.tmux.conf` and no symlink needed.

Plugins are managed by [TPM](https://github.com/tmux-plugins/tpm), which bootstraps itself on first load. The config ships with a test suite covering the conf statically, structurally and at runtime.

---

## Requirements

- **tmux ≥ 3.2** (floating popups)
- **macOS** — the clipboard bindings use the native `pbcopy`. On Linux, swap it for `xclip` / `xsel` in the copy-mode bindings and in `@extrakto_clip_tool`.
- **Homebrew dependencies:**
  ```bash
  brew install fzf          # required: extrakto + sessionx
  brew install lazygit      # popup on prefix+G
  brew install bat fd       # nicer sessionx preview (optional)
  brew install zoxide       # sessionx suggests recent dirs (optional)
  ```

---

## Install

```bash
# 1. Clone into ~/.config/tmux
git clone https://github.com/albertosca/tmux.git ~/.config/tmux

# 2. Start tmux — TPM installs itself and fetches the plugins
tmux
```

On the first launch `tmux.conf` notices TPM is missing and clones plus installs everything. To force it by hand: `prefix + I`.

> **Note:** `plugins/` is gitignored — every machine installs its own through TPM.

---

## Layout

```
~/.config/tmux/
├── tmux.conf           # main config
├── CHEATSHEET.md       # shortcuts, popups, day-to-day flows
├── scripts/
│   ├── session-theme.sh  # per-session status bar colors (work/personal)
│   └── sync-public.sh    # publishes this config to the public mirror
├── test/
│   ├── run.sh          # test entry point
│   ├── shell.sh        # static checks against the conf
│   ├── integration.sh  # runtime tests on an isolated socket
│   ├── structure.sh    # line order, duplicates, plugin health
│   ├── meta.sh         # harness self-tests
│   └── lib.sh          # assertion helpers
└── plugins/            # managed by TPM (not versioned)
    └── tpm/
```

---

## `tmux.conf` sections

| Section          | Highlights                                                                        |
|------------------|-----------------------------------------------------------------------------------|
| KEY BINDINGS     | prefix `C-a`, splits `\|`/`-`, vim nav `hjkl`, resize `HJKL`, popups, `r` = reload |
| DESIGN CHANGES   | pane colors, status bar with sessions + git branch + date/time, true color        |
| PLUGINS          | TPM auto-install, 9 plugins, the TPM `run` on the last line                       |
| Post-TPM         | overrides that must beat tmux-sensible defaults (e.g. `status-keys vi`)           |

Load order matters: `tmux-sensible` sets `status-keys emacs` unconditionally when it loads, so anything that has to win against it lives **after** the TPM `run` line.

---

## Plugins

| Plugin | What it does | Binding |
|--------|--------------|---------|
| [tpm](https://github.com/tmux-plugins/tpm) | plugin manager | `prefix+I` install, `prefix+U` update |
| [tmux-sensible](https://github.com/tmux-plugins/tmux-sensible) | sane defaults | — |
| [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) | save/restore sessions | `prefix+C-s` / `prefix+C-r` |
| [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum) | auto-save every 15min + restore on boot | — |
| [tmux-yank](https://github.com/tmux-plugins/tmux-yank) | copy to system clipboard | `y` in copy-mode |
| [tmux-open](https://github.com/tmux-plugins/tmux-open) | open the selection | `o` / `C-o` in copy-mode |
| [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator) | seamless Vim ↔ tmux nav | `C-h/j/k/l` without prefix |
| [extrakto](https://github.com/laktak/extrakto) | fuzzy-grab paths/urls/hashes | `prefix+Tab` |
| [tmux-sessionx](https://github.com/omerxx/tmux-sessionx) | fuzzy session/window switcher | `prefix+O` |

---

## Per-session themes

The status bar and the pane borders change color based on the session name:

| Name prefix | Color  |
|-------------|--------|
| `work`      | Cyan   |
| `personal`  | Orange |
| anything else | Default (black) |

`scripts/session-theme.sh` is driven by the `session-created`, `session-renamed` and `client-session-changed` hooks.

---

## Tests

```bash
bash test/run.sh              # all four suites, compact output
bash test/run.sh -v           # case by case
bash test/run.sh shell        # static greps + regression guards
bash test/run.sh structure    # line order, duplicates, encoding, plugin health
bash test/run.sh integration  # runtime on an isolated socket
bash test/run.sh meta         # harness self-tests
```

The integration suite starts its own tmux server on a PID-namespaced socket (`claude-test-$$`), so it never touches running sessions. Run it before committing — it encodes every bug already fixed here as a permanent regression test.

---

## Portability notes

Two bindings reach outside this repo and are guarded so a fresh clone still works:

- `default-command` pins the native arm64 `reattach-to-user-namespace` by absolute path (a PATH-resolved Intel build silently forces every pane under Rosetta). The pin sits behind an `if-shell` existence check — unguarded, an absolute path that is missing kills every pane with exit 127.
- `prefix + m` calls a personal Claude Code hook that only exists on my machine, behind a `test -f` guard, so it is a no-op anywhere else.

---

## Vim side (vim-tmux-navigator)

For `C-h/j/k/l` to navigate inside Vim too, install the matching Vim plugin — see the **Vim ↔ tmux** section in [`CHEATSHEET.md`](CHEATSHEET.md).

---

## Related projects

- **[albertosca/vim](https://github.com/albertosca/vim)** — my Vim config (pairs with this setup: tmux↔Vim navigation, plugins, theme)
- **[albertosca/vim-tutorial](https://github.com/albertosca/vim-tutorial)** — the Vim tutorial I use as a reference
