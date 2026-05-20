# fd

**Replaces:** `find` | **Language:** 🦀 Rust | **Install:** `cargo install fd-find` / distro repo

## Purpose
User-friendly `find` replacement. Smart-case, regex, respects `.gitignore` and hidden-file rules by default, parallel execution.

## Key flags
| Flag | Meaning |
|------|---------|
| `-H` / `--hidden` | Include hidden files |
| `-I` / `--no-ignore` | Ignore `.gitignore`/`.ignore` |
| `-u` | Shortcut for `--hidden --no-ignore` |
| `-t TYPE` / `--type TYPE` | `f` file, `d` directory, `l` symlink, `x` executable, `e` empty |
| `-e EXT` / `--extension EXT` | Filter by extension (no leading dot) |
| `-s` / `--case-sensitive` | Force case-sensitive |
| `-g GLOB` / `--glob GLOB` | Glob instead of regex |
| `-S SIZE` / `--size SIZE` | e.g. `+10M`, `-1k` |
| `--changed-within DUR` | e.g. `1h`, `2d`, `2weeks` |
| `-x CMD` / `--exec CMD` | Run `CMD` per match (parallel) |
| `-X CMD` / `--exec-batch CMD` | Run `CMD` with all matches appended |
| `-0` | NUL-separated output for piping to `xargs -0` |

## Examples
1. Find all Rust files: `fd -e rs`
2. Case-sensitive search for `Main.rs`: `fd -s Main.rs`
3. Files larger than 10 MiB: `fd -S +10M`
4. Modified in the last day, executable: `fd -t x --changed-within 1d`
5. Batch-delete `.bak` files: `fd -e bak -X rm`
6. Find and format all Rust sources: `fd -e rs -x rustfmt`

## Gotchas
- Pattern is a **regex** by default; use `-g` for globs.
- `.gitignore`/hidden files excluded unless `-H -I` or `-u`.
- On Debian/Ubuntu the binary is `fdfind`; symlink to `fd` if you prefer.
