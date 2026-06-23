# Bravais -- Product Requirements Document

**Project:** Bravais (A Steelbore OS NixOS Distribution)
**Version:** 3.1 | **Date:** 2026-04-20
**Author:** Mohamed Hammad | **License:** GPL-3.0-or-later
**Status:** Implemented

---

## 1. Executive Summary

Bravais is a flake-based NixOS configuration implementing the Spacecraft Software Standard. It delivers a complete, reproducible system with a modular, opt-in architecture supporting five desktop environments: GNOME (Wayland), COSMIC (Wayland), KDE Plasma 6 (Wayland), Niri (Wayland), and LeftWM (X11).

**Core Principles:**

- Memory-safe tooling preferred (Rust-first ecosystem)
- Opt-in modularity via `lib.mkEnableOption` in the `spacecraft.*` namespace
- Steelbore Color Palette applied universally to all visual surfaces
- Self-sufficient flake configuration (no external dependencies beyond nixpkgs, home-manager, nix-flatpak, and gitway)
- Dual-channel support (stable nixos-26.05 / unstable rolling) with four x86-64 microarchitecture profiles (v1-v4)
- 14+ terminal emulators, all themed with the Steelbore palette
- Declarative Flatpak management via nix-flatpak
- Podman (not Docker) with runc as default runtime and Youki (Rust) available
- Nushell (Rust) as default user shell; Brush (Rust, Bash-compatible) as root shell; Bash disabled as login shell

---

## 2. Architecture Overview

### 2.1 Directory Structure

```text
bravais/
+-- flake.nix                      # Flake entry point
+-- flake.lock                     # Pinned dependencies
+-- lib/                           # Custom Nix helper functions
|   +-- default.nix                # mkSpacecraftModule, color palette
+-- hosts/                         # Machine-specific configurations
|   +-- bravais/                   # Primary host
|       +-- default.nix            # Host traits (boot, locale, user, toggles)
|       +-- hardware.nix           # Hardware configuration (generated)
+-- modules/                       # NixOS modules (spacecraft.* namespace)
|   +-- core/                      # Always-enabled necessities
|   |   +-- default.nix            # Core module entry
|   |   +-- nix.nix                # Nix settings, flakes, overlays
|   |   +-- boot.nix               # Bootloader, kernel
|   |   +-- locale.nix             # Timezone, i18n
|   |   +-- audio.nix              # PipeWire audio stack
|   |   +-- security.nix           # sudo-rs, polkit, SSH agent
|   |   +-- dns.nix                # systemd-resolved + DoT + DNSSEC (Cloudflare malware-block)
|   +-- theme/                     # Steelbore visual identity
|   |   +-- default.nix            # Color palette env vars, TTY colors
|   |   +-- fonts.nix              # Typography (system fonts)
|   +-- hardware/                  # Hardware-specific modules
|   |   +-- default.nix            # Hardware module entry
|   |   +-- fingerprint.nix        # fprintd
|   |   +-- intel.nix              # Intel CPU optimizations (v1-v4 march levels)
|   +-- desktops/                  # Desktop environments (opt-in)
|   |   +-- default.nix            # Desktop module entry
|   |   +-- gnome.nix              # GNOME on Wayland
|   |   +-- cosmic.nix             # COSMIC DE on Wayland
|   |   +-- plasma.nix             # KDE Plasma 6 on Wayland
|   |   +-- niri.nix               # Niri + Ironbar on Wayland
|   |   +-- leftwm.nix             # LeftWM + Polybar on X11
|   +-- login/                     # Display/login managers
|   |   +-- default.nix            # greetd + tuigreet + shell sessions
|   +-- packages/                  # Application bundles (opt-in)
|       +-- default.nix            # Package module entry
|       +-- browsers.nix           # Web browsers
|       +-- terminals.nix          # Terminal emulators (14+, all themed)
|       +-- editors.nix            # Text editors & IDEs
|       +-- development.nix        # Dev tools & languages
|       +-- security.nix           # Encryption & auth
|       +-- networking.nix         # Network tools
|       +-- multimedia.nix         # Media players & processing
|       +-- productivity.nix       # Office & notes
|       +-- system.nix             # System utilities & containers
|       +-- ai.nix                 # AI coding assistants
|       +-- flatpak.nix            # Declarative Flatpak apps
|       +-- homebrew.nix           # Linuxbrew via FHS env (escape hatch)
+-- users/                         # User profiles
|   +-- mj/                        # User "mj"
|       +-- default.nix            # System-level user config
|       +-- home.nix               # Home Manager configuration
+-- overlays/                      # Package overlays
    +-- default.nix                # sequoia-wot fix (doCheck = false)
```

### 2.2 Module Design Pattern

All modules use the `spacecraft.*` namespace with `lib.mkEnableOption`:

```nix
{ config, lib, pkgs, ... }:
{
  options.spacecraft.desktops.niri = {
    enable = lib.mkEnableOption "Niri scrolling tiling compositor (Wayland)";
  };

  config = lib.mkIf config.spacecraft.desktops.niri.enable {
    # Module implementation
  };
}
```

A `mkSpacecraftModule` helper is available in `lib/default.nix` to reduce boilerplate.

### 2.3 Host Configuration Pattern

The host toggles modules declaratively:

```nix
spacecraft = {
  desktops.gnome.enable = true;
  desktops.cosmic.enable = true;
  desktops.plasma.enable = true;
  desktops.niri.enable = true;
  desktops.leftwm.enable = true;

  hardware.fingerprint.enable = true;
  hardware.intel.enable = true;

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
  packages.homebrew.enable = true;
};
```

### 2.4 Dual-Channel Design

Bravais supports two nixpkgs channels, selectable per build:

| Channel    | nixpkgs Branch    | Home Manager Branch | Stability |
|------------|-------------------|---------------------|-----------|
| `stable`   | `nixos-26.05`     | `release-26.05`     | Tested    |
| `unstable` | `nixos-unstable`  | Latest              | Rolling   |

### 2.5 Microarchitecture Profiles

`nixosConfigurations` are generated **per physical machine** (stable + unstable each).
The x86-64 march level is pinned in each machine's host config, not exploded into a matrix:

| Configuration               | Machine                            | Channel  | March                          |
|-----------------------------|------------------------------------|----------|--------------------------------|
| `bravais-thinkpad`          | ThinkPad (i7-8665U, Whiskey Lake)  | stable   | v3 (AVX2; CPU has no AVX-512)  |
| `bravais-thinkpad-unstable` | ThinkPad                           | unstable | v3                             |
| `bravais` (alias)           | → `bravais-thinkpad` (stable)      | stable   | v3                             |

Adding a machine = drop a `hosts/<machine>/` directory + two output lines in `flake.nix`.
Shared host settings live in `hosts/common.nix`; each `hosts/<machine>/` imports it plus its
own `hardware.nix` and pins `networking.hostName` + `steelbore.hardware.*` (incl.
`intel.marchLevel`).

---

## 3. Flake Configuration

### 3.1 Inputs

| Input                    | URL                                                    | Follows        |
|--------------------------|--------------------------------------------------------|----------------|
| `nixpkgs`                | `github:nixos/nixpkgs/nixos-26.05`                    | --             |
| `home-manager`           | `github:nix-community/home-manager/release-26.05`     | `nixpkgs`      |
| `nixpkgs-unstable`       | `github:nixos/nixpkgs/nixos-unstable`                 | --             |
| `home-manager-unstable`  | `github:nix-community/home-manager`                   | `nixpkgs-unstable` |
| `nix-flatpak`            | `github:gmodena/nix-flatpak`                          | --             |
| `gitway`                 | `github:Spacecraft-Software/Gitway` (tracks `main`)             | `nixpkgs-unstable` |

### 3.2 Steelbore Color Palette Definition

Defined in `flake.nix` and passed as `specialArgs` to all modules:

```nix
spacecraftPalette = {
  voidNavy    = "#000027";
  moltenAmber = "#D98E32";
  steelBlue   = "#4B7EB0";
  radiumGreen = "#50FA7B";
  redOxide    = "#FF5C5C";
  liquidCool  = "#8BE9FD";
};
```

### 3.3 mkBravais Function

```nix
mkBravais = { host, channel ? "stable" }: ...
```

- `host` is a machine path from the `hosts` map in `flake.nix` (e.g. `./hosts/thinkpad`)
- Selects nixpkgs and home-manager inputs based on `channel`
- Passes `specialArgs = { inherit spacecraftPalette gitway; }`
- Loads modules in order: external (home-manager, nix-flatpak), then `host`, core, theme, hardware, desktops, login, packages
- The march level is **not** a parameter — it is pinned inside the host config via `steelbore.hardware.intel.marchLevel`
- Configures Home Manager: `useGlobalPkgs = true`, `useUserPackages = true`, `backupFileExtension = "backup"`, passes `spacecraftPalette` via `extraSpecialArgs`

### 3.4 Overlays

Defined inline in `modules/core/nix.nix` via `nixpkgs.overlays`. A reference copy exists in `overlays/default.nix`.

**sequoia-wot:** Disables failing tests (`doCheck = false`).

**claude-code:** Pinned to latest npm release (2.1.113) via `overrideAttrs` overlay. Overrides `version`, `src` (built via `runCommand` to bake `overlays/claude-code-package-lock.json` into the source tree), `npmDepsHash`, and `npmDeps` (explicit `fetchNpmDeps` call — `overrideAttrs` does not propagate `src`/`npmDepsHash` into the internal `fetchNpmDeps`). Since ~2.1.113, claude-code ships a native binary via optional dependency `@anthropic-ai/claude-code-linux-x64`; `bin/claude.exe` is a placeholder replaced at install time. Because `buildNpmPackage` does not run `postinstall`, the overlay's `postInstall` copies the native binary from `node_modules` over the placeholder and relinks `$out/bin/claude`. `autoPatchelfHook` patches the ELF interpreter/RPATHs for NixOS, with `autoPatchelfIgnoreMissingDeps = [ "libc.musl-x86_64.so.1" ]` so the unused musl variant doesn't fail the build. This bypasses the lag between npm releases and nixpkgs packaging.

**bash→brush (not implemented):** Replacing `pkgs.bash` via a nixpkgs overlay is architecturally infeasible — every nixpkgs derivation uses `final.bash` as its build shell via stdenv, creating an unavoidable bootstrapping cycle. Bash is excluded from all login shell assignments; users get Nushell and root gets Brush.

---

## 4. Steelbore Visual Identity

### 4.1 Color Palette

| Token          | Hex       | RGB                | Role                           |
|----------------|-----------|--------------------|--------------------------------|
| Void Navy      | `#000027` | RGB(000, 000, 039) | Background / Canvas            |
| Molten Amber   | `#D98E32` | RGB(217, 142, 050) | Primary Text / Active Readout  |
| Steel Blue     | `#4B7EB0` | RGB(075, 126, 176) | Primary Accent / Structural    |
| Radium Green   | `#50FA7B` | RGB(080, 250, 123) | Success / Safe Status          |
| Red Oxide      | `#FF5C5C` | RGB(255, 092, 092) | Warning / Error Status         |
| Liquid Coolant | `#8BE9FD` | RGB(139, 233, 253) | Info / Links                   |

**`#000027` (Void Navy) is the mandatory background for ALL Steelbore surfaces.**

### 4.2 16-Color Terminal Palette Mapping

| Index | Role           | Normal Token   | Bright Token   |
|-------|----------------|----------------|----------------|
| 0     | Black          | Void Navy      | Steel Blue     |
| 1     | Red            | Red Oxide      | Red Oxide      |
| 2     | Green          | Radium Green   | Radium Green   |
| 3     | Yellow         | Molten Amber   | Molten Amber   |
| 4     | Blue           | Steel Blue     | Liquid Coolant |
| 5     | Magenta        | Steel Blue     | Liquid Coolant |
| 6     | Cyan           | Liquid Coolant | Liquid Coolant |
| 7     | White          | Molten Amber   | Molten Amber   |

### 4.3 Typography

Two font roles, both defined in `modules/theme/fonts.nix` (source of truth).
**To change a font, follow the "Changing fonts" runbook in `CLAUDE.md`** — the
family string is repeated across ~15 terminal configs and the exact Nerd Font
family name must be read from the package, not guessed.

| Role                | Font                  | License | Fallback             |
|---------------------|-----------------------|---------|----------------------|
| Main / UI (sans+serif) | Hack Nerd Font     | MIT     | —                    |
| Terminal / code (mono) | JetBrainsMono Nerd Font | OFL | CaskaydiaMono Nerd Font |
| Icon glyph fallback | Symbols Nerd Font Mono | MIT    | —                    |

**Font packages installed:** `nerd-fonts.hack`, `nerd-fonts.jetbrains-mono`, `nerd-fonts.caskaydia-mono`, `nerd-fonts.symbols-only`.

**Fontconfig defaults:**
- Monospace: JetBrainsMono Nerd Font, CaskaydiaMono Nerd Font
- Sans-serif: Hack Nerd Font
- Serif: Hack Nerd Font

### 4.4 Theme Environment Variables

Exported system-wide via `modules/theme/default.nix`:

```
SPACECRAFT_BACKGROUND = #000027
SPACECRAFT_TEXT       = #D98E32
SPACECRAFT_ACCENT     = #4B7EB0
SPACECRAFT_SUCCESS    = #50FA7B
SPACECRAFT_WARNING    = #FF5C5C
SPACECRAFT_INFO       = #8BE9FD
```

### 4.5 TTY/Virtual Console Colors

Set via `console.colors` -- 16 hex values without `#` prefix, in order: normal 0-7 then bright 8-15.

```
000027 FF5C5C 50FA7B D98E32 4B7EB0 4B7EB0 8BE9FD D98E32
4B7EB0 FF5C5C 50FA7B D98E32 8BE9FD 8BE9FD 8BE9FD D98E32
```

---

## 5. Core System Modules

### 5.1 Nix Settings (`modules/core/nix.nix`)

- **Experimental features:** `nix-command`, `flakes`
- **Garbage collection:** automatic, weekly, `--delete-older-than 30d`
- **nixpkgs.config:** `allowUnfree = true`
- **Overlays:** defined inline; sequoia-wot test fix (`doCheck = false`), claude-code pinned to latest npm release via `overrideAttrs`

### 5.2 Boot (`modules/core/boot.nix`)

- **Bootloader:** systemd-boot, EFI variables writable
- **Kernel:** `linuxPackages_xanmod_latest` (performance-optimized)
- **Initrd modules:** `xhci_pci`, `nvme`, `usb_storage`, `sd_mod`, `rtsx_pci_sdmmc`
- **Kernel modules:** `kvm-intel`

### 5.3 Locale (`modules/core/locale.nix`)

- **Timezone:** `Asia/Bahrain`
- **Default locale:** `en_US.UTF-8`
- **All LC_* variables:** `en_US.UTF-8` (ADDRESS, IDENTIFICATION, MEASUREMENT, MONETARY, NAME, NUMERIC, PAPER, TELEPHONE, TIME)
- **Console keymap:** Set per-host (`us`)

### 5.4 Audio (`modules/core/audio.nix`)

- **PulseAudio:** Disabled
- **PipeWire:** Enabled (ALSA, 32-bit ALSA, PulseAudio compatibility)
- **RTKit:** Enabled (real-time scheduling privileges)
- **JACK:** Available but commented out

### 5.5 Security (`modules/core/security.nix`)

- **sudo (C):** Disabled
- **sudo-rs (Rust):** Enabled, `execWheelOnly = true`
- **Polkit:** Enabled
- **SSH agent:** `programs.ssh.startAgent = true`, GNOME keyring SSH agent disabled
- **Tmpfiles rules:** `/tmp 1777`, `/var/tmp 1777`

### 5.6 DNS (`modules/core/dns.nix`)

- **Resolver:** `systemd-resolved` (NetworkManager → `dns = "systemd-resolved"`)
- **Primary:** Cloudflare malware-blocking — `1.1.1.2` / `1.0.0.2` (+ v6) with TLS SNI `security.cloudflare-dns.com`
- **Fallback:** Plain Cloudflare — `1.1.1.1` / `1.0.0.1` (+ v6) with TLS SNI `cloudflare-dns.com`
- **DNS-over-TLS (DoT):** Enforced (`DNSOverTLS=true` — refuses plaintext)
- **DNSSEC:** Enforced (`DNSSEC=true` — drops responses that fail validation)
- **Routing:** Global `~.` Domains entry forces every query through the global DNS list, ignoring link-specific DNS pushed by DHCP
- **Channel portability:** Schema differs between stable 26.05 (legacy `services.resolved.{dnssec,dnsovertls,...}` flags) and unstable (renamed to `services.resolved.settings.Resolve.*`); module uses an `options.services.resolved ? settings` check to pick the right form per channel and evaluates clean on both the stable and unstable mkBravais variants

---

## 6. Hardware Modules

### 6.1 Fingerprint Reader (`modules/hardware/fingerprint.nix`)

**Option:** `spacecraft.hardware.fingerprint.enable`

When enabled: `services.fprintd.enable = true`, package `fprintd` installed.

### 6.2 Intel CPU Optimizations (`modules/hardware/intel.nix`)

**Option:** `spacecraft.hardware.intel.enable` with `marchLevel` suboption (enum: v1/v2/v3/v4, default: v4).

**Flag sources:** CachyOS for v1/v3/v4, ALHP for v2.

#### CachyOS Common C Flags (v1, v3, v4):
```
-O3 -pipe -fno-plt -fexceptions -flto=auto
-Wp,-D_FORTIFY_SOURCE=3 -Wformat -Werror=format-security
-fstack-clash-protection -fcf-protection
```

#### CachyOS Linker Flags (v1, v3, v4):
```
-fuse-ld=gold
-Wl,-O1 -Wl,--sort-common -Wl,--as-needed
-Wl,-z,relro -Wl,-z,now -Wl,-z,pack-relative-relocs
```

#### ALHP Linker Flags (v2 only):
```
-fuse-ld=gold
-Wl,-O1 -Wl,--sort-common -Wl,--as-needed
-Wl,-z,relro -Wl,-z,now
```

#### Per-Level Flag Table

| Level | CFLAGS                           | RUSTFLAGS                                     | GOAMD64 |
|-------|----------------------------------|-----------------------------------------------|---------|
| v1    | `-march=x86-64 -mtune=native` + CachyOS common + `-flto=auto` | `-C target-cpu=x86-64 -C opt-level=3 -Clink-arg=-z -Clink-arg=pack-relative-relocs` | v1 |
| v2    | `-march=x86-64-v2 -mtune=native -O3 -mpclmul -falign-functions=32 -flto=auto` | `-Copt-level=3 -Ctarget-cpu=x86-64-v2 -Clink-arg=-z -Clink-arg=pack-relative-relocs` | v2 |
| v3    | `-march=x86-64-v3 -mtune=native -mpclmul` + CachyOS common + `-flto=auto` | `-C target-cpu=x86-64-v3 -C opt-level=3 -Clink-arg=-z -Clink-arg=pack-relative-relocs` | v3 |
| v4    | `-march=x86-64-v4 -mtune=native -mpclmul` + CachyOS common + `-flto=auto` | `-C target-cpu=x86-64-v4 -C opt-level=3 -Clink-arg=-z -Clink-arg=pack-relative-relocs` | v4 |

**CXXFLAGS** = `${CFLAGS} -Wp,-D_GLIBCXX_ASSERTIONS` for all levels.
**LTOFLAGS** = `-flto=auto` for all levels.
**LDFLAGS** include `-fuse-ld=gold` on all levels (required on NixOS so GCC can locate the LTO plugin in `/nix/store`).

**Additional config:** `boot.kernelModules = [ "kvm-intel" ]`, Intel microcode updates enabled.

---

## 7. Host Configuration (`hosts/`)

`hosts/` is one directory per physical machine plus a shared `hosts/common.nix`. Each
`hosts/<machine>/default.nix` imports `../common.nix` and its own `./hardware.nix`, then sets
the per-machine bits (`networking.hostName`, `steelbore.hardware.*`). Current machines:
`thinkpad`.

### 7.1 Shared Host Settings (`hosts/common.nix`)

- **Networking:** NetworkManager enabled
- **X11:** Enabled (for LeftWM), keyboard layouts `us,ara`, toggle `grp:ctrl_space_toggle`
- **Console keymap:** `us` (ckbcomp can't resolve multi-layout XKB configs)
- **Printing:** Enabled
- **Desktop + package toggles:** the full `steelbore.desktops.*` / `steelbore.packages.*` set

### 7.1.1 ThinkPad (`hosts/thinkpad/default.nix`)

- **Hostname:** `bravais-thinkpad`
- **Hardware toggles:** `steelbore.hardware.fingerprint.enable`, `steelbore.hardware.intel.enable`
- **March level:** `steelbore.hardware.intel.marchLevel = "v3"` (i7-8665U is AVX2-max, no AVX-512)

### 7.2 User Account

- **Username:** `mj`
- **Full name:** Mohamed Hammad
- **Groups:** `networkmanager`, `wheel`, `input`, `video`, `audio`
- **Shell:** `pkgs.nushell` (Nushell -- Rust shell)
- **Root shell:** `pkgs.brush` (Brush -- Rust Bash-compatible shell)
- **Valid login shells:** nushell, brush, ion (registered via `environment.shells`); bash excluded from `environment.shells` and not assigned to any user — NixOS internals require the bash module to remain enabled

### 7.3 Hardware (`hardware.nix`)

Generated by `nixos-generate-config`. Key details:
- **Platform:** `x86_64-linux`
- **Root filesystem:** ext4, `/dev/disk/by-uuid/667c95b9-16ac-449a-b36c-7a4e156620c3`
- **Boot partition:** vfat, `/dev/disk/by-uuid/30F4-BB7D`, `fmask=0077`, `dmask=0077`
- **Swap:** None
- **Microcode updates:** Linked to `hardware.enableRedistributableFirmware`

### 7.4 State Version

`system.stateVersion = "26.05"`

---

## 8. Login Manager (`modules/login/default.nix`)

### 8.1 greetd + tuigreet

```
tuigreet \
  --time \
  --time-format "%Y-%m-%d %H:%M:%S" \
  --remember \
  --remember-session \
  --asterisks \
  --greeting "STEELBORE :: BRAVAIS" \
  --sessions <sessionData>/share/wayland-sessions:<sessionData>/share/xsessions
```

Running as user `greeter`.

### 8.2 Shell Sessions

Custom shell sessions are built with a `mkShellSession` helper using `pkgs.runCommand` with `passthru.providedSessions`:

| Session Name  | Binary               | Comment                          |
|---------------|----------------------|----------------------------------|
| Nushell       | `nushell`/`nu`       | Default user shell               |
| Brush Shell   | `brush`              | Rust Bash-compatible (root)      |
| Ion Shell     | `ion`                | Available as optional shell      |

### 8.3 Registered Session Packages

```nix
services.displayManager.sessionPackages = [
  niri
  cosmic-session
  ion-shell-session
  nushell-session
  brush-session
];
```

Plasma, LeftWM, and GNOME sessions are auto-registered by their respective NixOS modules.

### 8.4 greetd Environments

```
niri-session
start-cosmic
plasma-session
plasma-x11-session
gnome-session
ion
nu
brush
```

### 8.5 PAM

`security.pam.services.greetd.enableGnomeKeyring = true`

---

## 9. Desktop Environments

### 9.1 GNOME (Wayland)

**Option:** `spacecraft.desktops.gnome.enable`

**Services:**
- `services.xserver.enable = true`
- `services.displayManager.gdm.enable = lib.mkDefault false` (greetd used instead)
- `services.displayManager.gdm.wayland = true`
- `services.desktopManager.gnome.enable = true`

**Extensions (18):**
  caffeine, just-perfection, window-gestures, wayland-or-x11, toggler, vim-alt-tab, open-bar, tweaks-in-system-menu, launcher, window-title-is-back, yakuake, forge, tiling-shell, smart-tiling, ollama-indicator, simple-tiling, warp-toggle, resource-monitor

**Utilities:** gnome-tweaks, dconf-editor, gnome-extension-manager, gnome-browser-connector

**Portals:** xdg-desktop-portal-gnome, xdg-desktop-portal-gtk

**Excluded packages:** gnome-tour, gnome-music, epiphany, geary, totem

### 9.2 COSMIC (Wayland)

**Option:** `spacecraft.desktops.cosmic.enable`

**Services:**
- `services.desktopManager.cosmic.enable = true`
- `services.displayManager.cosmic-greeter.enable = false` (greetd used)

Fully Rust-based desktop from System76. No additional packages needed.

### 9.3 KDE Plasma 6 (Wayland)

**Option:** `spacecraft.desktops.plasma.enable`

**Services:**
- `services.desktopManager.plasma6.enable = true`
- `services.displayManager.sddm.enable = lib.mkDefault false` (greetd used)
- `services.displayManager.sddm.wayland.enable = lib.mkDefault false`
- `services.xserver.enable = true` (XWayland support)
- `programs.ssh.askPassword = lib.mkForce "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass"` (avoids askpass conflicts)

**KDE Packages (8):**
plasma-browser-integration, kdeconnect-kde, plasma-systemmonitor, filelight, kcalc, ark, kate, xdg-desktop-portal-kde

**Excluded packages:** oxygen, elisa, khelpcenter

### 9.4 Niri (Wayland -- Scrolling Tiling)

**Option:** `spacecraft.desktops.niri.enable`

**Service:** `programs.niri.enable = true`

**Companion packages (14):**
niri, swaybg, xwayland-satellite, ironbar, waybar, anyrun, onagre, wired, swaylock, swayidle, wl-clipboard, wl-clipboard-rs, grim, slurp

**Niri Configuration** (`~/.config/niri/config.kdl`, single source via `users/mj/home.nix` — niri reads the user config in preference to `/etc/niri`, so the config lives only at the user level; `modules/desktops/niri.nix` just enables Niri, installs packages, and ships the backlight udev rule + rfkill wrappers):

Layout: gaps 8, focus-ring width 2 (active: Molten Amber, inactive: Steel Blue), borders off, default column width 50%, center-focused-column on-overflow.

Startup: swaybg (Void Navy solid color), ironbar, wired.

Input: keyboard layouts `us,ar` with `grp:ctrl_space_toggle`, touchpad with tap/natural-scroll/accel-speed 0.3.

Key bindings (Mod = Super):
- **Session:** `Mod+Shift+E` quit, `Mod+Shift+L` lock (gtklock), `Mod+Shift+C` toggle Caffeine (pauses swayidle to keep the machine awake)
- **Idle management:** `swayidle -w` (config `~/.config/swayidle/config`) locks via gtklock at 5 min, blanks via `niri msg action power-off-monitors` at 6 min, and locks before suspend; `steelbore-caffeine` SIGSTOP/SIGCONT-toggles it
- **Applications:** `Mod+Return` alacritty (default terminal), `Mod+D` onagre, `Mod+Shift+D` anyrun
- **Windows:** `Mod+Q` close, `Mod+F` maximize, `Mod+Shift+F` fullscreen
- **Focus:** `Mod+H/J/K/L` or `Mod+Arrows` (Vim + CUA)
- **Move:** `Mod+Shift+H/J/K/L` or `Mod+Shift+Arrows`
- **Workspaces:** `Mod+1-5` focus, `Mod+Shift+1-5` move
- **Resize:** `Mod+R` preset, `Mod+Minus/Equal` +/-10%
- **Screenshots:** `Print` full, `Mod+Print` window, `Mod+Shift+Print` screen
- **Dedicated / multimedia keys** (XF86, `allow-when-locked`, hidden from the hotkey overlay):
  - Display brightness `XF86MonBrightnessUp/Down` → `swayosd-client --brightness` (OSD)
  - Volume `XF86AudioRaiseVolume/LowerVolume/Mute` + mic `XF86AudioMicMute` → `swayosd-client --output-volume/--input-volume` (OSD, capped at 100%)
  - Media `XF86AudioPlay/Next/Prev/Stop` → `playerctl`
  - Keyboard backlight `XF86KbdBrightnessUp/Down` → `brightnessctl --device=tpacpi::kbd_backlight`
  - Radios `XF86Bluetooth` / `XF86RFKill` → `steelbore-bt-toggle` / `steelbore-airplane-toggle` (rfkill, rootless via `/dev/rfkill` uaccess ACL, dunst feedback)
  - **OSD:** `swayosd-server` (spawned at startup) renders Steelbore-themed bars; config at `~/.config/swayosd/{config.toml,style.css}` (Void Navy / Molten Amber). Backlight is rootless via brightnessctl's udev rules (`services.udev.packages`; groups `video`/`input`). Added packages: `swayosd`, `brightnessctl`, `playerctl`.

**Ironbar Configuration** (`/etc/ironbar/config.yaml`):
- Position: top, height 32, anchor to edges
- Start: workspaces, focused window
- Center: clock (`%H:%M:%S :: %Y-%m-%d`)
- End: sys_info (CPU%/RAM%, 1s interval), tray

**Ironbar Stylesheet** (`/etc/ironbar/style.css`):
- Font: Share Tech Mono / JetBrains Mono, 14px
- Window: Void Navy background, Molten Amber text, Steel Blue bottom border
- Workspaces: Steel Blue buttons, Molten Amber active with underline
- Clock: Molten Amber bold
- Sys info: Radium Green

### 9.5 LeftWM (X11 -- Tiling WM)

**Option:** `spacecraft.desktops.leftwm.enable`

**Services:** `services.xserver.enable = true`, `services.xserver.windowManager.leftwm.enable = true`

**Companion packages (15):**
leftwm, leftwm-theme, leftwm-config, rlaunch, rofi, dmenu, polybar, picom, feh, dunst, xclip, xsel, maim, xdotool, numlockx

**LeftWM Configuration** (`/etc/leftwm/config.ron`):
- Modkey: Mod4 (Super), mousekey: Mod4
- Tags: 1-9
- Layouts: MainAndVertStack, MainAndHorizontalStack, MainAndDeck, GridHorizontal, EvenHorizontal, EvenVertical, Fibonacci, Monocle
- Layout mode: Tag, insert behavior: Bottom
- Focus: Sloppy, focus new windows, sloppy mouse follows focus
- Scratchpad: "Terminal" (alacritty, 1200x800)

Key bindings:
- **Session:** `Mod+Shift+E` kill session
- **Applications:** `Mod+Return` alacritty (default terminal), `Mod+D` rlaunch, `Mod+Shift+D` rofi
- **Windows:** `Mod+Q` close, `Mod+F` fullscreen, `Mod+Shift+F` float
- **Focus:** `Mod+H/J/K/L` or `Mod+Arrows` (Vim + CUA)
- **Move:** `Mod+Shift+H/J/K/L`
- **Layouts:** `Mod+Space` next, `Mod+Shift+Space` previous
- **Workspaces:** `Mod+1-9` goto, `Mod+Shift+1-9` move
- **Resize:** `Mod+Equal/Minus` +/-5
- **Scratchpad:** `Mod+Grave` toggle terminal

**Theme** (`/etc/leftwm/themes/current/theme.ron`):
- Border width: 2, margin: 8, workspace margin: 8
- Default border: Steel Blue, floating border: Liquid Coolant, focused border: Molten Amber

**Startup Script** (`up`): feh (Void Navy background), picom, dunst, polybar spacecraft, numlockx on

**Shutdown Script** (`down`): kills polybar, picom, dunst

**Polybar Configuration** (`polybar.ini`):
- Bar height: 32, fixed-center, Void Navy background
- Fonts: Share Tech Mono 12, JetBrainsMono Nerd Font 12
- Modules: leftwm-tags (left), date `%H:%M:%S :: %Y-%m-%d` (center), cpu/memory/network (right)
- Colors: success (Radium Green), info (Liquid Coolant), warning (Red Oxide)

**Polybar Tag Template** (`template.liquid`):
- Active tag: Molten Amber with underline
- Visible tag: Liquid Coolant
- Busy tag: Steel Blue
- Empty tag: Steel Blue at 50% opacity

**Picom** (`picom.conf`): GLX backend, vsync, inactive opacity 0.95, fading (delta 5), no shadows, no rounded corners.

**Dunst** (`dunstrc`): 350x150, top-right, 10x40 offset, Share Tech Mono 12, Steel Blue frame. Urgency colors: low (Liquid Coolant), normal (Molten Amber), critical (Red Oxide with Red Oxide frame, no timeout).

---

## 10. Terminal Emulators (`modules/packages/terminals.nix`)

All terminals are themed with the Steelbore palette. Both system-level and user-level configs use Nushell (`nu`) as the default shell.

### 10.1 Terminal Package List

| Terminal       | Language | Category   |
|----------------|----------|------------|
| Alacritty      | Rust     | Primary    |
| WezTerm        | Rust     | Primary    |
| Rio            | Rust     | Primary    |
| Ghostty        | Zig      | Primary    |
| Ptyxis         | C (VTE)  | GNOME — nixpkgs (host install for distrobox integration) |
| WaveTerm       | Go       | AI-native  |
| Warp           | Rust     | AI-powered |
| Termius        | Various  | SSH client |
| COSMIC Term    | Rust     | COSMIC     |
| Konsole        | C++      | KDE        |
| Yakuake        | C++      | KDE        |
| GNOME Console  | C        | GNOME      |
| Foot           | C        | Wayland    |
| XTerm          | C        | X11        |
| XFCE4 Terminal | C        | XFCE       |

### 10.2 System-Level Configuration Files

Each terminal has a system-level config placed in `/etc/` with the full Steelbore palette. The following are generated:

| Terminal       | Config Path                                      | Format  |
|----------------|--------------------------------------------------|---------|
| Alacritty      | `/etc/alacritty/alacritty.toml`                  | TOML    |
| WezTerm        | `/etc/wezterm/wezterm.lua`                       | Lua     |
| Rio            | `/etc/rio/config.toml`                           | TOML    |
| Ghostty        | `/etc/ghostty/config`                            | Custom  |
| COSMIC Term    | `/etc/cosmic/com.system76.CosmicTerm/v1/syntax_theme_dark` | Text |
| COSMIC Term    | `/etc/cosmic/com.system76.CosmicTerm/v1/color_schemes_dark` | RON |
| COSMIC Term    | `/etc/cosmic/com.system76.CosmicTerm/v1/profiles` (Nushell shell; system default) | RON |
| COSMIC Term    | `/etc/cosmic/com.system76.CosmicTerm/v1/default_profile`   | RON |
| COSMIC Term    | `~/.config/cosmic/com.system76.CosmicTerm/v1/{profiles,default_profile}` (HM, `force`; the layer that actually applies — cosmic-config user keys win over `/etc`) | RON |
| Ptyxis/VTE     | `/etc/gtk-4.0/gtk.css`                           | CSS     |
| WaveTerm       | `/etc/waveterm/config.json`                      | JSON    |
| Warp           | `/etc/warp/themes/spacecraft.yaml`                | YAML    |
| Konsole        | `/etc/xdg/konsole/Steelbore.colorscheme`         | INI     |
| Konsole        | `/etc/xdg/konsole/Steelbore.profile`             | INI     |
| Konsole        | `/etc/xdg/konsolerc`                             | INI     |
| Yakuake        | `/etc/xdg/yakuakerc`                             | INI     |
| Foot           | `/etc/xdg/foot/foot.ini`                         | INI     |
| XTerm          | `/etc/X11/Xresources`                            | Xresources |
| XFCE4          | `/etc/xdg/xfce4/terminal/terminalrc`             | INI     |

### 10.3 Common Terminal Settings

- **Font:** JetBrains Mono (12pt for most, 14pt for Rio)
- **Background opacity:** 0.95
- **Padding:** 10px
- **System shell:** Nushell (via `${pkgs.nushell}/bin/nu`)
- **User shell:** Nushell (via `${pkgs.nushell}/bin/nu` in home.nix configs)
- **Foot quirk:** Uses hex colors without `#` prefix (handled by helper `h = c: builtins.substring 1 (builtins.stringLength c - 1) c`)
- **Rio font config:** Uses `weight = N` integers (400 regular, 700 bold) -- no `style` key
- **Konsole:** Full colorscheme with Normal/Faint/Intense variants, profile with 160x48 geometry, blinking cursor
- **Yakuake:** Height 50%, width 100%, no keep-open, no animation, inherits Konsole Steelbore profile

### 10.4 User-Level Configs (Home Manager)

Home Manager additionally generates user-level configs in `~/.config/` for: niri, ironbar (config.yaml + style.css), wezterm, rio, ghostty, foot, xfce4-terminal, konsole (rc + colorscheme + profile via xdg.dataFile), yakuake, and xresources. The user-level Alacritty config is managed via `programs.alacritty` with structured Nix settings. Ptyxis and GNOME Console are configured via `dconf.settings`.

---

## 11. Package Inventory

### 11.1 Browsers (`modules/packages/browsers.nix`)

- **BrowserOS** (Chromium/AppImage) — agentic browser, packaged with `appimageTools.wrapType2`
  (pinned `fetchurl` + SRI hash) so it builds reproducibly into the Nix store
- **Firefox** (system-managed via `programs.firefox.enable`)
- google-chrome, brave, microsoft-edge, librewolf

### 11.2 Editors (`modules/packages/editors.nix`)

**Linting:** markdownlint-cli2

**TUI Editors (Rust):** helix, amp, msedit (MS-DOS style)

**TUI Editors (Standard):** neovim, vim, mg (micro Emacs), mc (Midnight Commander)

**GUI Editors (Rust):** zed-editor-fhs (FHS variant), lapce, neovide, cosmic-edit

**GUI Editors (Standard):** emacs-pgtk, vscode-fhs, gedit

### 11.3 Development (`modules/packages/development.nix`)

**Git & VCS:** git, gitui (Rust), delta (Rust), jujutsu/jj (Rust), gh (Go), github-desktop

**Forgejo (self-hosted Git):** forgejo (Go), forgejo-cli (Rust), forgejo-runner (Go)

**Rust Toolchain:** rustup, cargo, cargo-update

**Build & Task (Rust):** just, sad, pueue, tokei

**Environment:** lorri (Rust), dotter (Rust)

**Cloud CLIs:** google-cloud-sdk, azure-cli, awscli

**Languages:** jdk, php

**Nix Ecosystem:** nixfmt (Rust), cachix, nix, guix, emacsPackages.guix

**Git system config:** `init.defaultBranch = "main"`, `core.editor = msedit`, `color.ui = true`

### 11.4 Security (`modules/packages/security.nix`)

**Encryption:** age (Rust), rage (Rust), sops (Go)

**Sequoia PGP Stack (Rust):** sequoia-sq, sequoia-chameleon-gnupg, sequoia-wot, sequoia-sqv, sequoia-sqop

**Password Managers:** rbw (Rust, Bitwarden CLI), bitwarden-cli, bitwarden-desktop, authenticator (Rust, 2FA/OTP)

**SSH:** openssh_hpn (general-purpose fallback), gitway (Spacecraft Software SSH transport for Git, via flake input — primary path; `gitway-agent` owns `$SSH_AUTH_SOCK`, `gitway-keygen` is git's `gpg.ssh.program`, `gitway-add` replaces `ssh-add` in shell init)

**Backup:** pika-backup (Rust, Borg frontend)

**Secure Boot:** sbctl (Rust)

### 11.5 Networking (`modules/packages/networking.nix`)

**Network Mgmt:** impala (Rust, iwd TUI), iwd

**HTTP Clients:** xh (Rust), monolith (Rust), curlFull, wget2

**Diagnostics (Rust):** gping, trippy, lychee, rustscan, sniffglue, bandwhich

**GUI Apps (Rust):** sniffnet, mullvad-vpn, rqbit

**Download Managers:** aria2, uget

**Clipboard:** wl-clipboard, wl-clipboard-rs (Rust)

**DNS & Services:** dnsmasq, atftp, adguardhome

### 11.6 Multimedia (`modules/packages/multimedia.nix`)

**Video Players:** mpv, vlc, cosmic-player (Rust)

**Audio Players (Rust):** amberol, termusic, ncspot, psst, shortwave

**Image Viewers (Rust):** oculante (default GUI viewer — bound to image MIME types via `xdg.mimeApps` in `users/mj/home.nix`), loupe, emulsion, viu (CLI)

**Audio Recognition:** mousai (Rust)

**Processing (Rust):** rav1e, gifski, oxipng, video-trimmer, ffmpeg

**Downloaders:** yt-dlp

### 11.7 Productivity (`modules/packages/productivity.nix`)

**Knowledge Mgmt (Rust):** appflowy, affine

**Note-taking:** nb (CLI note-taking & knowledge base)

**Office Suites:** libreoffice-fresh, onlyoffice-desktopeditors

**Utilities:** qalculate-gtk

**Communication:** fractal (Rust, Matrix), newsflash (Rust, RSS), tutanota-desktop, onedriver (Go, OneDrive)

### 11.8 System Utilities (`modules/packages/system.nix`)

**Modern Unix (Rust):** fd, ripgrep, bat, eza, sd, zoxide, procs, dust, dua

**Coreutils (Rust):** uutils-coreutils, uutils-diffutils, uutils-findutils

**File Management:** yazi (Rust), broot (Rust), superfile (Go), spacedrive (Rust), fclones (Rust), kondo (Rust), pipe-rename (Rust), ouch (Rust)

**Disk Management:** gptman (Rust), parted, tparted (TUI), gparted (GUI)

**System Monitoring:** bottom (Rust), kmon (Rust), macchina (Rust), bandwhich (Rust), mission-center (Rust), htop, btop, gotop, fastfetch, i7z, hw-probe

**Text Processing (Rust):** jaq, teip, htmlq, skim, tealdeer, mdcat, difftastic, texinfo, pandoc, reuse, hunspell (+en_US)

**Shells:** nushell (Rust), brush (Rust), ion (Rust), starship (Rust), atuin (Rust), pipr (Rust), moor (Rust), powershell

**Multiplexers:** zellij (Rust), screen

**Recording:** t-rec (Rust)

**Containers & Virtualization:** steam-run (FHS environment), distrobox, host-spawn, podman, runc, youki (Rust), oxker (Rust), qemu, flatpak, bubblewrap. Boxbuddy is available as the Flatpak `io.github.dvlv.boxbuddyrs`.

**System Management:** topgrade (Rust), paru (Rust), doas, os-prober, kbd, numlockx, xremap (Rust), input-leap

**Archiving:** p7zip, zip, unzip

**ZFS:** zfs, antigravity-fhs (Rust — FHS variant)

**Benchmarking:** phoronix-test-suite, perf

### 11.9 AI (`modules/packages/ai.nix`)

**Rust:** aichat, gemini-cli

**Other:** opencode (Go), codex, github-copilot-cli, gpt-cli, mcp-nixos, task-master (npx wrapper — nixpkgs `task-master-ai` is unfixable, see CLAUDE.md), claude-code (pinned to latest npm release via overlay)

### 11.10 Flatpak (`modules/packages/flatpak.nix`)

**Remote:** flathub (`https://dl.flathub.org/repo/flathub.flatpakrepo`)

**Packages (44):**

> VSCode (`com.visualstudio.code`) ships a declarative user-level flatpak override
> at `~/.local/share/flatpak/overrides/com.visualstudio.code` (via HM `xdg.dataFile`
> in `users/mj/home.nix`) that prepends `/app/bin:/usr/bin` to PATH so the `code`
> entrypoint resolves inside the sandbox.

| Category            | App IDs                                              |
|---------------------|------------------------------------------------------|
| Terminals           | app.devsuite.Ptyxis (flatpak, alongside nixpkgs host install; GSettings schema org.gnome.Ptyxis — themed via shared host dconf) |
| Browsers            | app.zen_browser.zen, com.microsoft.Edge, com.opera.Opera |
| Communication       | com.discordapp.Discord, im.riot.Riot, io.wavebox.Wavebox |
| Networking / Internet | de.haeckerfelix.Fragments (Rust BitTorrent client)  |
| Security & Remote   | com.bitwarden.desktop, com.rustdesk.RustDesk         |
| Development         | com.jetbrains.RustRover, com.visualstudio.code, dev.zed.Zed, io.github.shiftey.Desktop |
| System & Utilities  | com.github.tchx84.Flatseal, io.github.dvlv.boxbuddyrs, io.github.prateekmedia.appimagepool, it.mijorus.gearlever, org.adishatz.Screenshot, org.flameshot.Flameshot, org.gnome.baobab |
| Gaming              | com.heroicgameslauncher.hgl, com.usebottles.bottles, com.valvesoftware.Steam, info.beyondallreason.bar, net.openra.OpenRA, net.wz2100.wz2100, org.libretro.RetroArch, org.openttd.OpenTTD |
| Retro / Classic     | com.dosbox.DOSBox, com.dosbox_x.DOSBox-X, com.play0ad.zeroad, com.remnantsoftheprecursors.ROTP, eu.jumplink.Learn6502, io.github.dosbox-staging, io.github.jotd666.gods-deluxe, io.github.dman95.SASM, org.seul.crimson, org.zdoom.UZDoom, rs.ruffle.Ruffle |
| Productivity        | io.github.Qalculate, org.kde.yakuake                 |

### 11.11 Homebrew (`modules/packages/homebrew.nix`)

Linuxbrew as a **4th-priority escape hatch** (per the spacecraft-missing-pkg
order Guix → Nix → Cargo → **Homebrew** → Flatpak → Snap) for software with no
Nix/Guix/Cargo packaging. Brew expects an FHS layout, a real system compiler,
and a `/home/linuxbrew` prefix that NixOS does not provide, so it runs inside a
**distrobox container** (`brew`, from `quay.io/toolbx-images/ubuntu-toolbox:24.04`)
where it behaves exactly as upstream intends: full FHS, an apt-managed userland,
passwordless sudo inside the box, and brew-installed binaries that run normally.

**Dependency:** distrobox drives the host's rootless podman, configured by the
`system` bundle (`virtualisation.podman.enable`). The host enables both
`packages.system` and `packages.homebrew`, so this is always satisfied — noted
so the coupling is explicit.

**Commands installed** (all `pkgs.writeShellApplication`, shellcheck-linted at
build time):

| Command         | Purpose                                                                          |
|-----------------|----------------------------------------------------------------------------------|
| `brew-box-init` | One-time setup: create the `brew` container, apt-install brew's Linux deps (`build-essential procps curl file git`), then run the Homebrew installer. |
| `brew`          | Run `brew <args>` from the normal (Nushell) shell — proxies into the box and sources `brew shellenv`. Errors with a hint if `brew-box-init` hasn't run. |
| `brew-box`      | Interactive shell inside the container (for poking around or running brew-installed tools). |

**One-time bootstrap:**

```sh
brew-box-init
# then, from any shell:
brew install <formula>
```

Installs to the documented prefix `/home/linuxbrew/.linuxbrew` inside the box.
`brew-box-init` is kept separate from `brew` so the first `brew` call is not a
surprise multi-minute image-pull + install.

**Why distrobox over an FHS sandbox:** a `buildFHSEnv` wrapper also works, but
binaries installed *by* brew then link against the sandbox and only run inside
it. The container approach removes that sharp edge — `brew-box` runs them
natively. The image is hardcoded but trivially swappable (Fedora/Debian) in the
module's `image` binding.

---

## 12. Virtualization & Containers

### 12.1 Podman

```nix
virtualisation.podman = {
  enable = true;
  dockerCompat = true;       # docker -> podman drop-in alias
  extraPackages = [ pkgs.youki pkgs.runc ];
};
```

### 12.2 Flatpak

```nix
services.flatpak.enable = true;
```

### 12.3 AppImage

First-class support: `binfmt` auto-run for any `*.AppImage`, plus the AppImagePool GUI
(Flatpak). Loose AppImages live in `~/Applications/` by convention. When an AppImage is
used regularly, prefer packaging it as a Nix derivation with `appimageTools.wrapType2`
(see BrowserOS in §11.1) over a loose binary.

```nix
programs.appimage = {
  enable = true;
  binfmt = true;  # auto-run via binfmt
};
```

### 12.4 Container User Config

```ini
# ~/.config/containers/containers.conf
[engine]
runtime = "runc"
```

---

## 13. User Configuration (Home Manager)

### 13.1 Basic Settings (`users/mj/home.nix`)

- **Username:** mj
- **Home:** `/home/mj`
- **State version:** 26.05
- **Symlink:** `~/steelbore` -> `/spacecraft-software` (out-of-store symlink; `/steelbore/` legacy symlink farm still resolves)

### 13.2 Keyboard Layout

```nix
home.keyboard = {
  layout = "us,ara";
  options = [ "grp:ctrl_space_toggle" ];
};
```

### 13.3 Session Variables

```
EDITOR = msedit/bin/edit
VISUAL = msedit/bin/edit
SPACECRAFT_THEME = true
```

### 13.4 User Packages

`sequoia-chameleon-gnupg`

### 13.5 Git Configuration

```nix
programs.git = {
  enable = true;
  lfs.enable = true;
  settings = {
    user.name = "UnbreakableMJ";
    user.email = "34196588+UnbreakableMJ@users.noreply.github.com";
    user.signingkey = "~/.ssh/id_ed25519.pub";
    gpg.format = "ssh";
    commit.gpgsign = true;
    init.defaultBranch = "main";
  };
};
```

### 13.6 Starship Prompt (Tokyo Night Preset)

Format string:
```
[blk](#a3aed2)[  ](bg:#a3aed2 fg:#090c0c)[](bg:#769ff0 fg:#a3aed2)$directory[](fg:#769ff0 bg:#394260)$git_branch$git_status[](fg:#394260 bg:#212736)$nodejs$rust$golang$php[](fg:#212736 bg:#1d2230)$time[ ](fg:#1d2230)\n$character
```

(Where `blk` represents the unicode block characters.)

Module configurations: directory (truncation 3, icon substitutions), git_branch (symbol), git_status, nodejs/rust/golang/php (version info in dark segment), time (`%R` format).

### 13.7 Nushell Configuration

```nix
programs.nushell.enable = true;
```

Config includes: `show_banner: false`, `ls_colors: true`, `clickable_links: true`, block cursor shapes.

**Steelbore Telemetry Aliases:**
- `ll` = `ls -l`
- `lla` = `ls -la`
- `telemetry` = `macchina`
- `sensors` = `watch -n 1 sensors`
- `sys-logs` = `journalctl -p 3 -xb`
- `network-diag` = `gping google.com`
- `top-processes` = `bottom`
- `disk-telemetry` = `yazi`
- `edit` = `msedit`

**`steelbore` command:** Prints Steelbore OS Bravais identity banner (STATUS: ACTIVE, LOAD: NOMINAL, INTEGRITY: VERIFIED).

### 13.8 Ion Shell Init (`~/.config/ion/initrc`)

- Starship prompt integration: `eval $(starship init ion)`
- Same aliases as Nushell (ll, lla, telemetry, sensors, sys-logs, top-processes, disk-telemetry, edit)

### 13.9 Alacritty (Home Manager)

Managed via `programs.alacritty.enable = true` with structured Nix settings. Shell: Nushell. Full Steelbore palette via `spacecraftPalette` variable references.

### 13.10 dconf Settings

**Ptyxis:**
- Default profile UUID: `steelbore`
- Font: JetBrainsMono Nerd Font 12
- Full 16-color palette from `steelborePalette`
- Background: Void Navy, foreground: Molten Amber, opacity: 0.95

**GNOME Console:**
- Theme: night
- Font: JetBrains Mono 12

---

## 14. Keyboard Layout

- **Primary:** US English (`us`)
- **Secondary:** Arabic (`ara`)
- **Toggle:** `Ctrl+Space` (`grp:ctrl_space_toggle`)
- **Configuration:** Set in `hosts/common.nix` (system), `users/mj/home.nix` (user), `modules/desktops/niri.nix` (Niri XKB)

---

## 15. Desktop Environment Summary

| Desktop | Protocol | Bar      | Launcher        | Notification          |
|---------|----------|----------|-----------------|----------------------|
| GNOME   | Wayland  | Shell    | GNOME           | GNOME                |
| COSMIC  | Wayland  | Panel    | cosmic-launcher | cosmic-notifications |
| Plasma  | Wayland  | Panel    | KRunner         | KDE Notifications    |
| Niri    | Wayland  | Ironbar  | onagre/anyrun   | wired                |
| LeftWM  | X11      | Polybar  | rlaunch/rofi    | dunst                |

---

## 16. Verification Plan

### 16.1 Build Verification

```bash
# Check flake validity
nix flake check

# Show flake outputs
nix flake show

# Dry-run build
nixos-rebuild dry-build --flake .#bravais

# Build without switching
nixos-rebuild build --flake .#bravais

# Switch to new configuration
sudo nixos-rebuild switch --flake .#bravais

# Build a specific machine / channel
sudo nixos-rebuild switch --flake .#bravais-thinkpad
sudo nixos-rebuild switch --flake .#bravais-thinkpad-unstable
```

### 16.2 Desktop Environment Verification

| Desktop | Verification Command       | Expected Result               |
|---------|----------------------------|-------------------------------|
| GNOME   | `gnome-session --version`  | Session starts on Wayland     |
| COSMIC  | `cosmic-session --version` | Session starts with panel     |
| Plasma  | `plasmashell --version`    | Session starts on Wayland     |
| Niri    | `niri --version`           | WM starts with Ironbar        |
| LeftWM  | `leftwm --version`         | WM starts with Polybar        |

### 16.3 Spacecraft Software Standard Compliance

- [x] **Metallurgical naming:** Bravais (crystal structure)
- [x] **Memory safety:** Rust-first packages, sudo-rs, Sequoia PGP, Nushell/Brush shells; bash excluded from login shells (NixOS module kept enabled for PAM/activation script compatibility)
- [x] **Performance:** XanMod kernel, x86-64-v1/v2/v3/v4 flags (CachyOS/ALHP sourced)
- [x] **Security:** Sequoia PGP, polkit, sudo-rs execWheelOnly, secure boot ready (sbctl)
- [x] **License:** GPL-3.0-or-later, SPDX headers on all files
- [x] **Privacy:** No telemetry, local storage default
- [x] **Key bindings:** CUA + Vim (hjkl) in all tiling WMs (Niri, LeftWM)
- [x] **Color palette:** Void Navy background on all surfaces (TTY, terminals, bars, notifications)
- [x] **Typography:** Share Tech Mono (HUD), JetBrains Mono (code), Orbitron (headers)
- [x] **Date/Time:** ISO 8601 (`%Y-%m-%d %H:%M:%S`), 24h format in all bars and tuigreet
- [x] **Containers:** Podman (not Docker) with runc default runtime and Youki (Rust) available

---

*--- Forged in Spacecraft Software ---*
