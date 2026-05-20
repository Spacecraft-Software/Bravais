# msedit

**Replaces:** `nano`, minimal terminal editors | **Language:** 🦀 Rust | **Install:** `cargo install msedit`

## Purpose
Minimalist terminal text editor. Launch, type, save, quit — no modes, no configuration.

## Launch
```
msedit FILE
```

## Key bindings (CUA-style)
| Key | Action |
|-----|--------|
| `Ctrl+S` | Save |
| `Ctrl+Q` | Quit |
| `Ctrl+X` | Cut line |
| `Ctrl+C` | Copy |
| `Ctrl+V` | Paste |
| `Ctrl+Z` / `Ctrl+Y` | Undo / redo |
| `Ctrl+F` | Find |

## Examples
1. Edit a file: `msedit notes.txt`
2. Create new: `msedit newfile.md`

## Gotchas
- Intentionally minimal — for any code work, use `helix` instead.
- No split windows, no LSP, no multi-file buffers.
