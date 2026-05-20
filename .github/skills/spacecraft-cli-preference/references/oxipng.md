# oxipng

**Replaces:** `optipng`, `pngcrush` | **Language:** 🦀 Rust | **Install:** `cargo install oxipng`

## Purpose
Multithreaded, lossless PNG optimiser. Strips metadata, tries multiple filter/deflate strategies.

## Key flags
| Flag | Meaning |
|------|---------|
| `-o N` | Optimisation level 0–6 (default 2) |
| `-Z` | Zopfli compression (slower, smaller) |
| `--strip safe` / `all` | Metadata stripping |
| `-r` | Recurse into directories |
| `-p` / `--preserve` | Preserve timestamps |
| `--alpha` | Optimise alpha pre-multiplication |
| `-t N` / `--threads N` | Thread count |
| `--interlace 0` / `1` | Set PNG interlacing |

## Examples
1. Optimise in place: `oxipng -o 4 image.png`
2. Strip all metadata: `oxipng --strip all *.png`
3. Recursive, Zopfli, max compression: `oxipng -r -Z -o max assets/`
4. Keep timestamps: `oxipng -p -o 3 *.png`

## Gotchas
- In-place by default — make a backup or use `-P SUFFIX`.
- `-Z` can be 10× slower than `-o 4` for small gains.
