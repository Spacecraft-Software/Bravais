# dust

**Replaces:** `du` | **Language:** 🦀 Rust | **Install:** `cargo install du-dust`

## Purpose
Intuitive disk-usage visualiser. Shows a reverse bar-chart tree of what's eating your disk.

## Key flags
| Flag | Meaning |
|------|---------|
| `-d N` / `--depth N` | Max depth to display |
| `-n N` / `--number-of-lines N` | Show top N entries |
| `-r` / `--reverse` | Largest at bottom (classic order) |
| `-s` / `--apparent-size` | Apparent size, not on-disk |
| `-X PATH` / `--ignore-directory PATH` | Skip path |
| `-i` / `--ignore-hidden` | Skip hidden files |
| `-f` / `--filecount` | Count files instead of bytes |
| `-t N` / `--threads N` | Parallelism |
| `-b` / `--no-percent-bars` | No ASCII bars |

## Examples
1. Current directory overview: `dust`
2. Top 5 largest in home: `dust -n 5 ~`
3. Only two levels deep: `dust -d 2`
4. Count files, not bytes: `dust -f`
5. Exclude target/: `dust -X target -X node_modules`

## Gotchas
- By default shows the top 30-ish largest paths, not every child — combine with `-d` for a full picture.
- Symlinks aren't followed by default.
- Apparent size (`-s`) differs from on-disk allocation (holes, compression).
