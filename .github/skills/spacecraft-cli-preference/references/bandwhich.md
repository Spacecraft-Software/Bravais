# bandwhich

**Replaces:** `iftop`, `nethogs` | **Language:** 🦀 Rust | **Install:** `cargo install bandwhich`

## Purpose
Per-process/per-connection bandwidth monitor. Shows which process is using how much in real time.

## Key flags
| Flag | Meaning |
|------|---------|
| `-i IFACE` / `--interface IFACE` | Specific interface |
| `-r` / `--raw` | Machine-readable output, no TUI |
| `-n` / `--no-resolve` | Don't resolve IPs to hostnames |
| `-s` / `--show-dns` | Show DNS queries |
| `-d SEC` / `--dns-server` | Use specific DNS server |
| `-p` / `--processes` | Processes view only |
| `--total-utilization` | Include total line |

## Examples
1. Live TUI: `sudo bandwhich`
2. Single NIC: `sudo bandwhich -i eth0`
3. Scripting (one sample): `sudo bandwhich --raw -n | head`
4. No DNS lookups (lower latency): `sudo bandwhich -n`

## Gotchas
- Requires raw socket access — root or `CAP_NET_RAW,CAP_NET_ADMIN`.
- Running in a Docker container needs `--cap-add` + `--network=host`.
