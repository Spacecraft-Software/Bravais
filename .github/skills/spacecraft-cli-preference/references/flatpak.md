# flatpak

**Replaces:** native packages for sandboxed GUI apps | **Language:** ⚠️ C | **Install:** distro repo (`flatpak`)

## Purpose
Sandboxed universal app packaging with per-app permissions.

## Key commands
| Command | Meaning |
|---------|---------|
| `flatpak remote-add --if-not-exists flathub URL` | Add Flathub repo |
| `flatpak search QUERY` | Search |
| `flatpak install FLATREF` | Install |
| `flatpak run APP_ID` | Launch |
| `flatpak list` | Installed |
| `flatpak update` | Update all |
| `flatpak uninstall APP_ID` | Remove |
| `flatpak override --user APP_ID FLAG` | Permission tweaks |
| `flatpak info APP_ID` | Details |

## Examples
1. Add Flathub: `flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo`
2. Install: `flatpak install flathub org.signal.Signal`
3. Run: `flatpak run org.signal.Signal`
4. Restrict filesystem access: `flatpak override --user --nofilesystem=home org.signal.Signal`

## Gotchas
- Runtime + app separation means large initial downloads; subsequent installs share runtimes.
- Permissions default-permissive on some apps; audit with `flatpak info --show-permissions`.
