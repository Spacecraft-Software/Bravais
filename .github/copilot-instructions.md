# Copilot Instructions — Steelbore OS Bravais

Bravais is a flake-based NixOS distribution implementing the **Steelbore Standard**.
It ships a curated, modular, Rust-first system configuration for x86-64 Linux.

---

## Project Structure

```
bravais/
├── flake.nix                      # Entry point; mkBravais helper; per-machine nixosConfigurations
├── flake.lock                     # Pinned inputs
├── lib/                           # Custom Nix helpers (color palette definitions)
├── hosts/                         # One directory per physical machine
│   ├── common.nix                 # Shared host traits & steelbore.* module toggles
│   └── thinkpad/                  # ThinkPad (i7-8665U): hostname + hardware + march pin
│       ├── default.nix            # Machine traits (hostName, steelbore.hardware.*)
│       └── hardware.nix           # Hardware scan output
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
├── pkgs/                          # In-tree packages (audio-led, claude-desktop, CRD, ollama)
├── users/mj/                      # User "mj" (Home Manager)
│   ├── default.nix
│   └── home.nix
└── v0/                            # Archived v0-era configs (do not modify)
```

### Flake outputs

| Target | Machine | Channel | CPU |
|---|---|---|---|
| `bravais-thinkpad` | ThinkPad (i7-8665U) | stable 26.05 | x86-64-v3 (pinned; no AVX-512) |
| `bravais-thinkpad-unstable` | ThinkPad | nixos-unstable | x86-64-v3 |
| `bravais` (alias) | → `bravais-thinkpad` | stable 26.05 | x86-64-v3 |

March level is pinned per-machine in `hosts/<machine>/default.nix`
(`steelbore.hardware.intel.marchLevel`), not chosen per flake target.

---

## Coding Conventions

### General

<!-- REUSE-IgnoreStart -->
- **License header on every source file:** `# SPDX-License-Identifier: GPL-3.0-or-later`
<!-- REUSE-IgnoreEnd -->
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
  `hosts/common.nix`, a `hosts/<machine>/` config, or `flake.nix`.

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
nixos-rebuild dry-build --flake .#bravais-thinkpad --show-trace
```

### Apply to the running system

```sh
# ThinkPad (stable 26.05, x86-64-v3):
sudo nixos-rebuild switch --flake .#bravais-thinkpad

# ThinkPad on the unstable channel:
sudo nixos-rebuild switch --flake .#bravais-thinkpad-unstable --show-trace
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
   errors across every per-machine nixosConfiguration.
2. **`nixos-rebuild dry-build`** — full NixOS configuration evaluation without
   building or activating; catches module option conflicts and missing packages.
3. **Manual activation** — `nixos-rebuild switch` on the target host.

Always run `nix flake check` before opening a PR. The CI workflow
(`.github/workflows/`) may also validate flake outputs automatically.

---

## Shell Environment

- **User shell (mj):** nushell + starship prompt
- **Root shell:** Brush (Rust, Bash-compatible)
- **Bash compatibility:** bash stays installed and `programs.bash.enable`
  remains true (NixOS PAM/activation scripts require it), but bash is not a
  login shell. (An earlier bash→Brush PATH wrapper was abandoned; no such
  wrapper exists.)
- `programs.bash.enable` is intentionally `true` — required by NixOS activation
  scripts and PAM tooling. Users are not assigned bash as their login shell.

---

## Key Modules & Concepts

| Module | Purpose |
|---|---|
| `modules/core/security.nix` | sudo-rs (replaces sudo), polkit, gitway-agent |
| `modules/hardware/intel.nix` | Intel vendor bits (kvm-intel, microcode); march levels live in `modules/platform/x86-64.nix` |
| `modules/desktops/niri.nix` | The Steelbore Standard desktop |
| `modules/packages/development.nix` | Rust toolchain (gcc, rustup, cargo, rustfmt, clippy) |
| `modules/core/nix.nix` (inline overlays) | sequoia-wot test-disable patch |

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

Copilot skills for this repository live in `.github/skills/`. They are a
**vendored mirror** of [Spacecraft-Software/Construct](https://github.com/Spacecraft-Software/Construct),
pinned to the `construct` rev in `flake.lock` — the same rev Home Manager
installs into `~/.agents/skills/`, so the cloud agent and the local agents read
byte-identical skills.

**Never hand-edit a file under `.github/skills/`.** It is generated output: the
next sync silently reverts it. Change the skill in Construct instead, then
re-vendor here.

```sh
nu pkgs/sync-skills.nu           # re-vendor from the rev pinned in flake.lock
nu pkgs/sync-skills.nu --check   # report drift only — this is what CI runs
```

The `Skills Drift` workflow fails the build when the vendored tree stops
matching the pinned rev, so a stale copy cannot land. `pkgs/sync-skills.nu`
holds the authoritative skill list; the table below tracks it.

| Skill | Applies to |
|---|---|
| `microsoft-rust-guidelines` | Rust in `pkgs/steelbore-audio-led/`, `bravais-mcp/` (upstream Microsoft, dual GPL/MIT) |
| `spacecraft-agentic-cli` | `AGENTS.md` / `CLAUDE.md` authoring, agent-facing docs |
| `spacecraft-brand-guidelines` | Void Navy / Molten Amber identity, brand assets |
| `spacecraft-cli-preference` | Tool substitutions — `rg` over `grep`, `eza` over `ls` |
| `spacecraft-cli-shell` | Nushell vs POSIX syntax (user shell is Nushell) |
| `spacecraft-cli-standard` | Dual-mode self-documenting CLI patterns |
| `spacecraft-document-format` | Document deliverables |
| `spacecraft-missing-pkg` | Packaging a dependency nixpkgs does not ship |
| `spacecraft-nix-guidelines` | Every `.nix` file here — modules, flakes, derivations |
| `spacecraft-nu-guidelines` | `users/mj/shell.nix` Nushell defs, `pkgs/*.nu` scripts |
| `spacecraft-rust-guidelines` | House Rust style; pairs with the Microsoft set |
| `spacecraft-steelbore-standard` | The Steelbore Standard itself |
| `spacecraft-theme-factory` | `lib/terminal-theme.nix` emitters, per-app theming |
