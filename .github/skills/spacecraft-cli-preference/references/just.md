# just

**Replaces:** `make` (for task running) | **Language:** 🦀 Rust | **Install:** `cargo install just`

## Purpose
Modern command runner. `Justfile` syntax is cleaner than Make's, no tab/space traps, first-class dependencies, `.env` support.

## Justfile basics
```make
default: build test

build:
    cargo build --release

test:
    cargo nextest run

fmt:
    cargo fmt --all

clean:
    cargo clean
    rm -rf dist/

# With parameter
release version:
    cargo publish -p {{version}}
```

## Key flags
| Flag | Meaning |
|------|---------|
| `-l` / `--list` | List recipes |
| `-s RECIPE` / `--show RECIPE` | Show recipe source |
| `-n` / `--dry-run` | Print commands, don't execute |
| `--choose` | Interactive recipe picker (needs `fzf`) |
| `-f FILE` / `--justfile FILE` | Use non-default Justfile |
| `-d DIR` / `--working-directory DIR` | Run from DIR |
| `--evaluate` | Dump variables + exit |
| `--set NAME VAL` | Override variable |

## Examples
1. Run default recipe: `just`
2. List recipes: `just -l`
3. Run a parameterised recipe: `just release 1.2.0`
4. Pick interactively: `just --choose`
5. Dry run: `just -n build`

## Gotchas
- Indentation is either tabs OR spaces consistently — mixing breaks parse.
- Recipes run in a fresh shell each line unless you use `\` to chain.
- Uses `sh` by default; switch with `set shell := ["nu", "-c"]` or `["ion", "-c"]` at the top of the Justfile.
