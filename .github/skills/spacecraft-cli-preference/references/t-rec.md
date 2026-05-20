# t-rec

**Replaces:** `asciinema` (for GIF/MP4 output) | **Language:** 🦀 Rust | **Install:** `cargo install t-rec`

## Purpose
Terminal recorder that outputs animated GIF or MP4 directly — not just cast files. Records by screenshotting the terminal window.

## Key flags
| Flag | Meaning |
|------|---------|
| `-o FILE` / `--output FILE` | Output (extension picks format) |
| `-m` / `--video` | Produce MP4 (needs ffmpeg) |
| `-d MS` / `--decor MS` | Decoration / border (`shadow`, `none`) |
| `-b` / `--bg` | Background color (`white`, `black`, `transparent`) |
| `-q` / `--quiet` | No intro countdown |
| `-n` / `--natural` | Natural typing speed |
| `-e` / `--end-pause` | Freeze last frame |
| `-s` / `--start-pause` | Freeze first frame |

## Examples
1. Record a session to GIF: `t-rec -o demo.gif`
2. MP4 output: `t-rec -m -o demo.mp4`
3. With pauses at start and end: `t-rec -s 2s -e 2s -o demo.gif`

## Gotchas
- Records a single terminal window — don't resize mid-recording.
- On Wayland needs screencast permissions; X11 works out-of-box.
- MP4 output requires `ffmpeg` on PATH.
