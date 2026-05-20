# fclones

**Replaces:** `fdupes`, `rmlint` | **Language:** 🦀 Rust | **Install:** `cargo install fclones`

## Purpose
Parallel duplicate-file finder; can also deduplicate in place via hard/symlinks or reflinks.

## Key commands
| Command | Meaning |
|---------|---------|
| `fclones group PATHS…` | Find duplicates (default) |
| `fclones remove` | Delete files from a prior group output |
| `fclones link [--soft]` | Replace duplicates with hardlinks (or symlinks) |
| `fclones dedupe` | Btrfs/XFS reflink-based dedup |

## Key flags
| Flag | Meaning |
|------|---------|
| `-R` / `--recursive` | Recurse into directories (on by default for positional dirs) |
| `-s SIZE` / `--min-size SIZE` | Skip files below this size (e.g. `1M`) |
| `-H` / `--match-links` | Treat hardlinks as duplicates |
| `--hash-fn ALGO` | `metro`, `xxhash3`, `blake3`, `sha256` |
| `-o FILE` / `--output FILE` | Write group list |
| `-f FMT` / `--format FMT` | `default`, `csv`, `json`, `fdupes` |

## Examples
1. Find duplicates under home: `fclones group ~`
2. Save groups, then review and delete: `fclones group ~/Pictures -o dupes.txt && fclones remove < dupes.txt`
3. Hardlink duplicates in a dataset: `fclones group data/ | fclones link`
4. Only files ≥1 MB: `fclones group -s 1M ~/Downloads`
5. JSON output: `fclones group -f json /srv > dupes.json`

## Gotchas
- `remove`/`link`/`dedupe` read previous `group` output from stdin — always review first.
- Reflink dedup (`dedupe`) requires btrfs/xfs with reflink support.
- Hash choice affects speed vs. collision safety; `blake3` is a good balance.
