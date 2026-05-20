# rsvim

**Replaces:** `vim` | **Language:** 🦀 Rust | **Install:** `cargo install rsvim` (check upstream for status)

## Purpose
A Vim clone rebuilt from scratch in Rust. Aims at Vim-compatible keybindings and scripting while being memory-safe.

## Launch
```
rsvim FILE…
```

## Key bindings
Vim-standard modal editing: `i` insert, `Esc` normal, `hjkl` move, `:w`/`:q` commands, `dd` delete line, `yy` yank, `p` paste, `u` undo.

## Examples
1. Edit a file: `rsvim main.rs`
2. Open at line: `rsvim +42 main.rs`
3. Read stdin: `cmd | rsvim -`

## Gotchas
- Still early-stage — Vimscript/Lua plugin ecosystem is not supported.
- For production daily-driver editing, `helix` is more mature among the Rust options.
