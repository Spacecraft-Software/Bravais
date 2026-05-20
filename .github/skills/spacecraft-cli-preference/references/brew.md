# brew

**Replaces:** — (cross-platform fallback) | **Language:** ⚠️ Ruby | **Install:** https://brew.sh

## Purpose
Homebrew: macOS and Linux package manager. Cross-platform fallback when a tool isn't in your distro's repos.

## Key commands
| Command | Meaning |
|---------|---------|
| `brew update` | Refresh tap metadata |
| `brew upgrade [PKG]` | Upgrade all / one |
| `brew install PKG` | Install |
| `brew uninstall PKG` | Remove |
| `brew search QUERY` | Search |
| `brew info PKG` | Details |
| `brew list` | Installed |
| `brew doctor` | Diagnose install |
| `brew bundle dump` | Export installed set |
| `brew bundle` | Install from Brewfile |

## Examples
1. Install multiple: `brew install eza bat fd ripgrep jaq`
2. Export current setup: `brew bundle dump --file ~/Brewfile`
3. Reinstall on a new machine: `brew bundle --file ~/Brewfile`

## Gotchas
- On Linux, paths live under `/home/linuxbrew/.linuxbrew` by default.
- Casks (`brew install --cask`) only work on macOS.
