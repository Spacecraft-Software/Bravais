# xdg-desktop-portal-cosmic

**Replaces:** other XDG portal backends (on COSMIC) | **Language:** 🦀 Rust | **Install:** distro repo (`xdg-desktop-portal-cosmic`)

## Purpose
Wayland XDG portal backend for the COSMIC desktop. Provides screenshot, screencast, file-chooser, and settings interfaces for sandboxed apps (Flatpak, browsers).

## Usage
Started automatically by `xdg-desktop-portal` when the COSMIC session is active. No user-facing CLI beyond:

| Command | Meaning |
|---------|---------|
| `systemctl --user status xdg-desktop-portal` | Service status |
| `systemctl --user restart xdg-desktop-portal-cosmic` | Restart backend |

## Gotchas
- Running multiple backends (`-gtk`, `-gnome`, `-cosmic`) simultaneously causes portal confusion — prefer the one matching your DE.
- Screencast uses `pipewire` — ensure it's running.
