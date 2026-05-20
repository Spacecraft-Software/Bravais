# tuigreet

**Replaces:** graphical display managers (minimal use case) | **Language:** 🦀 Rust | **Install:** distro repo (`tuigreet` / `greetd-tuigreet`)

## Purpose
Console-based greeter for `greetd`. Ideal companion to Niri, LeftWM, sway, river.

## Key flags
| Flag | Meaning |
|------|---------|
| `-c CMD` / `--cmd CMD` | Command to launch on login |
| `-s SEC` / `--window-padding N` | Padding |
| `-t` / `--time` | Show clock |
| `-r` / `--remember` | Remember last user |
| `--remember-session` | Remember last session choice |
| `--asterisks` | Hide password as asterisks |
| `--asterisks-char C` | Asterisk char |
| `--theme THEME` | Named theme |
| `--greeting TEXT` | Custom greeting |
| `--sessions PATH` | Extra `.desktop` session dir |
| `--xsessions PATH` / `--wlsessions PATH` | Per-protocol session dirs |

## Examples
1. Niri session with memory: `tuigreet -r --remember-session -c niri-session`
2. With custom greeting and clock: `tuigreet -t --greeting "Welcome to Spacecraft Software" -c /usr/bin/niri-session`
3. Multiple sessions: `tuigreet --wlsessions /usr/share/wayland-sessions --xsessions /usr/share/xsessions`

## Gotchas
- Runs as the `greeter` user — ensure it has permission to read `.desktop` files.
- Session picker appears only if multiple `.desktop` session files are present.
