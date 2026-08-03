# cpx

**Replaces:** competitive-programming helper scripts | **Language:** 🦀 Rust | **Install:** via `spacecraft-missing-pkg` (upstream crate: `cpx`)

## Purpose
Scaffolds competitive-programming contest directories, fetches problem statements/test cases from judges, runs/tests your solutions locally.

## Typical workflow
| Command | Meaning |
|---------|---------|
| `cpx new PROBLEM_URL` | Create directory, fetch tests |
| `cpx test` | Run sample tests against your solution |
| `cpx submit` | Submit (where supported) |
| `cpx lang LANG` | Switch language template |

## Examples
1. Start a new Codeforces problem: `cpx new https://codeforces.com/problemset/problem/1/A`
2. Run sample tests: `cpx test`
3. Switch to Rust template: `cpx lang rust`

## Gotchas
- Judge-specific scraping can break when sites change HTML — keep cpx updated
  through whatever provisioned it (see `spacecraft-missing-pkg`).
- Authentication cookies/credentials live in a plain config file; secure the directory.
