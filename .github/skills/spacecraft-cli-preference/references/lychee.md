# lychee

**Replaces:** link-checker scripts, `markdown-link-check` | **Language:** 🦀 Rust | **Install:** `cargo install lychee`

## Purpose
Fast async link checker for Markdown, HTML, RST, emails, arbitrary text. Suitable for CI.

## Key flags
| Flag | Meaning |
|------|---------|
| `-c FILE` / `--config FILE` | Config file (`lychee.toml`) |
| `-b URL` / `--base URL` | Base URL for relative links |
| `-r N` / `--retry-wait-time N` | Retry delay |
| `--max-retries N` | Retry count |
| `--accept CODES` | HTTP codes to accept (e.g. `200,204,403`) |
| `--exclude PATTERN` | Skip URLs matching regex |
| `--offline` | Skip remote links |
| `--include-mail` | Check `mailto:` |
| `--format FMT` | `markdown`, `json`, `detailed`, `compact` |
| `-o FILE` | Write report |
| `--cache` / `--no-progress` | CI helpers |

## Examples
1. Check a README: `lychee README.md`
2. Check a whole site: `lychee --offline ./book/`
3. CI-friendly JSON: `lychee --format json 'docs/**/*.md' -o links.json`
4. Ignore internal hosts: `lychee --exclude 'internal\.example\.com' docs/`

## Gotchas
- Default user agent may get rate-limited by big sites; set one via config.
- Use `--cache` + `--max-cache-age 1d` for CI runs to avoid hammering upstream.
