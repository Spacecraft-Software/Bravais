# topgrade

**Replaces:** hand-written "update everything" scripts | **Language:** 🦀 Rust | **Install:** `cargo install topgrade`

## Purpose
Detects every package manager/tool on the system (apt, pacman, nix, flatpak, brew, cargo, rustup, npm, pnpm, pip, gem, tldr, vim plugins, docker, …) and updates them all in one pass.

## Key flags
| Flag | Meaning |
|------|---------|
| `-y` / `--yes` | No confirmations |
| `--only STEP[,STEP]` | Run only listed steps |
| `--disable STEP` | Skip step |
| `--dry-run` / `-n` | Show what would run |
| `-c` / `--cleanup` | Do cleanup passes (cargo cache, apt autoremove, etc.) |
| `--no-retry` | Don't prompt to retry failed steps |
| `--skip-notify` | No notifications |
| `-t SECS` / `--ssh-arguments` | Remote targets |
| `--edit-config` | Open config |

## Examples
1. Update everything: `topgrade`
2. Dry-run: `topgrade -n`
3. Only rust + cargo: `topgrade --only rustup,cargo`
4. Systemd timer friendly: `topgrade -y -c --skip-notify`

## Gotchas
- Runs many privileged commands in sequence (`sudo pacman`, etc.) — expect password prompts, or set up `sudo` caching.
- Config: `$XDG_CONFIG_HOME/topgrade.toml` — disable noisy steps there.
