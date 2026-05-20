# delta

**Replaces:** `diff` pager for git | **Language:** 🦀 Rust | **Install:** `cargo install git-delta`

## Purpose
Syntax-highlighted diffs for `git`, `diff`, `grep`. Side-by-side or unified view. Integrates via `.gitconfig`.

## Setup (once per user)
```ini
# ~/.gitconfig
[core]
    pager = delta
[interactive]
    diffFilter = delta --color-only
[delta]
    navigate = true
    side-by-side = true
    line-numbers = true
    syntax-theme = Dracula
[merge]
    conflictStyle = diff3
```

## Key flags
| Flag | Meaning |
|------|---------|
| `--side-by-side` | Two-column view |
| `--line-numbers` | Gutter line numbers |
| `--navigate` | `n`/`N` between files in pager |
| `--syntax-theme THEME` | e.g. `Dracula`, `GitHub`, `OneHalfDark` |
| `--plus-style`, `--minus-style` | Colour overrides |
| `--features PROFILE` | Named config profile from `.gitconfig` |
| `--light` / `--dark` | Light/dark background hints |

## Examples
1. Pipe a diff: `git diff | delta`
2. Pretty grep (rg): `rg -p "unwrap" | delta`
3. Show a commit: `git show HEAD` (uses delta as pager once configured)
4. Compare two files: `delta a.txt b.txt`

## Gotchas
- Must be set as the git pager to show in `git log -p`, `git show`, etc.
- `merge.conflictStyle = diff3` (or `zdiff3`) makes conflict markers far clearer.
- `BAT_THEME`/`DELTA_FEATURES` env vars can override config.
