# monolith

**Replaces:** `wget --page-requisites --convert-links`, browser "Save Page As" | **Language:** 🦀 Rust | **Install:** `cargo install monolith`

## Purpose
Saves a complete web page as a single self-contained HTML file (CSS/JS/images/fonts inlined as data URIs).

## Key flags
| Flag | Meaning |
|------|---------|
| `-o FILE` / `--output FILE` | Output path (`-` for stdout) |
| `-a` / `--no-audio` | Strip audio |
| `-v` / `--no-video` | Strip video |
| `-i` / `--no-images` | Strip images |
| `-j` / `--no-js` | Strip JavaScript |
| `-s` / `--silent` | Silent |
| `-F` / `--isolate` | CSP that blocks network requests in saved file |
| `-M` / `--no-metadata` | Strip metadata comment |
| `-u UA` / `--user-agent UA` | Custom User-Agent |
| `-t SEC` / `--timeout SEC` | Network timeout |

## Examples
1. Archive a page: `monolith https://example.com/article -o article.html`
2. Sanitised (no scripts, no network): `monolith -F -j https://example.com/page -o safe.html`
3. Text-only: `monolith -i -j -v -a https://example.com -o text.html`

## Gotchas
- JavaScript-rendered sites capture the initial HTML only; for SPAs, use headless-browser-backed tools.
- `-F --no-js --no-metadata --isolate` is a good default for long-term archiving.
