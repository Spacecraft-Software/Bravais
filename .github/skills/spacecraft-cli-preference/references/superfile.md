# superfile (spf)

**Replaces:** TUI file managers | **Language:** 🐹 Go | **Install:** upstream installer / distro

## Purpose
Visually rich TUI file manager with tabs, split panes, built-in image previews, and a modern look.

## Launch
```
spf           # current dir
spf PATH      # specific dir
```

## Key bindings
| Key | Action |
|-----|--------|
| `h`/`j`/`k`/`l` | Navigate |
| `Enter` | Open |
| `a` | New file/dir |
| `r` | Rename |
| `c` / `x` / `v` | Copy / cut / paste |
| `d` | Delete |
| `/` | Search |
| `Tab` / `Shift+Tab` | Next/prev pane |
| `L` | New pane |
| `H` | Close pane |
| `q` | Quit |

## Gotchas
- Config: `$XDG_CONFIG_HOME/superfile/`.
- Not as scriptable as `yazi`; prefer yazi for automation contexts.
