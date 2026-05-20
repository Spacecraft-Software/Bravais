# ouch

**Replaces:** `tar`, `gzip`, `zip`/`unzip`, `7z`, `xz` | **Language:** 🦀 Rust | **Install:** `cargo install ouch`

## Purpose
One command for all archive formats. Format inferred from extension. Supports tar, zip, 7z, gz, bz2, xz, zstd, lz4, sz.

## Key flags
| Flag | Meaning |
|------|---------|
| `compress` (or `c`) | Create archive |
| `decompress` (or `d`) | Extract archive |
| `list` (or `l`) | List contents |
| `-y` / `--yes` | Answer yes to all prompts |
| `-n` / `--no` | Answer no to all prompts |
| `-d DIR` / `--dir DIR` | Extract to directory |
| `--format FMT` | Override format detection |

## Examples
1. Compress: `ouch compress src/ src.tar.gz`
2. Multiple inputs into zip: `ouch compress a b c bundle.zip`
3. Nested formats: `ouch compress dir/ out.tar.zst`
4. Decompress into a specific directory: `ouch decompress archive.tar.xz -d extracted/`
5. List archive contents: `ouch list archive.7z`
6. Auto-yes overwrite: `ouch -y d backup.zip`

## Gotchas
- Format is inferred from the output filename's extensions — `.tar.gz` works, `.tgz` too.
- For huge archives, `tar` with pipeline tools is still more memory-efficient.
- No streaming mode; reads the whole archive metadata up front.
