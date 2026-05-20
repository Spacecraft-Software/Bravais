# helix (hx)

**Replaces:** `vim`, `neovim` | **Language:** 🦀 Rust | **Install:** `cargo install --locked helix-term` / distro

## Purpose
Post-modern modal editor with multiple cursors, tree-sitter syntax, and built-in LSP. No plugins needed for a full dev loop.

## Launch
```
hx FILE…
hx +N FILE           # open at line N
hx --health          # diagnose LSP/grammars
```

## Key bindings (sample)
| Key | Action |
|-----|--------|
| `Esc` | Normal mode |
| `i` / `a` / `o` | Insert before / after / open line |
| `w`/`b`/`e` | Word motions |
| `x` | Select line |
| `d` / `y` / `c` | Delete / yank / change |
| `u` / `U` | Undo / redo |
| `%s` | Select whole buffer |
| `g g` / `g e` | Top / bottom |
| `Space f` | File picker (fuzzy) |
| `Space b` | Buffer picker |
| `Space /` | Workspace grep |
| `Space k` | Hover docs (LSP) |
| `g d` | Go to definition |
| `g r` | References |
| `:` | Command mode (`:w`, `:q`, `:wq!`) |

## Examples
1. Edit: `hx src/main.rs`
2. Open multiple files: `hx Cargo.toml src/lib.rs`
3. Check LSP setup: `hx --health rust`
4. Edit config: `hx ~/.config/helix/config.toml`

## Gotchas
- Selection comes before action (`w d` = select-word-then-delete), unlike Vim's `dw`.
- LSP needs the language server installed separately (`rust-analyzer`, `gopls`, `clangd`, etc.).
- No plugin ecosystem yet — the tradeoff for a batteries-included core.
