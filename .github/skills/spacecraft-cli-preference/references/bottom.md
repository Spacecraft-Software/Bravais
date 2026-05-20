# bottom (btm)

**Replaces:** `top`, `htop` | **Language:** 🦀 Rust | **Install:** `cargo install bottom`

## Purpose
Cross-platform TUI system monitor with CPU, memory, network, disk, process, and temperature graphs.

## Key flags (CLI)
| Flag | Meaning |
|------|---------|
| `-b` / `--basic` | Basic layout (no graphs) |
| `-t N` / `--rate N` | Refresh rate (ms) |
| `-S` / `--case_sensitive` | Case-sensitive process search |
| `--tree` | Process tree layout |
| `--battery` | Show battery widget |
| `--celsius` / `--fahrenheit` / `--kelvin` | Temperature units |
| `-g` / `--group_processes` | Group same-name processes |
| `-m` / `--mem_as_value` | Show mem as value, not % |
| `-C FILE` / `--config_location FILE` | Config |

## Key bindings (in TUI)
| Key | Action |
|-----|--------|
| `q` | Quit |
| `?` | Help |
| `/` | Search processes |
| `t` | Toggle tree |
| `dd` | Kill process |
| `e` | Expand widget |
| `Esc` | Close dialog/search |

## Examples
1. Launch: `btm`
2. Process tree, Celsius: `btm --tree --celsius`
3. Minimal layout on a low-res terminal: `btm -b`

## Gotchas
- Heavy graph rendering in Tmux can cause flicker — try `-b` or a lower refresh.
- Custom layouts via `bottom.toml` in `$XDG_CONFIG_HOME/bottom/`.
