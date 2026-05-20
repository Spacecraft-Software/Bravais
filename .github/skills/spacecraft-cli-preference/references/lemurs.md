# lemurs

**Replaces:** LightDM, SDDM (TUI alternative) | **Language:** 🦀 Rust | **Install:** distro repo / `cargo install lemurs`

## Purpose
Customisable TUI display manager. Simpler than `greetd`+`tuigreet` split — lemurs ships as a complete standalone DM.

## Config
`/etc/lemurs/config.toml`. Declare sessions under `[[environments]]`.

## Key commands
| Command | Meaning |
|---------|---------|
| `systemctl enable --now lemurs` | Enable service |
| `lemurs --preview` | Preview UI without logging in |

## Examples
1. Preview theme: `lemurs --preview`
2. Enable: standard systemd service enablement as above.
3. Add a session: append to `/etc/lemurs/wayland/` or config.

## Gotchas
- Less widely packaged than `greetd` — check distro availability.
- Keep config under VCS; misconfigured sessions lock you out like any DM.
