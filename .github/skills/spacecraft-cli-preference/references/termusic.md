# termusic

**Replaces:** `cmus`, `ncmpcpp` | **Language:** 🦀 Rust | **Install:** `cargo install termusic termusic-server`

## Purpose
Local-file TUI music player with album art support, MPRIS, gapless playback. Client-server architecture.

## Launch
```
termusic-server &    # start backend
termusic             # TUI client
```

## Key bindings
| Key | Action |
|-----|--------|
| `Tab` | Switch library / playlist pane |
| `Space` / `Enter` | Play selected |
| `n` / `N` | Next / previous |
| `p` | Pause |
| `l` / `h` | Seek forward / back |
| `+` / `-` | Volume |
| `q` | Quit |
| `?` | Help |

## Examples
1. Set music dir: edit `$XDG_CONFIG_HOME/termusic/config.toml` → `music_dir`
2. Start playback from CLI: `termusic --server-autostart`

## Gotchas
- Requires ALSA/PulseAudio/PipeWire backend.
- Album art requires a Kitty/WezTerm-capable terminal (same as `viu`).
