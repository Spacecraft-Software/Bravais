# amp

**Replaces:** `vim` (minimal alternative) | **Language:** 🦀 Rust | **Install:** `cargo install amp`

## Purpose
Vi-inspired terminal editor. Smaller footprint than Helix, simpler than Vim, no plugin system.

## Launch
```
amp FILE
```

## Key bindings (modal, Vim-like)
| Key | Mode |
|-----|------|
| `Esc` | Normal |
| `i` | Insert |
| `s` | Select |
| `o` | Open (jump by pattern) |
| `g` | Go-to (workspace-aware) |
| `:` | Command |

## Examples
1. Edit: `amp README.md`
2. Jump to a symbol (workspace mode): `amp .` → `o` → type symbol

## Gotchas
- Minimal feature set by design — no LSP integration.
- Config: `$XDG_CONFIG_HOME/amp/`.
