# matrix-commander-rs

**Replaces:** scripted Matrix interactions | **Language:** 🦀 Rust | **Install:** `cargo install matrix-commander-rs`

## Purpose
Scripting-oriented Matrix CLI. Send/receive messages, manage rooms, verify devices — pipe-friendly.

## Key flags
| Flag | Meaning |
|------|---------|
| `--login` | Initial login (interactive) |
| `-m MSG` / `--message MSG` | Send text |
| `-i FILE` / `--image FILE` | Send image |
| `-f FILE` / `--file FILE` | Send file |
| `-r ROOM` / `--room ROOM` | Room alias/ID |
| `-l` / `--listen` | Listen for messages (once/tail/forever) |
| `--sync` | Sync server state |
| `--store DIR` | Credential store path |
| `--verify emoji` | SAS-emoji device verification |
| `--room-create` / `--room-invite` | Room ops |

## Examples
1. Login: `matrix-commander-rs --login`
2. Send a message: `matrix-commander-rs -r '!roomid:server' -m "deploy starting"`
3. Pipe a build log: `cargo test 2>&1 | matrix-commander-rs -r '#ci:server' -m -`
4. Listen for new messages: `matrix-commander-rs -l tail`

## Gotchas
- Device verification (`--verify emoji`) required for E2EE rooms before encrypted messages work.
- Store directory holds session keys — back up securely.
