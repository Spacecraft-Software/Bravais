# curl

**Replaces:** — (the standard itself) | **Language:** ⚠️ C | **Install:** distro repo (universally available)

## Purpose
The gold standard for HTTP/FTP/SMTP/etc. data transfer. Keep `curl` whenever a command must run portably across systems without Rust toolchain installed. Prefer `xh` for interactive/one-off API calls.

## Key flags
| Flag | Meaning |
|------|---------|
| `-s` / `--silent` | Suppress progress |
| `-S` / `--show-error` | With `-s`, still show errors |
| `-f` / `--fail` | Non-zero exit on HTTP ≥400 |
| `-L` / `--location` | Follow redirects |
| `-o FILE` / `-O` | Save to FILE / original name |
| `-X METHOD` | HTTP method |
| `-d DATA` / `--data` | POST body (URL-encoded) |
| `--data-raw`, `--data-binary` | No special interpretation |
| `-H HEADER` | Custom header |
| `-u USER:PASS` | Basic auth |
| `-b FILE` / `-c FILE` | Read / write cookie jar |
| `-k` / `--insecure` | Skip TLS verify |
| `-I` / `--head` | HEAD request |
| `-w FORMAT` | Write-out format (e.g. `%{http_code}`) |
| `--resolve HOST:PORT:IP` | Force DNS |
| `--retry N` / `--retry-delay N` | Retry on transient failures |
| `-C -` | Resume a partial download |

## Examples
1. Silent + fail-on-error download: `curl -sSfLO https://example.com/file.tar.gz`
2. POST JSON: `curl -fsS -X POST -H 'Content-Type: application/json' -d '{"a":1}' URL`
3. Download with retry: `curl --retry 5 --retry-delay 2 -LO URL`
4. Only HTTP code: `curl -s -o /dev/null -w '%{http_code}\n' URL`
5. Auth probe: `curl -fsS -u "$USER:$TOKEN" https://api.example.com/me`
6. Resume: `curl -C - -LO URL`

## Gotchas
- Always combine `-sS` when scripting so silent mode doesn't swallow errors.
- `-f` is important — without it, curl exits 0 on HTTP 500.
- `--data` URL-encodes; use `--data-raw` or `--data-binary` for exact bodies.
