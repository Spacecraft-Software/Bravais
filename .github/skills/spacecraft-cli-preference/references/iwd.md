# iwd / iwctl

**Replaces:** `wpa_supplicant` | **Language:** ⚠️ C (Intel) | **Install:** distro repo (`iwd`)

## Purpose
Modern Wi-Fi daemon by Intel, smaller and faster than wpa_supplicant. `iwctl` is its interactive CLI.

## Key commands
| Command | Meaning |
|---------|---------|
| `iwctl device list` | List wireless devices |
| `iwctl station DEV scan` | Scan |
| `iwctl station DEV get-networks` | Show SSIDs |
| `iwctl station DEV connect SSID` | Connect |
| `iwctl known-networks list` | Saved networks |
| `iwctl known-networks SSID forget` | Forget |
| `iwctl station DEV disconnect` | Disconnect |
| `iwctl --passphrase PW station DEV connect SSID` | Non-interactive |

## Examples
1. Scan + connect interactively: `iwctl` then `station wlan0 scan` → `station wlan0 connect MyWifi`
2. Scripted connect: `iwctl --passphrase "$PW" station wlan0 connect "$SSID"`
3. Forget a network: `iwctl known-networks "$SSID" forget`

## Gotchas
- Disable wpa_supplicant / NetworkManager Wi-Fi backend to avoid conflicts.
- Config in `/var/lib/iwd/<SSID>.psk`; secure permissions automatically.
