# gifski

**Replaces:** `ffmpeg`-based GIF pipelines, `convert` (ImageMagick) for GIF | **Language:** 🦀 Rust | **Install:** `cargo install gifski`

## Purpose
High-quality GIF encoder based on the pngquant palette generator. Produces smaller, better-looking GIFs from video or PNG frames.

## Key flags
| Flag | Meaning |
|------|---------|
| `-o FILE` / `--output FILE` | Output GIF |
| `--fps N` | Frames per second |
| `--quality N` | 1–100 |
| `-W N` / `--width N` | Resize width |
| `-H N` / `--height N` | Resize height |
| `--fast` | Prefer speed |
| `--repeat N` | Loop count (0 = infinite) |
| `--motion-quality N` | Per-frame dither quality |
| `--lossy-quality N` | Lossy compression level |

## Examples
1. From frames: `gifski -o out.gif --fps 30 frames/*.png`
2. From video via ffmpeg: `ffmpeg -i in.mp4 -vf "fps=20,scale=720:-1" -f image2pipe -vcodec png - | gifski -o out.gif --fps 20 -`
3. Resize + loop: `gifski -W 480 --repeat 0 -o loop.gif *.png`

## Gotchas
- Frames must be supplied as PNGs or via pipe — no direct video input.
- Large frame counts need lots of RAM.
