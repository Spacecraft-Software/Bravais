# eza

**Replaces:** `ls` | **Language:** 🦀 Rust | **Install:** `cargo install eza` / distro repo

## Purpose
Modern `ls` replacement with git status, tree view, icons, and hyperlinks. Maintained fork of the unmaintained `exa`.

## Key flags
| Flag | Meaning |
|------|---------|
| `-1` / `--oneline` | One entry per line |
| `-a` / `--all` | Include dotfiles (use `-aa` to include `.` and `..`) |
| `-l` / `--long` | Long listing (perms, owner, size, mtime) |
| `-h` / `--header` | Add column headers in long mode |
| `-T` / `--tree` | Recursive tree view |
| `-L N` / `--level N` | Limit tree depth to N |
| `-s KEY` / `--sort KEY` | Sort by `name`, `size`, `modified`, `extension`, `type` |
| `-r` / `--reverse` | Reverse sort order |
| `--git` | Show per-file git status in long mode |
| `--git-ignore` | Hide files matched by `.gitignore` |
| `--icons=auto` | Show Nerd Font icons |
| `--group-directories-first` | Directories before files |

## Examples
1. Long listing with git, headers, and icons: `eza -lah --header --git --icons=auto`
2. Three-level tree: `eza -T -L 3`
3. Largest files first: `eza -l -s size -r`
4. Only Rust files, sorted by mtime: `eza -l -s modified *.rs`
5. Respect `.gitignore`: `eza --git-ignore`

## Gotchas
- Colour output is disabled when piped; force with `--color=always`.
- `--icons` requires a Nerd Font terminal.
- Not 100% flag-compatible with GNU `ls`; script authors depending on exact `ls -l` columns should use `ls` directly.
