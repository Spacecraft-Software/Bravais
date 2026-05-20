# dog

**Replaces:** `dig`, `nslookup` | **Language:** 🦀 Rust | **Install:** `cargo install dog` / distro repo

## Purpose
User-friendly DNS lookup with colourised output, JSON mode, native DoT/DoH support.

## Key flags
| Flag | Meaning |
|------|---------|
| `-1` / `--short` | Short output |
| `-J` / `--json` | JSON output |
| `-q NAME` | Query name (usually positional) |
| `-t TYPE` | Record type (`A`, `AAAA`, `MX`, `NS`, `TXT`, `CNAME`, …) |
| `-n NAMESERVER` | Specific nameserver |
| `--tcp` / `--udp` | Force transport |
| `--tls` | DNS-over-TLS (port 853) |
| `--https` | DNS-over-HTTPS |
| `-T` | Show TTL |
| `-Z` | Show response time |

## Examples
1. A record: `dog example.com`
2. MX records: `dog example.com MX`
3. Query 1.1.1.1 via DoH: `dog --https @1.1.1.1 anthropic.com`
4. JSON for scripting: `dog -J example.com | jaq '.responses[0].answers'`
5. Multiple types at once: `dog example.com A AAAA MX TXT`

## Gotchas
- Uses the system resolver by default — pass `@SERVER` for an explicit one.
- DoH URL format: `dog --https @https://cloudflare-dns.com/dns-query name`.
