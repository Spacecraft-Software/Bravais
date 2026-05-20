# rustscan

**Replaces:** `nmap` (fast-scan front-end) | **Language:** 🦀 Rust | **Install:** `cargo install rustscan`

## Purpose
Extremely fast TCP port scanner; typically pipes into `nmap` for deeper enumeration. **Only scan hosts you have explicit authorisation to test.**

## Key flags
| Flag | Meaning |
|------|---------|
| `-a HOST` / `--addresses HOST` | Target(s) (CIDR, comma list, or file) |
| `-p PORTS` / `--ports PORTS` | Specific ports (e.g. `80,443,8000-9000`) |
| `-r RANGE` / `--range RANGE` | Port range (default `1-65535`) |
| `-u LIMIT` / `--ulimit LIMIT` | File-descriptor limit |
| `-b N` / `--batch-size N` | Parallel sockets |
| `-t MS` / `--timeout MS` | Per-port timeout |
| `--scan-order RANDOM\|SERIAL` | Scan order |
| `-g` / `--greppable` | Plain output |
| `--accessible` | Screen-reader-friendly |
| `--` | Pass remaining flags to `nmap` |

## Examples
1. Scan a host then hand off to nmap for service detection: `rustscan -a 10.0.0.1 -- -sV -A`
2. Limit to common ports: `rustscan -a example.com -p 22,80,443,8080`
3. Subnet sweep: `rustscan -a 192.168.1.0/24 -b 5000`
4. Grep-able output: `rustscan -a host -g`

## Gotchas
- Extremely aggressive defaults can trigger IDS alerts.
- File-descriptor limit: bump with `ulimit -n 65535` or the `-u` flag.
- Running against infrastructure you don't own or administer is typically illegal — always get authorisation.
