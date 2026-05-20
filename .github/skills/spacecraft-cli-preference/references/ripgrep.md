# ripgrep (rg)

**Replaces:** `grep -r` | **Language:** 🦀 Rust | **Install:** `cargo install ripgrep` / distro repo

## Purpose
Fastest recursive search tool. Respects `.gitignore`, understands Unicode, parallel by default.

## Key flags
| Flag | Meaning |
|------|---------|
| `-i` / `--ignore-case` | Case-insensitive |
| `-S` / `--smart-case` | Case-insensitive unless pattern has uppercase |
| `-F` / `--fixed-strings` | Literal (non-regex) match |
| `-w` / `--word-regexp` | Match whole words |
| `-l` / `--files-with-matches` | Only list filenames |
| `-c` / `--count` | Count matches per file |
| `-n` / `--line-number` | Show line numbers (default on TTY) |
| `-A N`, `-B N`, `-C N` | Context lines after / before / both |
| `-t TYPE` / `--type TYPE` | Filter by type (e.g. `rust`, `py`, `md`); see `rg --type-list` |
| `-T TYPE` / `--type-not TYPE` | Exclude type |
| `-g GLOB` / `--glob GLOB` | Include/exclude glob (prefix with `!` to negate) |
| `--hidden` | Include hidden files |
| `-u` | Loosen filtering (`-u` gitignore, `-uu` hidden, `-uuu` binary) |
| `-z` / `--search-zip` | Search inside compressed files |
| `-r REPL` / `--replace REPL` | Display with replacement (non-destructive) |
| `--json` | Machine-readable output |

## Examples
1. Recursive search in the tree: `rg "TODO"`
2. Case-insensitive, whole word: `rg -iw "fixme"`
3. Only Rust files, with 2 lines of context: `rg -t rust -C 2 "unsafe"`
4. List files mentioning a symbol: `rg -l "tokio::spawn"`
5. Exclude tests: `rg "unwrap" -g '!tests/*'`
6. Search compressed logs: `rg -z "panic" /var/log/*.gz`
7. JSON output (for scripting): `rg --json "error" | jaq '. | select(.type=="match")'`

## Gotchas
- `.gitignore` + hidden-file filtering is on by default — use `-uu` to match everything.
- Patterns are Rust regex (similar to PCRE, but no backreferences). Use `-F` if your pattern has regex metacharacters.
- Binary files skipped by default; `-a` to force text treatment.
