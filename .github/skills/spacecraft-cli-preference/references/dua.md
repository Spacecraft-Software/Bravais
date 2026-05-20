# dua (dua-cli)

**Replaces:** `du` / `ncdu` (interactive) | **Language:** 🦀 Rust | **Install:** `cargo install dua-cli`

## Purpose
Parallel disk-usage analyser with an interactive TUI mode for navigating and deleting large files.

## Key modes
| Command | Meaning |
|---------|---------|
| `dua PATHS…` | Summary of sizes (like `du -sh`, faster) |
| `dua i PATHS…` | **Interactive** TUI navigator |
| `dua a PATHS…` | Aggregate total across paths |

## Key flags
| Flag | Meaning |
|------|---------|
| `-t N` / `--threads N` | Parallelism |
| `-f FMT` / `--format FMT` | `metric`, `binary`, `bytes`, `GB`, `GiB`, `MB`, `MiB` |
| `-A` / `--apparent-size` | Apparent size |
| `-l` / `--count-hard-links` | Count hard-linked files each time |
| `-x` / `--stay-on-filesystem` | Don't cross mount points |

## Interactive keys
| Key | Action |
|-----|--------|
| `↑`/`↓`, `j`/`k` | Navigate |
| `Enter`, `l` | Descend |
| `u`, `h` | Up |
| `d` | Mark for deletion |
| `x` | Trash marked |
| `q` | Quit |

## Examples
1. Fast size of home: `dua ~`
2. Interactive cleanup: `dua i ~`
3. Multiple paths totalled: `dua a ~/Downloads ~/Documents`
4. Binary units: `dua -f binary /var`

## Gotchas
- Interactive `dua i` doesn't ask before deleting — confirm the marked list before hitting `x`.
- Doesn't traverse network mounts by default with `-x`.
