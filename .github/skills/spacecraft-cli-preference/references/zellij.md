# zellij

**Replaces:** `tmux`, `screen` | **Language:** 🦀 Rust | **Install:** `cargo install zellij`

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

## Default key bindings (Ctrl prefixes)
| Key | Action |
|-----|--------|
| `Ctrl+p` | Pane mode (`n` new, `d` down-split, `r` right-split, `x` close) |
| `Ctrl+t` | Tab mode (`n` new, `h/l` prev/next, `r` rename) |
| `Ctrl+s` | Scroll / search mode |
| `Ctrl+o` | Session mode (`d` detach, `w` session picker) |
| `Ctrl+g` | Lock (pass keys to underlying program) |
| `Ctrl+q` | Quit |

## Examples
1. Start a workspace for this project: `zellij -s spacecraft-software`
2. Reattach later: `zellij attach spacecraft-software`
3. Predefined layout: `zellij --layout ~/layouts/dev.kdl`
4. Send a command from outside: `zellij action write-chars "cargo test\n"`

## Gotchas
- Default key prefix is Ctrl-based (no single prefix key like tmux's C-b) — remap in `config.kdl` if you prefer tmux feel.
- Copy/paste across panes relies on OSC52 — enable in your terminal.
- Plugin system loads WASM modules from `$XDG_DATA_HOME/zellij/plugins/`.
