# yazi

**Replaces:** `ranger`, `nnn`, `mc` | **Language:** 🦀 Rust | **Install:** `cargo install yazi-fm yazi-cli`

## Purpose
Blazing-fast async terminal file manager with image previews, plugin system, and vim-like keybindings. Spacecraft Software's preferred TUI file manager.

## Launch
```
yazi [PATH]
```

## Key bindings
| Key | Action |
|-----|--------|
| `h`/`j`/`k`/`l` | Navigate |
| `g`/`G` | Top / bottom |
| `Space` | Select |
| `v` | Visual mode |
| `y` / `d` / `p` | Yank / cut / paste |
| `a` | Create file/dir (trailing `/` = dir) |
| `r` | Rename |
| `o` / `O` | Open / open with picker |
| `f` | Filter |
| `/` | Find (forward) |
| `s` | Sort menu |
| `.` | Toggle hidden |
| `t` | New tab |
| `[` / `]` | Prev/next tab |
| `;` | Command input |
| `q` | Quit |

## Examples
1. Launch at $HOME: `yazi ~`
2. Change directory on exit: `function y { yazi --cwd-file=/tmp/yazicwd "$@" && cd "$(< /tmp/yazicwd)"; }`
3. Set default editor: export `EDITOR=hx` before launch

## Gotchas
- Image previews need a graphics-capable terminal (kitty, WezTerm, Ghostty) or `ueberzugpp`.
- Config: `$XDG_CONFIG_HOME/yazi/{yazi,keymap,theme}.toml`.
- `cd-on-exit` requires the shell wrapper shown above; the binary itself cannot `cd` in the parent shell.
