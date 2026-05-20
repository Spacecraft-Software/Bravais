# omni

**Replaces:** per-distro package managers (bridge) | **Language:** 🦀 Rust | **Install:** `cargo install omnicli` / GitHub release

## Purpose
Universal package-manager front-end. Translates generic install/search/remove commands to the host's native PM (pacman, apt, dnf, brew, xbps, nix, flatpak, pkg, …).

## Key commands
| Command | Meaning |
|---------|---------|
| `omni install PKG` | Install via native PM |
| `omni remove PKG` | Uninstall |
| `omni search QUERY` | Search |
| `omni update` | Refresh package indexes |
| `omni upgrade` | Upgrade all |
| `omni info PKG` | Show package info |
| `omni list` | Installed packages |

## Examples
1. Cross-distro install line in docs: `omni install ripgrep fd eza bat`
2. Full system upgrade: `omni upgrade`
3. Script-friendly search: `omni search --json rust`

## Gotchas
- Routes to whichever PM is detected first — force backend with `--backend pacman|apt|nix|…`.
- Not every distro ships omni; bootstrapping still uses the native PM.
