# wget2

**Replaces:** `wget` | **Language:** ⚠️ C | **Install:** distro repo

## Purpose
Successor to wget. Multithreaded HTTP/2 downloader, better for large mirrors and batch fetches.

## Key flags
| Flag | Meaning |
|------|---------|
| `-O FILE` | Save to FILE |
| `-P DIR` | Save under DIR |
| `-c` | Resume partial |
| `-r` | Recursive |
| `-np` | No parent (limit recursion upward) |
| `-nd` | No directory structure |
| `-l N` | Recursion depth |
| `--threads N` | Parallel connections (wget2-specific) |
| `-k` / `--convert-links` | Rewrite links for local viewing |
| `-U UA` | User-Agent |
| `--tries N` | Retry count |

## Examples
1. Parallel download: `wget2 --threads 8 https://big.example.com/file.iso`
2. Mirror a docs site: `wget2 -r -np -k -P docs/ https://example.com/docs/`
3. Resume interrupted: `wget2 -c URL`

## Gotchas
- Not a 100% flag-compat drop-in for wget — review scripts.
- For single ad-hoc requests, `curl -LO` is usually simpler.
