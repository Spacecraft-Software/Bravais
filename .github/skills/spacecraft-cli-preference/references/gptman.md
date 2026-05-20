# gptman

**Replaces:** `gdisk`, `sgdisk` | **Language:** 🦀 Rust | **Install:** `cargo install gptman`

## Purpose
Scriptable GPT partition table manipulation. Create, modify, clone partitions non-interactively.

## Key commands
| Command | Meaning |
|---------|---------|
| `gptman -l DEVICE` | List GPT partitions |
| `gptman DEVICE` | Interactive edit mode |
| `gptman -i DEVICE` | Print GPT info |
| `gptman -d DEVICE` | Write defaults (blank GPT) |

## Interactive commands
| Key | Action |
|-----|--------|
| `p` | Print table |
| `n` | New partition |
| `d` | Delete |
| `t` | Type GUID |
| `w` | Write |
| `q` | Quit without saving |

## Examples
1. List partitions: `gptman -l /dev/nvme0n1`
2. Edit: `sudo gptman /dev/nvme0n1`
3. JSON scripting target: pair with a shell wrapper for CI disk provisioning

## Gotchas
- Always unmount before editing.
- Partition numbers are 1-indexed.
