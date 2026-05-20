# procs

**Replaces:** `ps` | **Language:** 🦀 Rust | **Install:** `cargo install procs`

## Purpose
Modern `ps` with colour, tree view, additional columns (TCP/UDP ports, Docker, read/write throughput), and keyword filtering.

## Key flags
| Flag | Meaning |
|------|---------|
| `<KEYWORD>` | Positional: filter by name/user/PID substring |
| `--tree` / `-t` | Tree layout |
| `--sortd KEY` / `--sorta KEY` | Sort descending / ascending by column |
| `--watch N` / `-W N` | Refresh every N seconds (like `top`) |
| `--watch-interval N` | Seconds between refreshes |
| `--insert COL` | Add column (e.g. `tcp`, `udp`, `docker`) |
| `--color always` | Force colour when piping |
| `--thread` / `-T` | Show threads |
| `--pager disable` | Don't paginate |

## Examples
1. Find Rust compiler processes: `procs rustc`
2. Process tree: `procs --tree`
3. Refreshing top-like view sorted by CPU: `procs --watch 1 --sortd cpu`
4. Show processes of a user: `procs $USER`
5. Find a PID holding a port: `procs --insert tcp | rg :8080`
6. Threads as well: `procs --thread firefox`

## Gotchas
- Unlike `ps`, `procs` has no direct equivalent of `-eLf` — use `--thread`.
- On some distros port columns require `CAP_NET_RAW` or root.
- Default output wraps to terminal width; use `--pager disable` + explicit columns in scripts.
