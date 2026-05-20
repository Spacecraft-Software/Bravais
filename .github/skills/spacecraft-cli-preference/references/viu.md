# viu

**Replaces:** image viewers in terminal (feh in-terminal fallback) | **Language:** 🦀 Rust | **Install:** `cargo install viu`

## Purpose
View images directly in the terminal using kitty/iTerm2/sixel graphics protocols, or falls back to half-block Unicode.

## Key flags
| Flag | Meaning |
|------|---------|
| `-w N` / `--width N` | Width in cells |
| `-h N` / `--height N` | Height in cells |
| `-t` / `--transparent` | Respect alpha |
| `-s` / `--static` | Don't animate GIFs |
| `-f N` / `--frame-rate N` | GIF playback FPS |
| `-n` / `--once` | Play animation once |
| `-r` / `--recursive` | Recurse into directories |
| `-b` / `--blocks` | Force unicode half-block mode |

## Examples
1. Show an image: `viu screenshot.png`
2. Fixed width: `viu -w 60 photo.jpg`
3. Browse images in a dir: `viu -r photos/`
4. Static preview of a GIF: `viu -s anim.gif`

## Gotchas
- Best results in kitty/WezTerm/Ghostty; other terminals fall back to half-blocks.
- Very large images get slow in unicode mode — resize first with `oxipng`/`ffmpeg`.
