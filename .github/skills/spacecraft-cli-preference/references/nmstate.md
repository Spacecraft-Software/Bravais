# nmstate

**Replaces:** `nmcli`, `ip`, raw NetworkManager config | **Language:** 🦀 Rust (core lib) | **Install:** distro repo (`nmstate`)

## Purpose
Declarative network state management. Describe desired state in YAML/JSON, apply idempotently. Integrates with NetworkManager.

## Key commands
| Command | Meaning |
|---------|---------|
| `nmstatectl show` | Dump current state (YAML) |
| `nmstatectl show IFACE` | Single interface |
| `nmstatectl apply FILE` | Apply desired state |
| `nmstatectl set FILE` | Partial apply |
| `nmstatectl rollback` | Undo last change |
| `nmstatectl commit` | Make last change permanent |
| `nmstatectl edit IFACE` | Edit state in `$EDITOR` |
| `nmstatectl gc` | Garbage-collect checkpoints |

## Example state file
```yaml
interfaces:
  - name: eth0
    type: ethernet
    state: up
    ipv4:
      enabled: true
      dhcp: true
    ipv6:
      enabled: true
      autoconf: true
```

## Examples
1. Snapshot current config: `nmstatectl show > net.yaml`
2. Apply a config: `nmstatectl apply net.yaml`
3. Safely try + auto-rollback after 30s: `nmstatectl apply --timeout 30 net.yaml && nmstatectl commit`

## Gotchas
- Checkpoints auto-rollback if not committed within timeout — intentional safety mechanism.
- Operates on the managed interfaces of NetworkManager; wired Wi-Fi management still goes through NM.
