# Steelbore OS Bravais

Bravais is a meticulously crafted, flake-based NixOS configuration implementing the **Steelbore Standard**. Designed from the ground up to be modular, memory-safe, and visually cohesive, it provides a performant, reliable, and highly customizable system architecture for advanced computing workflows.

## Core Philosophy

The design of Bravais is guided by four primary tenets:

1. **Rust-First Ecosystem (Memory Safety):** Extreme priority is given to tools written in memory-safe languages. Bravais replaces legacy C-based utilities with robust Rust equivalents—ranging from core privilege escalation (`sudo-rs` completely replacing standard `sudo`) to terminal emulators, status bars (`ironbar`), and application launchers (`anyrun`, `onagre`).

2. **Opt-in Modularity:** Every feature, hardware profile, and application set is structurally siloed inside its own module using Nix's `lib.mkEnableOption`. Hosts boot only exactly what they explicitly declare via the `steelbore.*` namespace.

3. **The Steelbore Telemetry Palette:** Color is treated as telemetry, not just decoration. A single Standard §11 palette — *Steelbore Modern* by default, swappable for any member of the palette family — acts as a system-wide visual identity unifying the interface, extending from desktop environments down to TTY consoles.

4. **Self-Sufficient Configuration:** Built with determinism and reproducibility at the forefront. Features minimal external dependencies beyond `nixpkgs`, ensuring your host builds identically every time.

## Directory Structure

```
bravais/
├── flake.nix                      # Flake entry point (mkBravais helper; per-machine configs)
├── flake.lock                     # Pinned dependencies
├── lib/                           # Custom Nix helper functions
│   └── default.nix                # Color palette definitions
├── hosts/                         # One directory per physical machine
│   ├── common.nix                 # Shared host config (user, shells, toggles)
│   └── thinkpad/                  # ThinkPad (i7-8665U) — hostname + hw + march pin
│       ├── default.nix            # Machine traits (hostName, hardware toggles)
│       └── hardware.nix           # Generated hardware configuration
├── modules/                       # NixOS modules (steelbore.* namespace)
│   ├── core/                      # Always-enabled necessities
│   │   ├── default.nix            # Core module entry
│   │   ├── nix.nix                # Nix settings, flakes, overlays
│   │   ├── boot.nix               # Bootloader, XanMod kernel
│   │   ├── locale.nix             # Timezone (UTC), i18n
│   │   ├── audio.nix              # PipeWire audio stack
│   │   └── security.nix           # sudo-rs, polkit
│   ├── theme/                     # Steelbore visual identity
│   │   ├── default.nix            # Color palette, TTY colors
│   │   └── fonts.nix              # Typography (Orbitron, JetBrains Mono)
│   ├── hardware/                  # Hardware-specific modules
│   │   ├── default.nix            # Hardware module entry
│   │   ├── fingerprint.nix        # fprintd support
│   │   └── intel.nix              # Intel CPU optimizations (x86-64 v1/v2/v3/v4 profiles)
│   ├── desktops/                  # Desktop environments (opt-in)
│   │   ├── default.nix            # Desktop module entry
│   │   ├── gnome.nix              # GNOME on Wayland (de-bloated)
│   │   ├── cosmic.nix             # COSMIC DE on Wayland
│   │   ├── niri.nix               # Niri + Ironbar (The Steelbore Standard)
│   │   ├── plasma.nix             # KDE Plasma on Wayland/X11
│   │   └── leftwm.nix             # LeftWM + Polybar on X11
│   ├── login/                     # Display/login managers
│   │   └── default.nix            # greetd + tuigreet + shell sessions
│   └── packages/                  # Application bundles (opt-in)
│       ├── default.nix            # Package module entry
│       ├── browsers.nix           # Web browsers
│       ├── terminals.nix          # Terminal emulators (Steelbore themed, starship+nushell)
│       ├── editors.nix            # Text editors & IDEs
│       ├── development.nix        # Dev tools & languages
│       ├── security.nix           # Encryption & auth (Sequoia stack)
│       ├── networking.nix         # Network tools
│       ├── multimedia.nix         # Media players & processing
│       ├── productivity.nix       # Office & notes
│       ├── system.nix             # System utilities (modern Unix, Docker + Youki OCI)
│       └── ai.nix                 # AI coding assistants
├── users/                         # User profiles
│   └── mj/                        # User "mj"
│       ├── default.nix            # System-level user config
│       └── home.nix               # Home Manager configuration
├── pkgs/                          # In-tree packages (audio-led, claude-desktop, CRD, ollama)
└── v0/                            # Frozen v0-era configurations (archive)
```

## Color Palette

**Declared palette: `steelbore` (Steelbore Modern)** — the Standard §11 default.
Per §11.4 a project adopts exactly one palette and never mixes tokens across
palettes.

| §11.1 role    | Token          | Hex       | Use                             |
|---------------|----------------|-----------|---------------------------------|
| `background`  | Void Navy      | `#000027` | Canvas — every surface          |
| `surface`     | Quantum Blue   | `#0E2A47` | Elevated panels / cards         |
| `surface-alt` | Deep Matrix    | `#0B1A12` | Code blocks / terminal wells    |
| `foreground`  | Platinum Mist  | `#D9DEE5` | Body text / default readout     |
| `accent`      | Plasma Orange  | `#FF5E00` | Primary accent / active readout |
| `structure`   | Pulse Violet   | `#8A6CFF` | Structure / links / borders     |
| `success`     | Acid Lime      | `#B4FF00` | Success / safe status / focus   |
| `error`       | Mars Red       | `#FF3B3B` | Error status                    |
| `warning`     | Plasma Magenta | `#E445FF` | Warning / attention             |

**`#000027` (Void Navy) is the mandatory canvas under Steelbore Modern.**
Surface tokens are fills placed *on* the canvas, never replacements for it and
never text colors (§11.0.1) — Quantum Blue is only 1.40:1 against the canvas.

### Switching themes

Nothing in this repo names a brand color; every consumer reads a §11.1 role
token, so the whole system — all ~15 terminals, both bars, every WM, the TTY
console and greetd — follows one word in **`theme.nix`**:

```nix
{ active = "steelbore"; }   # -> steelbore-classic, tokyonight, …
```

```sh
theme list            # every theme, with color swatches
theme show tokyonight # its role table, hex and xterm-256 indices
theme set tokyonight  # rewrite theme.nix, then `rebuild`
theme try tokyonight  # build it WITHOUT touching theme.nix
```

`theme try` works because every theme also gets a buildable system of its own,
so any of them can be applied without a single file changing:

```sh
nix build .#themeSystems.x86_64-linux.tokyonight
```

These live under `themeSystems`, not `nixosConfigurations`, on purpose:
`nix flake check` force-evaluates every `nixosConfigurations` entry, and a full
system costs ~1.9 GB in the evaluator plus ~1.3 GB for each additional one held
alongside it. Fifteen of them needed ~23 GB and were OOM-killed. As a
non-standard output they stay lazy — the check skips them with a warning, and
you pay only for the theme you actually build. `theme try` therefore activates
the way `nixos-rebuild` does internally: point the system profile at the build,
then `switch-to-configuration switch`.

Registered palettes are read from the canonical `steelbore.toml` shipped by the
`construct` input, never retyped (§11.4): `steelbore`, `steelbore-classic`,
`steelbore-blue`, `steelbore-blackpinkpanther`, `steelbore-matrixgreen`,
`steelbore-navywhite`, `tokyonight`, plus a `<slug>-high-contrast` sibling of
each (§11.1.1).

### Local themes

`themes/<slug>.nix` adds a theme of your own — the filename is the slug. Either
derive from a registered palette and override tokens, or bind the roles outright:

```nix
{ base = "steelbore"; accent = "#FF8A3D"; }              # tweak one token
{ background = "#0B0B14"; foreground = "#E8E8F0"; … }    # fully custom
```

A local theme resolves through the same path as a registered one, so it inherits
role completion, the hue-derived ANSI mapping and xterm-256 handling for free.
Naming a file after a registered slug shadows it — the way to adjust Modern
everywhere without forking upstream. Unknown role names, malformed hex and
missing required roles are all rejected at eval time.

> A fully custom palette is outside the Standard's registered family and carries
> no verified contrast matrix (§11.4). Deriving from a `base` keeps the rest of a
> compliant palette, and its measured ratios, intact.

## Desktop Environments

Bravais officially provisions definitions for four primary desktop targets:

| Desktop | Protocol | Status Bar | Launcher | Description |
|---------|----------|------------|----------|-------------|
| **Niri** | Wayland | Ironbar | onagre/anyrun | *The Steelbore Standard* — Scrolling tiling compositor |
| **COSMIC** | Wayland | cosmic-panel | cosmic-launcher | System76's fully Rust-based desktop |
| **GNOME** | Wayland | GNOME Shell | GNOME | De-bloated GNOME with curated extensions |
| **LeftWM** | X11 | Polybar | rlaunch/rofi | High-performance Rust tiling fallback |

## Terminal Emulators

All terminals are themed with the Steelbore color palette and launch **nushell + starship** by default.

| Terminal | Stack | Notes |
|----------|-------|-------|
| Alacritty | Rust / GPU | Primary Rust-native terminal |
| WezTerm | Rust / GPU | Lua-configurable, full tab bar |
| Rio | Rust / GPU | Native GPU rendering |
| Ghostty | Zig / GPU | Memory-safe, fast |
| Warp | Rust / AI | AI-powered terminal |
| WaveTerm | Go / AI | AI-native terminal |
| COSMIC Term | Rust | COSMIC desktop terminal |
| Konsole | C++ / KDE | Steelbore colorscheme + profile |
| Yakuake | C++ / KDE | Drop-down terminal (Konsole backend) |
| Ptyxis | C / GNOME | VTE-based, GNOME integration |
| GNOME Console | C / GNOME | Minimal GNOME 4x terminal |
| Foot | C / Wayland | Lightweight Wayland terminal |
| XFCE4 Terminal | C / GTK | XFCE4 compatible |
| XTerm | C / X11 | Classic X11 fallback |
| Termius | — | SSH client |

## AppImage Support

Bravais provides **first-class, kernel-level AppImage support**. The `programs.appimage`
module (`modules/packages/system.nix`) is enabled with `binfmt = true`, registering a
`binfmt_misc` handler that transparently routes any `*.AppImage` through `appimage-run`
(an FHS environment supplying FUSE and the libraries AppImages expect). The result: you
simply mark an AppImage executable and run it directly — no wrapper command required.

```bash
chmod +x ~/Applications/SomeApp.AppImage
~/Applications/SomeApp.AppImage          # kernel routes it through appimage-run automatically
appimage-run ~/Applications/SomeApp.AppImage   # explicit fallback if binfmt doesn't catch it
```

**Conventions:**

- **Target directory.** Loose AppImages live in `~/Applications/` (e.g. `warp.appimage`,
  `waveterm-linux-x86_64-*.AppImage`). This is the canonical drop location for manually
  managed AppImages.
- **GUI manager.** [`AppImagePool`](https://github.com/prateekmedia/appimagepool) is
  provisioned via Flatpak (`io.github.prateekmedia.appimagepool`) for browsing, downloading,
  and updating AppImages with desktop-entry integration.
- **Preferred: package as a Nix derivation.** When you rely on an AppImage regularly, the
  Standard-aligned move is to wrap it reproducibly with `pkgs.appimageTools.wrapType2`
  (pinned `fetchurl` + SRI hash) inside the relevant `modules/packages/*.nix` bundle rather
  than leaving a loose binary in `~/Applications/`. **BrowserOS** (`modules/packages/browsers.nix`)
  is the reference example — it pins the upstream GitHub-release AppImage and builds a
  store-resident, march-aware wrapper. The package-manager priority (Guix → Nix → Cargo →
  Homebrew → Flatpak → Snap) still applies: reach for AppImage only when a tool isn't
  available higher up the chain.

## Per-machine configurations

`hosts/` holds one directory per physical machine. Shared host settings live in
`hosts/common.nix`; each `hosts/<machine>/` imports it plus its own generated
`hardware.nix` and pins the machine-specific bits: `networking.hostName` and the
`steelbore.hardware.*` toggles, **including the x86-64 march level**. The flake's
`mkBravais { host, channel ? "stable" }` then builds a stable + an unstable variant per
machine. Adding a machine = drop a `hosts/<machine>/` dir + two output lines in `flake.nix`.

| Configuration | Machine | Channel | March |
|---------------|---------|---------|-------|
| `bravais-thinkpad` | ThinkPad (i7-8665U, Whiskey Lake) | stable (26.05) | `v3` (AVX2; CPU has no AVX-512) |
| `bravais-thinkpad-unstable` | ThinkPad | unstable (rolling) | `v3` |
| `bravais` | alias → `bravais-thinkpad` (stable) | | |

The march level is the `marchLevel` option in `modules/hardware/intel.nix` (enum `v1`–`v4`).
Compiler flags are sourced from **CachyOS** (v1, v3, v4) and **ALHP** (v2 — the authoritative
v2 source, as CachyOS skips v2); all levels use `-mtune=native` and include
`pack-relative-relocs` in `RUSTFLAGS`. The four levels are SSE2 baseline (`v1`),
SSE4.2/POPCNT/CX16 (`v2`), AVX2/BMI1·2/FMA (`v3`), and AVX-512F/BW/CD/DQ/VL (`v4`).

All levels share: `-O3 -flto=auto -fuse-ld=gold -mpclmul` (v2+) and full security hardening
(`-D_FORTIFY_SOURCE=3`, `-fstack-clash-protection`, `-fcf-protection`, `-Clink-arg=pack-relative-relocs`).
`-fuse-ld=gold` is required on NixOS so GCC can resolve the LTO plugin path in `/nix/store`.

## Flake Inputs

| Input | Source | Purpose |
|-------|--------|---------|
| `nixpkgs` | nixos-25.11 stable | Core package set |
| `home-manager` | release-25.11 | Home Manager (follows `nixpkgs`) |
| `nixpkgs-unstable` | nixos-unstable (rolling) | Bleeding-edge package set |
| `home-manager-unstable` | main (rolling) | Home Manager (follows `nixpkgs-unstable`) |
| `nix-flatpak` | github:gmodena/nix-flatpak | Declarative Flatpak management |
| `gitway` | Spacecraft-Software/Gitway (tracks `main`) | Gitway SSH agent NixOS + HM modules |
| `kimi-cli` | MoonshotAI/kimi-cli (tracks `main`) | Kimi Code CLI agent |

## Host Configuration Pattern

Hosts toggle modules declaratively via the `steelbore.*` namespace:

```nix
{
  steelbore = {
    # Desktop environments
    desktops.gnome.enable = true;
    desktops.cosmic.enable = true;
    desktops.plasma.enable = true;
    desktops.niri.enable = true;
    desktops.leftwm.enable = true;

    # Hardware — set per-machine in hosts/<machine>/default.nix
    # (fingerprint, intel.enable, and intel.marchLevel are pinned there)
    hardware.fingerprint.enable = true;
    hardware.intel.enable = true;

    # Package bundles
    packages.browsers.enable = true;
    packages.terminals.enable = true;
    packages.editors.enable = true;
    packages.development.enable = true;
    packages.security.enable = true;
    packages.networking.enable = true;
    packages.multimedia.enable = true;
    packages.productivity.enable = true;
    packages.system.enable = true;
    packages.ai.enable = true;
    packages.flatpak.enable = true;
  };
}
```

## Project Posture

Bravais is a **personal hobby project** — see [`NOTICE.md`](./NOTICE.md) for the full
no-warranty / no-liability statement. Contributions are welcome but acceptance is at the
maintainer's discretion; see [`CONTRIBUTING.md`](./CONTRIBUTING.md).

## Quick Start

```bash
# Check the configuration validation
nix flake check

# Show all flake outputs (includes all CPU profiles)
nix flake show

# Dry-run build
nixos-rebuild dry-build --flake .#bravais

# Build without switching
nixos-rebuild build --flake .#bravais

# Switch to new configuration (default alias → stable ThinkPad)
sudo nixos-rebuild switch --flake .#bravais

# ThinkPad (stable 26.05, x86-64-v3)
sudo nixos-rebuild switch --flake .#bravais-thinkpad

# ThinkPad on the unstable channel (bleeding-edge packages)
sudo nixos-rebuild switch --flake .#bravais-thinkpad-unstable
```

## Documentation

- [PRD.md](./PRD.md) — Product Requirements Document and module specifications
- [ARCHITECTURE.md](./ARCHITECTURE.md) — System architecture and data-flow diagrams
- [TODO.md](./TODO.md) — Implementation task tracking

## Package Statistics

| Category | Rust-First | Other | Total |
|----------|------------|-------|-------|
| System Utilities | 47 | 21 | 68 |
| Networking | 12 | 8 | 20 |
| Development | 10 | 8 | 18 |
| Multimedia | 12 | 3 | 15 |
| Terminals | 5 | 10 | 15 |
| Editors | 6 | 9 | 15 |
| Security | 9 | 4 | 13 |
| Productivity | 4 | 5 | 9 |
| AI | 2 | 5 | 7 |
| Browsers | 0 | 5 | 5 |
| **Total** | **107** | **78** | **185** |

## Maintainer

Mohamed Hammad &lt;Mohamed.Hammad@SpacecraftSoftware.org&gt;
Copyright (c) 2026 Mohamed Hammad | License: GPL-3.0-or-later
https://Bravais.SpacecraftSoftware.org/

---
*Bravais (A Steelbore OS NixOS Distribution)* | *Version 2.0*
