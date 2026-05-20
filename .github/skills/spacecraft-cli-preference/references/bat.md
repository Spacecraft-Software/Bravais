# bat

**Replaces:** `cat` (for viewing) | **Language:** 🦀 Rust | **Install:** `cargo install bat` / distro repo

## Purpose
`cat` with syntax highlighting, line numbers, git diff gutter, and paging. For interactive viewing — **do not** pipe `bat` into other tools unless you pass `--plain`.

## Key flags
| Flag | Meaning |
|------|---------|
| `-p` / `--plain` | No decorations; pipe-safe |
| `-n` / `--number` | Only line numbers (no other decorations) |
| `-A` / `--show-all` | Show non-printable characters |
| `--paging=never` | Disable pager |
| `-l LANG` / `--language LANG` | Force syntax (e.g. `yaml`, `rust`) |
| `--theme THEME` | Pick colour theme (`bat --list-themes`) |
| `--diff` | Highlight only modified lines |
| `-r N:M` / `--line-range N:M` | Print only lines N to M |
| `--style STYLES` | Comma list: `numbers,changes,header,grid,snip,rule` or `plain`/`full` |

## Examples
1. View with line numbers: `bat src/main.rs`
2. Multiple files concatenated for display: `bat Cargo.toml src/lib.rs`
3. Pipe-safe (for scripts): `bat --plain file.txt | head`
4. Highlight a JSON blob from stdin: `curl -s api | bat -l json`
5. Show only lines 10–40: `bat -r 10:40 logfile`
6. Diff-style: `git diff | bat --language diff`

## Gotchas
- Default output includes escape codes — if the consumer isn't a terminal, always `--plain`.
- `bat` is sometimes installed as `batcat` on Debian/Ubuntu; alias or symlink: `ln -s "$(which batcat)" ~/.local/bin/bat`.
- Replace the pager with `less -R` to keep colours: `export BAT_PAGER='less -R'`.
