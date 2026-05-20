# lorri

**Replaces:** manual `nix-shell` invocations | **Language:** 🦀 Rust | **Install:** via nix, or `cargo install lorri`

## Purpose
Daemon that watches `shell.nix` / `default.nix` and keeps a cached build environment hot. Integrates with `direnv` for automatic per-directory shell activation.

## Setup
1. Install: `nix-env -iA nixpkgs.lorri` (or cargo).
2. Start the daemon: `systemctl --user enable --now lorri.service` (or use the launchd/OpenRC unit).
3. In each project: `echo "eval \"\$(lorri direnv)\"" > .envrc && direnv allow`

## Key commands
| Command | Meaning |
|---------|---------|
| `lorri init` | Create `shell.nix` + `.envrc` scaffolding |
| `lorri daemon` | Run the watcher (usually as user unit) |
| `lorri watch` | One-shot watch + build |
| `lorri direnv` | Print direnv-compatible shell snippet |
| `lorri gc` | GC old build roots |

## Examples
1. New project: `lorri init && direnv allow`
2. Force rebuild: `touch shell.nix` (daemon picks it up)
3. Clear build roots: `lorri gc`

## Gotchas
- Requires Nix with flakes or classic; on flakes projects prefer `direnv` + `nix develop` via `use flake` in `.envrc`.
- Lorri's upstream has slowed — newer Bravais work may prefer plain `direnv + nix-direnv`.
