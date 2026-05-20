# kondo

**Replaces:** ad-hoc `rm -rf target/ node_modules/` | **Language:** 🦀 Rust | **Install:** `cargo install kondo`

## Purpose
Finds and deletes build/dependency artifacts from software projects (`target/`, `node_modules/`, `build/`, `dist/`, `.gradle/`, etc.) across many languages.

## Key flags
| Flag | Meaning |
|------|---------|
| `-a` / `--all` | Delete all without confirmation |
| `-d DAYS` / `--older DAYS` | Only include projects untouched for N days |
| `-o FMT` / `--output FMT` | `default`, `json` |
| `-f` / `--follow-symlinks` | Follow symlinks |
| `-q` / `--quiet` | Suppress output |
| `-i PATTERN` / `--ignored PATTERN` | Ignore paths by pattern |

## Examples
1. Interactive cleanup of home: `kondo ~`
2. Auto-clean everything older than 30 days: `kondo -a -d 30 ~/code`
3. Dry-run inventory as JSON: `kondo -o json ~`
4. Clean current directory only: `kondo .`

## Gotchas
- Deletion is **irrecoverable** — commit or push before running `-a`.
- Detects projects by marker files (`Cargo.toml`, `package.json`, etc.); mixed-layout repos may double-count.
