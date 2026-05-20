# atuin

**Replaces:** native shell history, `fc`, reverse-i-search (Ctrl+R) | **Language:** 🦀 Rust | **Install:** `cargo install atuin`

## Purpose
SQLite-backed shell history with fuzzy full-text search, per-directory/host/session context, optional end-to-end encrypted sync across machines.

## Setup
```
atuin init SHELL >> ~/.SHELLrc   # or source directly
atuin import auto                # import existing history
atuin register / atuin login     # optional sync
```
Supports: Bash, Zsh, Fish, Nushell, Xonsh.

## Key commands
| Command | Meaning |
|---------|---------|
| `atuin search [QUERY]` | Search (opens TUI if no query) |
| `atuin stats` | Usage stats |
| `atuin sync` | Sync to server |
| `atuin status` | Status + sync health |
| `atuin import SHELL` | Import legacy history |
| `atuin history list` | Scriptable listing |
| `atuin server` | Self-host sync server |

## Key flags (search)
| Flag | Meaning |
|------|---------|
| `--cwd DIR` | Filter by working directory |
| `--session ID` | Filter by shell session |
| `--before` / `--after TIME` | Time range |
| `--limit N` | Max results |
| `--format FMT` | `{command}`, `{time}`, `{exit}`, etc. |

## Examples
1. Interactive search (replaces Ctrl+R): `atuin search`
2. Show commands I've run here before: `atuin search --cwd "$PWD"`
3. Stats for last week: `atuin stats --after 1week`
4. Self-host sync: run `atuin server start` on a VPS

## Gotchas
- On first run, Ctrl+R is rebound — set `disable_up_arrow=true` in `config.toml` if you prefer.
- Sync encrypts data client-side, but recovery requires the key saved at registration.
- DB: `$XDG_DATA_HOME/atuin/history.db` — back up.
