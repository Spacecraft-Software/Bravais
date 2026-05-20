# sniffglue

**Replaces:** `tcpdump` (partial) | **Language:** 🦀 Rust | **Install:** `cargo install sniffglue`

## Purpose
Secure, multithreaded packet sniffer. Parses common protocols (Ethernet, IPv4/6, TCP, UDP, DNS, TLS, HTTP) with sandboxed workers.

## Key flags
| Flag | Meaning |
|------|---------|
| `-d DEV` | Capture device (e.g. `eth0`) |
| `-p PCAP` | Read from pcap file |
| `-v` | Verbose |
| `-n N` | Stop after N packets |
| `--promisc` | Promiscuous mode |
| `--insecure-disable-seccomp` | Disable sandbox (debugging only) |

## Examples
1. Sniff an interface: `sudo sniffglue -d eth0`
2. Read a capture: `sniffglue -p trace.pcap`
3. Just first 100 packets: `sudo sniffglue -d wlan0 -n 100`

## Gotchas
- Needs `CAP_NET_RAW` + `CAP_NET_ADMIN` (or root) to open the socket.
- Not a `tcpdump` BPF-filter replacement — for precise captures, still use `tcpdump` / `tshark`.
