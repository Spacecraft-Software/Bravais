# mpv

**Replaces:** — (Spacecraft Software-sanctioned player) | **Language:** ⚠️ C | **Install:** distro repo

## Purpose
Versatile, high-quality command-line media player. No Rust replacement is as capable; keep `mpv`.

## Key flags
| Flag | Meaning |
|------|---------|
| `--fs` | Fullscreen |
| `--loop=inf` / `--loop-file=inf` | Loop |
| `--shuffle` | Shuffle playlist |
| `--speed=N` | Playback speed |
| `--start=POS` / `--end=POS` | Trim range |
| `--no-audio` / `--no-video` | Disable stream |
| `--sid=N` / `--aid=N` | Subtitle / audio track |
| `--sub-file=FILE` | External subtitle |
| `--ytdl-format=FMT` | yt-dlp format |
| `--screenshot-format=PNG` | Screenshot format |
| `-o FILE` / `--o=FILE` | Dump to file (with `--o-format`) |

## Examples
1. Play a file: `mpv movie.mkv`
2. Play a YouTube URL: `mpv https://youtu.be/ID`
3. Loop a clip: `mpv --loop-file=inf clip.mp4`
4. Specific subtitle: `mpv --sub-file=en.srt movie.mkv`
5. Audio-only background: `mpv --no-video podcast.mp3`
6. Extract a clip: `mpv --start=00:01:00 --end=00:02:00 --o=clip.mp4 input.mp4`

## Gotchas
- YouTube support depends on `yt-dlp` being on PATH and current.
- Input config: `~/.config/mpv/input.conf`; main config: `mpv.conf`.
