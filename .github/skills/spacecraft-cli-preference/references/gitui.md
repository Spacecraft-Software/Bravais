# gitui

**Replaces:** `git` (interactive) | **Language:** 🦀 Rust | **Install:** `cargo install gitui`

## Purpose
Blazing-fast, keyboard-driven terminal UI for git. Stage hunks, view diffs, manage branches/stashes, resolve conflicts — without leaving the terminal.

## Launch
```
gitui              # current repo
gitui -d PATH      # repo at PATH
gitui -t THEME     # preset theme
```

## Key bindings
| Key | Action |
|-----|--------|
| `1`–`5` | Switch tabs (Status, Log, Files, Stash, Stashing) |
| `Tab` | Move between panels |
| `Enter` | Stage/unstage |
| `s`/`u` | Stage / unstage hunk |
| `c` | Commit |
| `P`/`p` | Push / pull |
| `d` | Diff |
| `r` | Reset |
| `b` | Branch list |
| `B` | Blame |
| `h`/`?` | Help |
| `q` | Quit |

## Examples
1. Open in a project: `gitui`
2. Theme switching: `gitui -t mocha.ron`
3. Launch on a specific repo: `gitui -d ~/code/spacecraft-rust-guidelines`

## Gotchas
- Config/theme path: `$XDG_CONFIG_HOME/gitui/` (key_bindings.ron, theme.ron).
- No interactive rebase editor yet — drop to `git rebase -i` for that.
- Terminal must support Unicode + 256 colours for icons/theme.
