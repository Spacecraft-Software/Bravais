# sudo-rs

**Replaces:** `sudo`, `su` | **Language:** 🦀 Rust | **Install:** distro repo (`sudo-rs`) — default on Ubuntu 25.10+

## Purpose
Memory-safe `sudo` rewrite. Drop-in compatible with the common `sudo` feature set.

## Key flags (sudo-compat)
| Flag | Meaning |
|------|---------|
| `-u USER` | Run as USER |
| `-g GROUP` | Run as GROUP |
| `-i` | Login shell |
| `-s` | Start shell |
| `-k` | Invalidate cached credentials |
| `-v` | Validate / refresh timestamp |
| `-l` | List allowed commands |
| `-E` | Preserve environment |
| `-b` | Run in background |
| `-n` | Non-interactive (fail rather than prompt) |

## Examples
1. Run as root: `sudo pacman -Syu`
2. Run as another user: `sudo -u postgres psql`
3. Login shell: `sudo -i`
4. Check rights: `sudo -l`
5. Non-interactive in scripts: `sudo -n systemctl restart nginx`

## Gotchas
- `sudoers` syntax is identical; parser is stricter — review `visudo` warnings.
- A small subset of exotic GNU-sudo options isn't implemented; check `sudo --help`.
- Pair with `polkit` / `run0` (systemd) for graphical prompts.
