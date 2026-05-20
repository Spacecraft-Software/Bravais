# AdGuard VPN CLI

**Replaces:** manual VPN dial-up | **Language:** 🐹 Go | **Install:** AdGuard official installer

## Purpose
Command-line client for AdGuard VPN. Manage connection, protocols, DNS, split-tunnel.

## Key commands
| Command | Meaning |
|---------|---------|
| `adguardvpn-cli login` | Authenticate |
| `adguardvpn-cli connect` | Connect (interactive location picker) |
| `adguardvpn-cli connect -l LOC` | Connect to location |
| `adguardvpn-cli disconnect` | Disconnect |
| `adguardvpn-cli status` | Status |
| `adguardvpn-cli list-locations` | Available servers |
| `adguardvpn-cli config set-mode` | `tun` / `socks` |
| `adguardvpn-cli site-exclusions` | Split-tunnel list |

## Examples
1. Login and connect to a specific server: `adguardvpn-cli login && adguardvpn-cli connect -l gb-london`
2. Check status: `adguardvpn-cli status`
3. Systemd-managed: create a unit that runs `adguardvpn-cli connect -l fastest`

## Gotchas
- `tun` mode needs root/capability; `socks` mode is per-app.
- Login stores credentials in plaintext config on older versions — check file permissions.
