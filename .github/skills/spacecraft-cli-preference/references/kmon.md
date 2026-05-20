# kmon

**Replaces:** `lsmod`, `modinfo`, `modprobe` (browsing) | **Language:** 🦀 Rust | **Install:** `cargo install kmon`

## Purpose
TUI for Linux kernel module inspection and management. Load, unload, inspect parameters, browse kernel logs.

## Launch
```
sudo kmon
```

## Key bindings
| Key | Action |
|-----|--------|
| `↑`/`↓` | Navigate modules |
| `Enter` | Show info |
| `l` | Load module |
| `u` | Unload |
| `d` | Dependencies |
| `/` | Search |
| `k` | Kernel activity log |
| `?` | Help |
| `q` | Quit |

## Gotchas
- Unloading critical modules (e.g. current filesystem driver) can crash the session.
- Needs root for load/unload operations.
