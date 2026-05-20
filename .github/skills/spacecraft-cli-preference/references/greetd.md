# greetd

**Replaces:** `getty` + `agetty`, LightDM/SDDM (minimal alternative) | **Language:** 🦀 Rust | **Install:** distro repo (`greetd`)

## Purpose
Minimal, generic login daemon that delegates the UI to a separate greeter (e.g. `tuigreet`, `gtkgreet`, `regreet`).

## Config
`/etc/greetd/config.toml`:
```toml
[terminal]
vt = 1

[default_session]
command = "tuigreet --cmd niri-session"
user = "greeter"
```

## Key commands
| Command | Meaning |
|---------|---------|
| `systemctl enable --now greetd` | Enable service |
| `journalctl -u greetd` | Logs |

## Examples
1. Enable on NixOS (Bravais): `services.greetd.enable = true;` + greeter settings.
2. Switch greeter: edit `default_session.command`, then restart service.
3. Debug session-start issues: `journalctl -u greetd -b`.

## Gotchas
- Mis-configured `command =` leaves you stuck at VT1 with no login — always keep another TTY open.
- The greeter user must exist (distro packages create it; NixOS handles it via the module).
