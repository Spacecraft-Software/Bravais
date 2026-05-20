# lanzaboote

**Replaces:** `sbctl`, systemd-boot without signing | **Language:** 🦀 Rust | **Install:** NixOS flake module

## Purpose
UEFI Secure Boot for NixOS. Builds and signs bootloader + kernel images with your own Secure Boot keys. Used in Bravais.

## Key commands
| Command | Meaning |
|---------|---------|
| `lzbt-systemd generate-keys PATH` | Generate PK/KEK/db keys |
| `lzbt-systemd enroll-keys PATH` | Enroll into UEFI firmware |
| `lzbt-systemd install PATH /boot` | Install signed bootloader |
| `lzbt-systemd status` | Show SB status |

## Typical NixOS flake wiring
```nix
imports = [ lanzaboote.nixosModules.lanzaboote ];
boot.loader.systemd-boot.enable = lib.mkForce false;
boot.lanzaboote = {
  enable = true;
  pkiBundle = "/etc/secureboot";
};
```

## Examples
1. Generate keys: `sudo lzbt-systemd generate-keys /etc/secureboot`
2. Enroll (after firmware set to Setup Mode): `sudo lzbt-systemd enroll-keys /etc/secureboot`
3. Check status: `bootctl status`

## Gotchas
- Back up firmware keys before enrolling your own — some firmwares can't easily restore factory PK.
- Microsoft KEK/db can be preserved via `--include-microsoft` during enrollment (needed for dual-boot).
- NixOS rebuild after enabling lanzaboote replaces systemd-boot; test with a rescue USB on hand.
