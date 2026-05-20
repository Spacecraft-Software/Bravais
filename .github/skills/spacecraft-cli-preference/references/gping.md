# gping

**Replaces:** `ping` (visual) | **Language:** 🦀 Rust | **Install:** `cargo install gping`

## Purpose
Ping with a live graph. Multiple hosts plotted concurrently; can even graph exit latency of shell commands.

## Key flags
| Flag | Meaning |
|------|---------|
| `-4` / `-6` | Force IPv4 / IPv6 |
| `-s` | Simple output (no graph) |
| `-n N` | Samples per second |
| `-i SEC` / `--watch-interval SEC` | Ping interval |
| `-b N` / `--buffer N` | Seconds of history in buffer |
| `--cmd CMD` | Graph exit-time of CMD instead of ICMP |

## Examples
1. Ping a single host: `gping 1.1.1.1`
2. Compare two: `gping 8.8.8.8 1.1.1.1`
3. Graph a command's latency: `gping --cmd curl https://api.example.com/health`
4. Text-only: `gping -s example.com`

## Gotchas
- ICMP may require raw sockets → needs root or CAP_NET_RAW on Linux.
- Terminal must support 256 colours + UTF-8 for the graph.
