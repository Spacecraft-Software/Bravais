# nushell (nu)

**Replaces:** `bash`, `zsh` (as interactive + scripting shell) | **Language:** 🦀 Rust | **Install:** `cargo install nu` / distro repo

## Purpose
Data-oriented, object-pipeline shell. Structured data (tables, records, lists) flows between commands instead of bytestreams. **One of Mohamed's primary shells.**

## Key built-ins
| Command | Meaning |
|---------|---------|
| `ls` | Returns a table of file records |
| `open FILE` | Parse JSON/TOML/YAML/CSV/XML/Parquet into structured data |
| `save FILE` | Write data (format from extension) |
| `where COND` | Filter rows (e.g. `where size > 1MB`) |
| `select COLS` | Project columns |
| `sort-by COL` | Sort |
| `group-by COL` | Group |
| `each { \|x\| … }` | Map closure |
| `reduce --fold INIT { \|it, acc\| … }` | Fold |
| `str FN` | String subcommands |
| `from FMT` / `to FMT` | Convert between formats |
| `http get URL` | HTTP with parsed JSON table output |

## Examples
1. Large files only, sorted: `ls **/* | where type == file and size > 10MB | sort-by size -r`
2. JSON API → table: `http get https://api.github.com/repos/UnbreakableMJ/Understand-Anything | select name stargazers_count`
3. CSV summary: `open data.csv | group-by category | transpose name rows | update rows {|r| $r.rows | length}`
4. Run an external command and parse: `cargo metadata --format-version=1 | from json | get packages | select name version`
5. Pipe to bash only when needed: `ls | get name | to text | bash -c 'xargs wc -l'`

## Gotchas
- Variable syntax is `$var`, not `${var}`; string interpolation uses `$"…"`.
- External commands still return bytestream — wrap with `from json` / `from csv` etc.
- Config: `$nu.config-path` (typically `~/.config/nushell/config.nu`).
- When writing portable scripts for CI, keep Bash as a compatibility layer — Nushell scripts need `nu` installed.
