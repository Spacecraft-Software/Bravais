# yt-dlp

**Replaces:** `youtube-dl`, all youtube-dl forks | **Language:** 🐍 Python | **Install:** `pip install yt-dlp` / distro repo

## Purpose
Feature-rich media downloader for YouTube and 1000+ sites. Gold standard; no Rust equivalent comes close.

## Key flags
| Flag | Meaning |
|------|---------|
| `-o TEMPLATE` | Output filename template |
| `-f FORMAT` | Format selector (`best`, `bestvideo+bestaudio`, `137+140`, etc.) |
| `-F URL` | List available formats |
| `-x` | Extract audio |
| `--audio-format FMT` | `mp3`, `m4a`, `opus`, `flac` |
| `--audio-quality N` | 0 (best) — 9 |
| `-a FILE` | Read URLs from file |
| `-i` | Ignore errors |
| `--embed-subs` / `--embed-thumbnail` | Embed |
| `--write-sub` / `--sub-langs en,de` | Write subs |
| `--cookies-from-browser firefox` | Use browser cookies |
| `--playlist-items 1-5` | Range |
| `-q` / `-v` | Quiet / verbose |
| `--download-archive FILE` | Skip already-downloaded |

## Examples
1. Best video+audio: `yt-dlp -f "bv*+ba/b" URL`
2. MP3 audio: `yt-dlp -x --audio-format mp3 --audio-quality 0 URL`
3. List formats first: `yt-dlp -F URL`
4. Named output: `yt-dlp -o "%(title)s.%(ext)s" URL`
5. Channel with archive (avoid redownloading): `yt-dlp --download-archive seen.txt -o "%(channel)s/%(title)s.%(ext)s" CHANNEL_URL`
6. With browser cookies for members-only content: `yt-dlp --cookies-from-browser firefox URL`

## Gotchas
- Keep yt-dlp **updated** — site extractors break often (`pip install -U yt-dlp`).
- `ffmpeg` required for format merging and audio extraction.
- Rate-limiting: `--sleep-interval 2 --max-sleep-interval 5` for politeness.
