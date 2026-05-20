# disktui

**Replaces:** `cfdisk`, `fdisk` (interactive) | **Language:** 🦀 Rust | **Install:** `cargo install disktui`

## Purpose
Interactive partition manager TUI with MBR/GPT support.

## Launch
```
sudo disktui [DEVICE]
```

## Key bindings
| Key | Action |
|-----|--------|
| `↑`/`↓` | Select partition |
| `n` | New |
| `d` | Delete |
| `t` | Change type |
| `w` | Write changes |
| `q` | Quit |

## Gotchas
- Writes are destructive — review with `lsblk` + `gptman` before `w`.
- Doesn't format filesystems — follow with `mkfs.*`.
