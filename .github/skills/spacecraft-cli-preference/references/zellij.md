# zellij

**Replaces:** `tmux`, `screen` | **Language:** 🦀 Rust | **Install:** via `spacecraft-missing-pkg` (upstream crate: `zellij`)

## Purpose
User-friendly terminal multiplexer. Layouts, floating panes, plugins (WASM), session manager, discoverable keybindings always visible.

## Key commands
| Command | Meaning |
|---------|---------|
| `zellij` | New or attach default session |
| `zellij -s NAME` | New named session |
| `zellij attach NAME` | Attach |
| `zellij list-sessions` / `ls` | List |
| `zellij kill-session NAME` | Kill |
| `zellij action NAME [ARGS]` | Dispatch action to running session |
| `zellij setup --dump-config > ~/.config/zellij/config.kdl` | Dump config |
| `zellij --layout FILE` | Start with a layout |

## Key bindings

Zellij ships two keybinding presets, selectable in its in-app Configuration
screen (`Ctrl+o` then `c` on Default, `Ctrl+g` then `o` then `c` on Unlock
First). **Check which one is active before assuming a binding** — see Gotchas.

### Preset 1 — Default (Ctrl prefixes)
| Key | Action |
|-----|--------|
| `Ctrl+p` | Pane mode (`n` new, `d` down-split, `r` right-split, `x` close) |
| `Ctrl+t` | Tab mode (`n` new, `h/l` prev/next, `r` rename) |
| `Ctrl+s` | Scroll / search mode |
| `Ctrl+o` | Session mode (`d` detach, `w` session picker) |
| `Ctrl+g` | Lock (pass keys to underlying program) |
| `Ctrl+q` | Quit |

### Preset 2 — Unlock First (non-colliding)
Starts locked (`default_mode "locked"`), so every keystroke reaches the program
in the pane and nothing collides with a shell, editor, or TUI. `Ctrl+g` unlocks;
single keys then enter modes; `Ctrl+g` or `esc` locks again.

| Key | Action |
|-----|--------|
| `Ctrl+g` | Unlock (leave locked mode) — the prefix for everything below |
| `Ctrl+g` then `p` | Pane mode (`n` new, `d` down-split, `r` right-split, `x` close) |
| `Ctrl+g` then `t` | Tab mode (`n` new, `h/l` prev/next, `r` rename) |
| `Ctrl+g` then `r` | Resize mode |
| `Ctrl+g` then `s` | Scroll mode (`f` enters search) |
| `Ctrl+g` then `m` | Move mode |
| `Ctrl+g` then `o` | Session mode (`d` detach, `w` session picker, `c` configuration) |
| `Ctrl+g` then `Ctrl+q` | Quit |

## Examples
1. Start a workspace for this project: `zellij -s spacecraft-software`
2. Reattach later: `zellij attach spacecraft-software`
3. Predefined layout: `zellij --layout ~/layouts/dev.kdl`
4. Send a command from outside: `zellij action write-chars "cargo test\n"`

## Gotchas
- **Do not assume the Ctrl-prefix defaults.** Read `~/.config/zellij/config.kdl`
  first: `default_mode "locked"` plus `keybinds clear-defaults=true` means the
  Unlock First preset is active and every mode key needs `Ctrl+g` ahead of it.
- The Default preset's prefix is Ctrl-based (no single prefix key like tmux's
  C-b) — switch preset, or remap in `config.kdl`, if you prefer a tmux feel.
- `zellij setup --dump-config` always emits the **Default** preset, never the
  active one and never Unlock First — it is not a way to read current settings,
  and piping it over a live `config.kdl` silently discards them.
- A config written by a Nix/dotfile generator can be overwritten by zellij at
  runtime (the in-app Configuration screen persists on apply and moves the old
  file to `config.kdl.bak.N`), and overwritten right back on the next
  generator run. Change the generator's source, not the live file.
- Validate a config without loading it: `ZELLIJ_CONFIG_FILE=<path> zellij setup
  --check` (expect `[CONFIG FILE]: Well defined.`).
- Copy/paste across panes relies on OSC52 — enable in your terminal.
- Plugin system loads WASM modules from `$XDG_DATA_HOME/zellij/plugins/`.
