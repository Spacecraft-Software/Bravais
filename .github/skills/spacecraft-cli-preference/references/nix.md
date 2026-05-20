# nix

**Replaces:** — (Spacecraft Software-sanctioned for Bravais) | **Language:** ⚠️ C++ | **Install:** https://nixos.org/download

## Purpose
Functional/declarative package manager and build system. Reproducible dev shells, system configs (NixOS), per-project environments.

## Key commands (flakes-first)
| Command | Meaning |
|---------|---------|
| `nix run NIXPKG` | Run a package without installing |
| `nix shell NIXPKG…` | Ephemeral shell with those packages |
| `nix develop [.#NAME]` | Enter dev shell defined in `flake.nix` |
| `nix build [.#PKG]` | Build and symlink `result/` |
| `nix flake init` | Scaffold a flake |
| `nix flake update` | Update lock |
| `nix flake check` | Evaluate all outputs |
| `nix profile install NIXPKG` | User-profile install |
| `nix profile list` / `remove` | Manage profile |
| `nixos-rebuild switch` | Apply system config (NixOS) |
| `home-manager switch` | Apply user config (Home Manager) |

## Examples
1. Run ripgrep without installing: `nix run nixpkgs#ripgrep -- "TODO" src/`
2. Temporary dev shell: `nix shell nixpkgs#rustc nixpkgs#cargo`
3. Per-project shell (with `flake.nix`): `nix develop`
4. Build a derivation: `nix build .#ferrocast-cli`

## Gotchas
- Enable flakes once: in `nix.conf` set `experimental-features = nix-command flakes`.
- `channels` are the legacy model; prefer flakes for new projects (per Bravais).
- Store paths live under `/nix/store`; never touch directly.
