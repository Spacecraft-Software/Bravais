# ffmpeg

**Replaces:** — (Spacecraft Software-sanctioned toolkit) | **Language:** ⚠️ C | **Install:** distro repo

## Purpose
The multimedia swiss-army knife. No Rust replacement comes close — keep `ffmpeg`. Pair it with `rav1e` / `gifski` / `oxipng` where specific output formats benefit.

## Key flags
| Flag | Meaning |
|------|---------|
| `-i FILE` | Input |
| `-c:v CODEC` / `-c:a CODEC` | Video / audio codec |
| `-b:v RATE` / `-b:a RATE` | Bitrate |
| `-crf N` | Constant rate factor (x264/x265) |
| `-r N` | Frame rate |
| `-s WxH` / `-vf "scale=W:H"` | Resize |
| `-ss T` / `-to T` / `-t DUR` | Seek / end / duration |
| `-an` / `-vn` / `-sn` | Drop audio / video / subs |
| `-map 0:v:0 -map 0:a:0` | Stream selection |
| `-f FMT` | Force format |
| `-y` | Overwrite output |
| `-threads N` | Parallelism |

## Examples
1. Convert MP4 → WebM: `ffmpeg -i in.mp4 -c:v libvpx-vp9 -c:a libopus out.webm`
2. Trim: `ffmpeg -ss 00:00:10 -t 30 -i in.mp4 -c copy clip.mp4`
3. Extract audio: `ffmpeg -i in.mp4 -vn -c:a copy out.m4a`
4. Burn subtitles: `ffmpeg -i in.mp4 -vf "subtitles=sub.srt" -c:a copy out.mp4`
5. GIF via palette (before gifski was common): `ffmpeg -i in.mp4 -vf "fps=15,scale=480:-1" out.gif`
6. Concat losslessly: `ffmpeg -f concat -safe 0 -i list.txt -c copy joined.mp4`
7. Pipe to rav1e: `ffmpeg -i in.mp4 -f yuv4mpegpipe - | rav1e - -o out.ivf`

## Gotchas
- `-ss` before `-i` = fast seek (keyframe); after `-i` = accurate but slow.
- `-c copy` is lossless but requires compatible container + codec.
- Mixing input and output flags by position is error-prone — always annotate.
