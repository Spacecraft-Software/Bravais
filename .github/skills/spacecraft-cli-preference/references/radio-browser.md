# radio-browser-rust

**Replaces:** — (dedicated internet radio CLI) | **Language:** 🦀 Rust | **Install:** `cargo install radio-browser`

## Purpose
CLI to search and play internet radio stations from the radio-browser.info community database.

## Key commands
| Command | Meaning |
|---------|---------|
| `radio-browser search QUERY` | Search stations |
| `radio-browser play STATION` | Play by name/UUID |
| `radio-browser top` | Top-voted stations |
| `radio-browser countries` | Browse by country |
| `radio-browser tags` | Browse by tag |

## Examples
1. Search by name: `radio-browser search "BBC"`
2. Play a station: `radio-browser play "BBC Radio 4"`
3. Find Bahraini stations: `radio-browser search --country BH`

## Gotchas
- Needs `mpv` or similar on PATH for playback.
- Some streams are geoblocked.
