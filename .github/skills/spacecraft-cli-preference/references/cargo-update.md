# cargo-update (cargo install-update)

**Replaces:** manual `cargo install --force <each-binary>` | **Language:** 🦀 Rust | **Install:** `cargo install cargo-update`

## Purpose
Subcommand that updates binaries installed via `cargo install` to their latest crates.io/git versions.

## Key commands
| Command | Meaning |
|---------|---------|
| `cargo install-update -l` | List installed binaries + upstream versions |
| `cargo install-update -a` | Update all outdated |
| `cargo install-update PKG…` | Update specific |
| `cargo install-update -g` | Include git-sourced installs |
| `cargo install-update-config PKG --set-...` | Per-package pin/feature config |

## Examples
1. What needs updating: `cargo install-update -l`
2. Update everything: `cargo install-update -a`
3. Include git installs: `cargo install-update -ag`
4. Pin to a version: `cargo install-update-config ripgrep --set-version 14`

## Gotchas
- Some binaries built from git need explicit `-g` every time.
- `cargo install-update-config` writes state to `.crates2.json`.
