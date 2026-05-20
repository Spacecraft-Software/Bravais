# impala

**Replaces:** `iwctl` (interactive), `nmtui` for Wi-Fi | **Language:** 🦀 Rust | **Install:** `cargo install impala`

## Purpose
TUI front-end for `iwd`. Scan, connect, manage known networks without memorising `iwctl` subcommands.

## Launch
```
impala
```

## Key bindings
| Key | Action |
|-----|--------|
| `s` | Scan |
| `Enter` | Connect to highlighted SSID |
| `d` | Disconnect |
| `k` | Manage known networks |
| `t` | Toggle power |
| `?` | Help |
| `q` | Quit |

## Gotchas
- Requires `iwd` running (`systemctl enable --now iwd`).
- Coexists badly with NetworkManager on Wi-Fi — pick one.
