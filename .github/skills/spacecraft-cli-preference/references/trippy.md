# trippy (trip)

**Replaces:** `traceroute`, `mtr` | **Language:** 🦀 Rust | **Install:** `cargo install trippy`

## Purpose
Network diagnostic TUI combining `traceroute` and `mtr`. ICMP/UDP/TCP probes, geolocation, DNS, IPv4/6.

## Key flags
| Flag | Meaning |
|------|---------|
| `-p PROTO` / `--protocol PROTO` | `icmp`, `udp`, `tcp` |
| `-P PORT` | Destination port (UDP/TCP) |
| `-L N` / `--multipath-strategy N` | ECMP detection |
| `-i SEC` / `--min-round-duration SEC` | Round interval |
| `-m N` / `--max-ttl N` | Max hops |
| `-z` / `--tui-refresh-rate` | UI refresh |
| `-r RESOLVER` | `system`, `resolv`, `google`, `cloudflare` |
| `--report-cycles N` | Non-TUI mode: run N cycles and print report |
| `--report-format FMT` | `pretty`, `csv`, `json`, `markdown`, `silent` |
| `-4` / `-6` | Force IPv4/6 |

## Examples
1. Interactive TUI: `trip example.com`
2. TCP trace to HTTPS port: `trip example.com -p tcp -P 443`
3. CI-friendly JSON report, 10 cycles: `trip example.com --report-cycles 10 --report-format json`
4. Multi-host (TUI tabs): `trip example.com cloudflare.com`

## Gotchas
- ICMP/UDP/TCP modes hit different path discovery semantics — results can differ.
- Raw sockets again → root or CAP_NET_RAW.
- `trip` and `trippy` are the same binary on most distros.
