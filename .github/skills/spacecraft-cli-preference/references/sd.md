# sd

**Replaces:** `sed` (for simple find/replace) | **Language:** 🦀 Rust | **Install:** `cargo install sd`

## Purpose
Intuitive find-and-replace. Regex by default, no `s/…/…/g` ceremony, in-place or streaming.

## Key flags
| Flag | Meaning |
|------|---------|
| `-p` / `--preview` | Dry-run: show what would change |
| `-s` / `--string-mode` | Literal match (no regex) |
| `-f FLAGS` / `--flags FLAGS` | Regex flags: `i` case-insensitive, `m` multiline, `s` dotall, `w` whole word |

## Examples
1. Replace in a file in place: `sd "foo" "bar" file.txt`
2. Across many files: `fd -e rs -x sd "old_name" "new_name"`
3. Stream from pipe: `echo "hello world" | sd "world" "rust"`
4. Preview before applying: `sd -p "unwrap" "expect" src/main.rs`
5. Case-insensitive: `sd -f i "error" "ERROR" log.txt`
6. Literal string (no regex escaping): `sd -s "a.b.c" "x.y.z" file.txt`

## Gotchas
- Writes in place by default — always preview first on untracked files.
- No address ranges or commands like `sed` — it's substitution-only. Complex scripts still need `sed` or `awk`.
- Backslash references use `$1`, `$2` (not `\1`).
