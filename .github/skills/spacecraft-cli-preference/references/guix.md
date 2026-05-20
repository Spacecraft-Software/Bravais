# guix

**Replaces:** — (alternative declarative PM) | **Language:** (λ) Guile Scheme | **Install:** https://guix.gnu.org/

## Purpose
Functional/declarative package manager and (optional) distro. Transactional upgrades, rollbacks, per-user profiles. Alternative to Nix with a Scheme-based language.

## Key commands
| Command | Meaning |
|---------|---------|
| `guix install PKG` | User install |
| `guix remove PKG` | Uninstall |
| `guix upgrade` | Upgrade all |
| `guix search QUERY` | Search |
| `guix show PKG` | Info |
| `guix pull` | Update Guix itself |
| `guix shell PKG…` | Ephemeral shell |
| `guix environment --container` | Isolated env |
| `guix package --roll-back` | Revert last profile change |
| `guix system reconfigure FILE` | Apply system config (Guix System) |

## Examples
1. Ephemeral dev shell: `guix shell rust cargo`
2. Roll back a bad upgrade: `guix package --roll-back`
3. Update Guix itself: `guix pull && guix upgrade`

## Gotchas
- Manifests are Scheme expressions — syntax is stricter than Nix's.
- Free-software-only by policy; proprietary drivers need the `nonguix` channel.
