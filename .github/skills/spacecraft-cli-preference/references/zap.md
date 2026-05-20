# zap

**Replaces:** `appimaged`, `am` | **Language:** 🦀 Rust | **Install:** GitHub release

## Purpose
High-performance AppImage manager: install, update, integrate (desktop entries + icons), remove.

## Key commands
| Command | Meaning |
|---------|---------|
| `zap install NAME` | Install an AppImage from GitHub/custom URL |
| `zap list` | List installed |
| `zap update` | Check/update all |
| `zap remove NAME` | Remove |
| `zap search QUERY` | Search catalog |
| `zap daemon` | Background update service |

## Examples
1. Install an AppImage by name: `zap install appimagelauncher`
2. Install from a direct URL: `zap install --from https://example.com/app.AppImage my-app`
3. Update all: `zap update`
4. Uninstall: `zap remove my-app`

## Gotchas
- AppImage integration requires XDG directories under `~/.local/share/applications/`.
- No sandboxing by default — treat AppImages as equivalent-trust to distro packages.
