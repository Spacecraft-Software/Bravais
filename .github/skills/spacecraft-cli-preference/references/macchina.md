# macchina

**Replaces:** `neofetch`, `fastfetch` | **Language:** 🦀 Rust | **Install:** `cargo install macchina`

## Purpose
Fast system-info fetcher. Customisable readouts, themes, ASCII art.

## Key flags
| Flag | Meaning |
|------|---------|
| `-t THEME` / `--theme THEME` | Named theme |
| `-o ITEM` / `--show ITEM` | Only show this item (repeatable) |
| `-H ITEM` / `--hide ITEM` | Hide item |
| `--list-themes` | Available themes |
| `-c FILE` / `--config FILE` | Config file |
| `-p` / `--predefined` | Use predefined logo |
| `-v` | Verbose |

## Examples
1. Default: `macchina`
2. Minimal (OS + kernel only): `macchina -o os -o kernel`
3. Custom theme: `macchina -t Helium`
4. Scriptable (no ASCII): `macchina -H logo`

## Gotchas
- Themes live in `$XDG_CONFIG_HOME/macchina/themes/`.
- Some readouts need permissions (e.g. battery on locked-down containers).
