# Copilot Instructions — Steelbore OS Bravais

Bravais is a flake-based NixOS distribution implementing the **Steelbore Standard**.
It ships a curated, modular, Rust-first system configuration for x86-64 Linux.

---

## Project Structure

```
bravais/
├── flake.nix                      # Entry point; mkBravais helper; 10 nixosConfigurations
├── flake.lock                     # Pinned inputs
├── lib/                           # Custom Nix helpers (color palette definitions)
├── hosts/bravais/                 # Machine-specific config
│   ├── default.nix                # Host traits & steelbore.* module toggles
│   └── hardware.nix               # Hardware scan output
├── modules/                       # NixOS modules under the steelbore.* namespace
│   ├── core/                      # Always-enabled: boot, nix, locale, audio, security, DNS
│   ├── theme/                     # Steelbore visual identity (color palette, fonts)
│   ├── hardware/                  # Opt-in: fingerprint, Intel CPU march profiles
│   ├── desktops/                  # Opt-in: GNOME, COSMIC, Niri, KDE Plasma, LeftWM
│   ├── login/                     # greetd + tuigreet display manager
│   └── packages/                  # Opt-in application bundles
│       ├── browsers.nix
│       ├── terminals.nix
│       ├── editors.nix
│       ├── development.nix        # Dev tools, languages, Rust toolchain
│       ├── security.nix
│       ├── networking.nix
│       ├── multimedia.nix
│       ├── productivity.nix
│       ├── system.nix             # Modern Unix, containers, shells
│       └── ai.nix                 # AI coding assistants
├── overlays/default.nix           # Custom package derivations
├── users/mj/                      # User "mj" (Home Manager)
│   ├── default.nix
│   └── home.nix
└── v0/                            # Archived v0-era configs (do not modify)
```

### Flake outputs

| Target | Channel | CPU |
|---|---|---|
| `bravais` / `bravais-v4` | stable 25.11 | AVX-512 (default) |
| `bravais-v1` … `bravais-v4` | stable 25.11 | x86-64-v1 … v4 |
| `bravais-unstable` / `bravais-unstable-v4` | nixos-unstable | AVX-512 |
| `bravais-unstable-v1` … `bravais-unstable-v4` | nixos-unstable | x86-64-v1 … v4 |

---

## Coding Conventions

### General

- **License header on every source file:** `# SPDX-License-Identifier: GPL-3.0-or-later`
- **Rust-first:** always prefer Rust packages over C/C++ equivalents. Annotate with
  `# Rust —` or `# Go —` comments in package lists.
- **Module namespace:** all custom options live under `steelbore.*`.
- **Opt-in modules:** every feature uses `lib.mkEnableOption` and is gated with
  `lib.mkIf config.steelbore.<path>.enable`.
- **No impure packages:** do not pin packages outside nixpkgs unless there is an
  explicit flake input for them.

### Nix style

- 2-space indentation.
- Trailing comma after the last element in attribute sets and lists.
- Align `=` in attribute sets when there are 3+ related keys.
- Comment pattern: `# Adjective — Short description` after each package in lists.
- `with pkgs;` is acceptable inside `environment.systemPackages` lists.
- Always add new packages to the appropriate `modules/packages/*.nix` file — not to
  `hosts/bravais/default.nix` or `flake.nix`.

### Commit style (Conventional Commits)

- Prefix: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`
- Subject ≤ 72 characters, imperative mood.
- Body wrapped at 72 columns; explain *why*, not *what*.
- Reference issues: `Closes #42`.
- Sign off: `git commit -s`.

### Identifier naming (Steelbore Standard §2)

New option names, module keys, and custom identifiers must follow the
aerospace / sci-fi / AI convention used throughout the codebase
(e.g., `steelbore`, `bravais`, `gitway`, `kimi-cli`).

---

## Build & Run

### Prerequisites

- Nix with flakes enabled (`nix.settings.experimental-features = ["nix-command" "flakes"]`)
- A NixOS host (or a VM) running NixOS 25.11 or nixos-unstable

### Validate (dry-run — safe, no system changes)

```sh
nix flake check
nixos-rebuild dry-build --flake .#bravais-unstable-v3 --show-trace
```

### Apply to the running system

```sh
# Stable (AVX-512):
sudo nixos-rebuild switch --flake .#bravais

# Unstable (AVX2, development default):
sudo nixos-rebuild switch --flake .#bravais-unstable-v3 --show-trace
```

### Update inputs

```sh
nix flake update            # update all inputs
nix flake update nixpkgs    # update a single input
```

---

## Test Framework

Bravais has no dedicated unit-test suite. Validation is performed by:

1. **`nix flake check`** — evaluates all flake outputs and catches Nix evaluation
   errors across all 10 nixosConfigurations.
2. **`nixos-rebuild dry-build`** — full NixOS configuration evaluation without
   building or activating; catches module option conflicts and missing packages.
3. **Manual activation** — `nixos-rebuild switch` on the target host.

Always run `nix flake check` before opening a PR. The CI workflow
(`.github/workflows/`) may also validate flake outputs automatically.

---

## Shell Environment

- **User shell (mj):** nushell + starship prompt
- **Root shell:** Brush (Rust, Bash-compatible)
- **Bash compatibility:** a `bash` wrapper re-dispatches to Brush for all users;
  NixOS internal activation scripts retain access to the real bash via its Nix
  store path.
- `programs.bash.enable` is intentionally `true` — required by NixOS activation
  scripts and PAM tooling. Users are not assigned bash as their login shell.

---

## Key Modules & Concepts

| Module | Purpose |
|---|---|
| `modules/core/security.nix` | sudo-rs (replaces sudo), polkit, gitway-agent |
| `modules/core/brush-wrapper.nix` | PATH-priority bash→Brush wrapper for all users |
| `modules/hardware/intel.nix` | x86-64 march level selection (v1–v4) |
| `modules/desktops/niri.nix` | The Steelbore Standard desktop |
| `modules/packages/development.nix` | Rust toolchain (gcc, rustup, cargo, rustfmt, clippy) |
| `overlays/default.nix` | sequoia-wot test-disable patch |

---

## Steelbore Color Palette

| Token | Hex | Role |
|---|---|---|
| Void Navy | `#000027` | Background / Canvas (mandatory on ALL surfaces) |
| Molten Amber | `#D98E32` | Primary text / active readout |
| Steel Blue | `#4B7EB0` | Primary accent / structural |
| Radium Green | `#50FA7B` | Success / safe status |
| Red Oxide | `#FF5C5C` | Warning / error |
| Liquid Coolant | `#8BE9FD` | Info / links |

---

## Skills

Copilot skills for this repository live in `.github/skills/` and are imported from
[Spacecraft-Software/Construct](https://github.com/Spacecraft-Software/Construct).

Available skills:

| File | Description |
|---|---|
| `rust-guidelines.skill` | Rust coding guidelines for Spacecraft Software projects |
| `spacecraft-agentic-cli.skill` | Agentic CLI conventions |
| `spacecraft-brand-guidelines.skill` | Brand & visual identity rules |
| `spacecraft-cli-preference.skill` | CLI tool preferences |
| `spacecraft-cli-shell.skill` | Shell usage conventions |
| `spacecraft-cli-standard.skill` | CLI standard patterns |
| `spacecraft-document-format.skill` | Document formatting conventions |
| `spacecraft-missing-pkg.skill` | Guidance for adding missing packages |
| `spacecraft-standard.skill` | Core Steelbore Standard reference |
| `spacecraft-theme-factory.skill` | Theme generation conventions |
