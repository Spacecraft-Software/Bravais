# tokei

**Replaces:** `cloc`, `wc -l` (for code) | **Language:** 🦀 Rust | **Install:** `cargo install tokei`

## Purpose
Fast code statistics: lines of code, comments, blanks, grouped by language. Respects `.gitignore`.

## Key flags
| Flag | Meaning |
|------|---------|
| `-t LANG[,LANG]` / `--type` | Only count these languages |
| `-e PATH` / `--exclude PATH` | Exclude path (gitignore-style) |
| `-s KEY` / `--sort KEY` | Sort by `lines`, `blanks`, `code`, `comments`, `files` |
| `-o FMT` / `--output FMT` | `json`, `yaml`, `toml`, `cbor` |
| `-f` / `--files` | Per-file breakdown |
| `--hidden` | Include hidden files |
| `-C` / `--compact` | Condensed output |

## Examples
1. Count this project: `tokei`
2. Only Rust and TOML: `tokei -t Rust,TOML`
3. Per-file breakdown sorted by code: `tokei -f -s code`
4. JSON for scripting: `tokei -o json | jaq '.Rust.code'`
5. Exclude vendor: `tokei -e vendor/ -e third_party/`

## Gotchas
- Counts by extension + heuristics; generated files inflate numbers — exclude them.
- Comment detection isn't perfect for obscure languages; spot-check with `-f`.
