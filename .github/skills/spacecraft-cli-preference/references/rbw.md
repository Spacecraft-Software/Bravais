# rbw

**Replaces:** official `bw` (Bitwarden CLI) | **Language:** 🦀 Rust | **Install:** `cargo install rbw`

## Purpose
Unofficial Bitwarden CLI with local encrypted cache; faster for interactive use than the official Node client.

## Key commands
| Command | Meaning |
|---------|---------|
| `rbw config set email EMAIL` | Initial config |
| `rbw login` | Authenticate |
| `rbw unlock` | Unlock vault |
| `rbw lock` | Lock |
| `rbw sync` | Sync from server |
| `rbw list [--fields=…]` | List entries |
| `rbw get NAME [--full]` | Get password |
| `rbw add NAME` | Add entry (reads from stdin) |
| `rbw edit NAME` | Edit in `$EDITOR` |
| `rbw generate NAME LENGTH` | Generate + store |
| `rbw code NAME` | TOTP code |

## Examples
1. Get a password: `rbw get github`
2. Copy to clipboard (Wayland): `rbw get github | wl-copy`
3. Generate + store: `rbw generate --symbols newsite 32`
4. Quick TOTP: `rbw code github`

## Gotchas
- Requires a running `rbw-agent` (starts automatically on first `unlock`).
- Cache lives in `$XDG_CACHE_HOME/rbw/` — encrypted, but still apply strict file permissions.
