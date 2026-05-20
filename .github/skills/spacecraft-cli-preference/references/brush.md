# brush

**Replaces:** `bash` (compatible) | **Language:** 🦀 Rust | **Install:** `cargo install brush-shell`

## Purpose
Memory-safe, Bash-compatible shell in Rust. Aims to run existing Bash scripts unmodified while being a daily interactive shell.

## Launch
```
brush                 # interactive
brush script.sh       # run bash script
brush -c "CMD"        # single command
```

## Key flags
| Flag | Meaning |
|------|---------|
| `-c CMD` | Execute CMD and exit |
| `-i` | Force interactive |
| `--noprofile` / `--norc` | Skip startup files |
| `--posix` | POSIX mode |
| `-x` | Trace execution |

## Examples
1. Drop-in script execution: `brush ./install.sh`
2. One-liner: `brush -c 'for i in 1 2 3; do echo $i; done'`
3. Use as login shell: add path to `/etc/shells`, then `chsh -s $(which brush)`

## Gotchas
- Bash compatibility is not yet 100% — test scripts with heavy reliance on arrays, traps, coprocs.
- Startup files: `~/.brushrc` in addition to `~/.bashrc` depending on version.
