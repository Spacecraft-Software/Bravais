# xh

**Replaces:** `curl` (interactive/API work) | **Language:** 🦀 Rust | **Install:** `cargo install xh`

## Purpose
Friendly, fast HTTP client with HTTPie-style syntax. For ad-hoc API probing, prefer `xh`; keep `curl` for cross-system shell scripts.

## Syntax
```
xh [METHOD] URL [REQUEST_ITEMS...]
```
Request items:
- `name=value` → JSON field
- `name:=value` → raw JSON (numbers, booleans, arrays)
- `name==value` → query string
- `name:value` → header
- `name@file` → file upload

## Key flags
| Flag | Meaning |
|------|---------|
| `-f` | Form-encode body |
| `-j` | Force JSON body (default when body items present) |
| `-a USER:PASS` | Basic auth |
| `-A bearer -a TOKEN` | Bearer auth |
| `-h` | Only print response headers |
| `-b` | Only print response body |
| `-p PRINT` | `H`=request headers, `B`=request body, `h`=response headers, `b`=response body |
| `--follow` | Follow redirects |
| `--verify=no` | Skip TLS verification |
| `-d` | Download mode (streaming to file) |
| `-o FILE` | Write body to FILE |
| `-S` | Stream response |

## Examples
1. GET JSON: `xh https://api.github.com/repos/UnbreakableMJ/Understand-Anything`
2. POST JSON body: `xh POST api.example.com/users name=alice age:=30 active:=true`
3. Headers + query: `xh api.com/search q==rust 'Authorization:Bearer $TOKEN'`
4. File upload: `xh POST api.com/upload file@/tmp/data.csv`
5. Download: `xh -d https://example.com/release.tar.gz`
6. Follow redirects, show everything: `xh --follow -p HhBb example.com`

## Gotchas
- `:=` vs `=`: use `:=` for non-string JSON values.
- No `-X` method flag — method goes first positionally.
- `xh` colourises output for TTYs; pipe via `--pretty=none` for scripts.
