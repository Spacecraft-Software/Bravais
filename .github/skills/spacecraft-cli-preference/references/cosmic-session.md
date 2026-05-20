# cosmic-session

**Replaces:** `gnome-session`, `plasma-session` | **Language:** 🦀 Rust | **Install:** distro repo

## Purpose
Session manager for COSMIC DE. Launched by your display manager when COSMIC is selected.

## Usage
Typically invoked as `cosmic-session` from a `.desktop` session file:
```
/usr/share/wayland-sessions/cosmic.desktop
```

## Commands
| Command | Meaning |
|---------|---------|
| `cosmic-session` | Start session (usually called by DM) |
| `systemctl --user status cosmic-session.target` | Session status |

## Gotchas
- Not meant to be invoked manually from a running session — restart via DM.
- Logs in `journalctl --user -u cosmic-session.target`.
