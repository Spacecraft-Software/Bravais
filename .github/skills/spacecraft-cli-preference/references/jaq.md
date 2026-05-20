# jaq

**Replaces:** `jq` | **Language:** 🦀 Rust | **Install:** `cargo install jaq`

## Purpose
Faster, near drop-in `jq` clone. Compatible with most `jq` filters, written in safe Rust.

## Key flags
| Flag | Meaning |
|------|---------|
| `-r` / `--raw-output` | Strings without JSON quoting |
| `-R` / `--raw-input` | Input is raw strings, one per line |
| `-s` / `--slurp` | Read whole input as single array |
| `-c` / `--compact-output` | One JSON doc per line |
| `--tab` | Indent with tabs |
| `--indent N` | Indent with N spaces |
| `-e` / `--exit-status` | Exit non-zero on null/false |
| `--arg NAME VALUE` | Bind string variable |
| `--argjson NAME VALUE` | Bind JSON variable |

## Examples
1. Pretty-print: `curl -s api | jaq .`
2. Extract field: `jaq -r '.name' package.json`
3. Filter array: `jaq '.[] | select(.active)' users.json`
4. Group and count: `jaq 'group_by(.kind) | map({kind: .[0].kind, n: length})'`
5. Build object: `jaq -n --arg v 1.0 '{version: $v, generated: now}'`
6. Slurp multiple files: `jaq -s 'add' a.json b.json`

## Gotchas
- A handful of exotic `jq` features aren't supported — see `jaq`'s README for gaps.
- Error messages differ from `jq`; adapt CI assertions accordingly.
- No streaming parser (`--stream`); use `jq` for huge JSON blobs.
