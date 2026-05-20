# paru

**Replaces:** `yay`, raw `makepkg` | **Language:** 🦀 Rust | **Install:** Arch `pacman -S paru`

## Purpose
Feature-rich AUR helper for Arch and derivatives. `pacman`-compatible flags, with AUR search, PKGBUILD inspection, and upgrade workflows.

## Key commands
| Command | Meaning |
|---------|---------|
| `paru` | Interactive upgrade (repo + AUR) |
| `paru -S PKG` | Install (repo or AUR) |
| `paru -Ss QUERY` | Search repo |
| `paru -Sua` | Upgrade AUR packages only |
| `paru -Syu` | Full upgrade |
| `paru -Rns PKG` | Remove with deps + config |
| `paru -Qu` | Pending upgrades |
| `paru -G PKG` | Clone PKGBUILD |
| `paru -Fy` / `paru -F FILE` | File database (find which pkg owns FILE) |

## Examples
1. Interactive review + upgrade: `paru`
2. Install from AUR: `paru -S rage`
3. Dry-run of upgrades: `paru -Qu`
4. Only AUR upgrades: `paru -Sua`

## Gotchas
- AUR PKGBUILDs run arbitrary build scripts — always review (`paru --review`).
- Keep `paru.conf` `SudoLoop` on for unattended long builds.
