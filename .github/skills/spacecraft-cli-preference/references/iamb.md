# iamb

**Replaces:** Matrix clients (TUI, Vim-like) | **Language:** 🦀 Rust | **Install:** `cargo install iamb`

## Purpose
Vim-like terminal Matrix client with multi-room support, modal editing, E2EE.

## Launch
```
iamb
```

## Key bindings (modal, Vim-style)
| Key | Action |
|-----|--------|
| `i` / `Esc` | Insert / normal mode |
| `:` | Command mode |
| `:join ROOM` | Join |
| `:verify` | Device verification |
| `:leave` | Leave room |
| `Ctrl+W h/j/k/l` | Navigate splits |
| `Ctrl+O` / `Ctrl+I` | History back / forward |
| `/` | Search |

## Examples
1. First-time config: edit `$XDG_CONFIG_HOME/iamb/config.toml` with your server/user
2. Join a room: `:join #rust:matrix.org`
3. Direct message: `:dms` to open DM list

## Gotchas
- First sync on a busy account takes a while.
- E2EE device verification required for encrypted rooms.
