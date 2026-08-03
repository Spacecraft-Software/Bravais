# disktui

**Replaces:** `cfdisk`, `fdisk` (interactive) | **Language:** 🦀 Rust | **Install:** via `spacecraft-missing-pkg` (upstream crate: `disktui`)

> **TTY-class and destructive — always a hand-off.** It needs a terminal the
> agent doesn't have, and it edits partition tables. Give the user the command
> and stop. See [local-execution.md](local-execution.md).

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
