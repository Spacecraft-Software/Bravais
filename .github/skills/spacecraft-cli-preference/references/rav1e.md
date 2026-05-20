# rav1e

**Replaces:** AV1 encoders (libaom, SVT-AV1 — alternative) | **Language:** 🦀 Rust | **Install:** `cargo install rav1e` / distro

## Purpose
Fast, memory-safe AV1 video encoder. Outputs IVF or raw Annex-B. Pair with `ffmpeg` for container muxing.

## Key flags
| Flag | Meaning |
|------|---------|
| `-o FILE` | Output path |
| `-s N` / `--speed N` | 0 (slowest/best) — 10 (fastest) |
| `-q N` / `--quantizer N` | Constant quantizer (0–255) |
| `--tile-rows N` / `--tile-cols N` | Tiling |
| `--threads N` | Thread count |
| `--limit N` | Encode only N frames |
| `--output-invalid-frames` | Include invalid frames (debug) |
| `--first-pass FILE` / `--second-pass FILE` | Two-pass |

## Examples
1. Encode a Y4M to AV1 IVF: `rav1e -s 6 -q 100 input.y4m -o out.ivf`
2. Pipe from ffmpeg: `ffmpeg -i in.mp4 -f yuv4mpegpipe - | rav1e - -o out.ivf`
3. Mux AV1 + Opus audio: `ffmpeg -i out.ivf -i audio.opus -c copy out.mkv`
4. Fastest reasonable: `rav1e -s 9 -q 130 in.y4m -o out.ivf`

## Gotchas
- Input must be raw Y4M/YUV — use `ffmpeg` for any other format.
- Speed 0–3 is impractical for anything beyond short clips.
- For HEVC/H.264 output, stick with `ffmpeg` + `x264`/`x265`.
