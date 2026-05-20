# ncspot

**Replaces:** Spotify GUI (terminal alternative) | **Language:** 🦀 Rust | **Install:** `cargo install ncspot`

## Purpose
TUI Spotify client. Requires a Spotify Premium account.

## Launch
```
ncspot
```

## Key bindings
| Key | Action |
|-----|--------|
| `Space` | Play/pause |
| `n` / `p` | Next / previous track |
| `s` | Search |
| `q` | Queue view |
| `l` | Library |
| `Enter` | Select |
| `/` | Search within view |
| `Shift+Q` | Quit |
| `?` | Help |

## Examples
1. Launch: `ncspot`
2. Set up MPRIS (control from media keys): enable `use_mpris = true` in config
3. Playback control from another terminal: `dbus-send` to the MPRIS interface, or use `playerctl`

## Gotchas
- First launch prompts for Spotify credentials; stored in `$XDG_CONFIG_HOME/ncspot/`.
- Premium-only — free accounts hit API errors.
- Config for keybindings and theme: `$XDG_CONFIG_HOME/ncspot/config.toml`.
