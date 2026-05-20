# am (AppMan)

**Replaces:** manual AppImage management | **Language:** ⚠️ Bash | **Install:** upstream install script

## Purpose
Bash-based AppImage manager. Lightweight, no daemon, extensive catalog. Secondary choice after `zap`.

## Key commands
| Command | Meaning |
|---------|---------|
| `am -i PKG` | Install |
| `am -u` | Update all |
| `am -r PKG` | Remove |
| `am -q QUERY` | Search |
| `am -l` | List installed |
| `am -a` / `--about PKG` | About |

## Examples
1. Install: `am -i librewolf`
2. Update everything: `am -u`

## Gotchas
- Bash-only — edit scripts in `$AM_INSTALLDIR` to debug.
- AppImages install under `~/.local/bin` by default.
