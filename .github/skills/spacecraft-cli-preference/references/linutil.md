# linutil

**Replaces:** ad-hoc post-install scripts | **Language:** 🦀 Rust | **Install:** `cargo install linutil-tui` / upstream installer

## Purpose
Distro-agnostic TUI for Linux setup and maintenance: system updates, driver installs, common toolchain setup, tweaks. Community scripts bundled.

## Launch
```
linutil          # TUI
linutil --help   # flags
```

## Key bindings
| Key | Action |
|-----|--------|
| `↑`/`↓` | Navigate |
| `Enter` | Run selected script |
| `/` | Search |
| `Tab` | Toggle tree sections |
| `q` | Quit |

## Gotchas
- Scripts are opinionated community contributions — read before executing.
- Some scripts assume Arch; check compatibility in each section header.
