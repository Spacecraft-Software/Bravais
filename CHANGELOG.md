# Changelog

All notable changes to Bravais are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added

- **nil Nix LSP** — `github:UnbreakableMJ/nil` flake input (fork of
  oxalica/nil), threaded through `specialArgs`/`extraSpecialArgs`, installed
  system-wide via `modules/packages/development.nix`, and used in the
  devShell (replacing the previous `nixpkgs.legacyPackages` nil reference).
- **steelbore-kbd-light-cycle** — cycles `tpacpi::kbd_backlight` 0→1→2→0
  for the ThinkPad T490s `XF86KbdLightOnOff` hotkey (F11 in hotkey mode).
  Rootless via the brightnessctl udev ACL (`input` group).
- **steelbore-osd** — dunstify-based X11 OSD wrapper for LeftWM (swayosd is
  Wayland-only). Handles volume-up/down/mute, mic-mute, brightness-up/down
  with progress-bar popups (replace-id → HUD feel).
- **LeftWM multimedia/hardware hotkeys** — 13 XF86 binds mirroring Niri:
  volume up/down/mute, mic-mute, media play/next/prev, brightness up/down,
  keyboard-backlight cycle, Bluetooth + airplane radio toggles, and
  keybinding help (`Mod+Shift+Slash` → `rofi -dmenu` over
  `~/.config/leftwm/keybinds.txt`).
- **Shared helper wrappers** — `steelbore-bt-toggle`,
  `steelbore-airplane-toggle`, `steelbore-caffeine`, and the new
  `steelbore-kbd-light-cycle` + `steelbore-osd` moved to
  `modules/desktops/shared.nix` (gated on `niri.enable || leftwm.enable`)
  so both WMs get them. `brightnessctl` udev rule also moved here so
  LeftWM gets the same rootless backlight ACL as Niri.
- **nix-ld enabled** (`programs.nix-ld.enable = true` in
  `modules/packages/development.nix`) — allows running unpatched dynamic
  binaries (npm packages, Python wheels with native extensions, VS Code
  server, pre-built toolchains).
- **Adit flake input placeholder** in `flake.nix` — commented-out `adit`
  input with activation checklist for when Adit (Spacecraft Software's
  universal SSH_ASKPASS helper) ships its flake.

### Fixed

- **Eww bar not rendering (both Niri and LeftWM)** — three yuck escaping
  bugs introduced during the Phase D split:
  1. `printf "%d"` → `printf \"%d\"` — bare inner quotes closed the yuck
     string; eww 0.6.0 rejected with "Invalid token" and the bar never
     loaded.
  2. `\xEF\x8A\x93` → `\\xEF\\x8A\\x93` — yuck stripped a lone backslash
     from `\x`, so Nerd Font glyphs rendered as literal "xEFx8Ax93" text.
     Doubling the backslashes passes `\x` through to the shell printf.
  3. `''${IF}` → `\''${IF}` — yuck interpreted `${IF}` as a yuck variable
     reference; prefixing with `\` (→ `\$` in yuck) passes it through to
     the shell as a bash variable.
- **Nushell `rebuild` command broken** — `$nu.home-path` renamed to
  `$nu.home-dir` in Nushell 0.112.2; the vendored-binary stamp check
  failed with `column_not_found` on every invocation.
- **F11 key mapped to hotkey-overlay** — the T490s F11 hotkey glyph is the
  keyboard-backlight toggle (`XF86KbdLightOnOff`), not a literal F11 key.
  Removed the `F11 { show-hotkey-overlay; }` bind; added
  `XF86KbdLightOnOff → steelbore-kbd-light-cycle`.
- **Mic mute** — `XF86AudioMicMute` now calls `wpctl set-mute
  @DEFAULT_AUDIO_SOURCE@ toggle` (swayosd's `--input-volume mute-toggle`
  is a no-op on this PipeWire build); the `steelbore-audio-led` daemon
  lights `platform::micmute` once wpctl flips the mute state.
- **Ptyxis `tty: ttyname error: No such device`** — removed
  `use-custom-command` / `custom-command` from the Ptyxis dconf profile.
  VTE now resolves the login shell via `getpwuid()` (nushell, set
  system-wide) and connects it to the PTY correctly.

### Changed

- **Eww config split into per-WM files** — the shared eww bar config
  (previously in `users/mj/niri.nix`) is now split into a Niri-specific
  config (`users/mj/eww.nix` with BT radio + network glyph defpolls) and a
  LeftWM-specific config (`modules/desktops/leftwm.nix` under
  `eww-leftwm/` with workspace tags via leftwm-state IPC, window title,
  and systray). `modules/login/default.nix` updated to launch
  `eww open bar --config ~/.config/eww-leftwm` for LeftWM sessions.
- **Dead ironbar config removed** — `ironbar/config.yaml` and
  `ironbar/style.css` blocks in `users/mj/niri.nix` were leftovers from the
  Phase D split; ironbar was never installed. Removed (~60 lines).
- **Per-machine host configurations.** `hosts/` is now one directory per
  physical machine. Shared host settings moved to `hosts/common.nix`;
  `hosts/bravais/` became `hosts/thinkpad/` (imports `../common.nix` +
  `./hardware.nix`, sets `networking.hostName = "bravais-thinkpad"` and
  pins `steelbore.hardware.intel.marchLevel = "v3"` — the i7-8665U is
  x86-64-v3 with no AVX-512, so the old v4 default would emit illegal
  instructions). `mkBravais` now takes `{ host, channel }` instead of
  `{ marchLevel, channel }`, and the 10-entry march × channel matrix is
  replaced by `bravais-thinkpad`, `bravais-thinkpad-unstable`, and a
  `bravais` alias → stable ThinkPad. Adding a machine = drop a
  `hosts/<machine>/` dir + two output lines in `flake.nix`.
- **Project renamed: Lattice → Bravais** (full name: *Steelbore OS
  Bravais*). The crystallography theme is preserved — a Bravais lattice
  is a kind of lattice — and every identifier follows: `mkLattice` →
  `mkBravais`, all 10 `nixosConfigurations` keys (`bravais`,
  `bravais-v{1..4}`, `bravais-unstable`, `bravais-unstable-v{1..4}`),
  `networking.hostName`, the working-tree path (`/steelbore/lattice` →
  `/steelbore/bravais`), the GitHub repo (`Spacecraft-Software/Lattice` →
  `Spacecraft-Software/Bravais`), all module headers, the greetd greeting
  (`STEELBORE :: BRAVAIS`), and every documentation file. `v0/` is
  intentionally left untouched as a frozen pre-flake snapshot of the old
  name; see `v0/README.md`.

## [2.1.0] — 2026-04-05

### Added

- **greetd + tuigreet login manager** — Professional graphical login replacing TTY-first boot
  - ISO 8601 date/time display (`%Y-%m-%d %H:%M:%S`)
  - Session memory (remembers last selected desktop)
  - Password asterisks for visual feedback
  - Steelbore branding in greeting message
  - PAM integration for GNOME Keyring

- **Steelbore themes for all terminal emulators**
  - Ghostty configuration (`/etc/ghostty/config`)
  - WaveTerm JSON configuration (`/etc/waveterm/config.json`)
  - Warp Terminal YAML theme (`/etc/warp/themes/spacecraft.yaml`)
  - COSMIC Term theme reference
  - Ptyxis dconf profile with full 16-color palette

- **USER_MANUAL.md** — Comprehensive user documentation
  - Complete Niri keybinding reference
  - Complete LeftWM keybinding reference
  - COSMIC and GNOME quick start guides
  - Terminal emulator comparison and usage
  - Shell configuration (Nushell aliases)
  - System administration commands
  - Troubleshooting guide
  - Quick reference card

- **Enhanced Niri keybindings**
  - Arrow key alternatives for all navigation
  - Workspaces 6-9 support
  - Mouse wheel workspace switching
  - Screenshot keybindings (Print, Mod+Print)

- **Enhanced home.nix XDG configurations**
  - User-level Ghostty config
  - User-level WezTerm config with tab bar theming
  - User-level Rio config
  - Ironbar status bar configuration

### Changed

- **modules/login/default.nix** — Complete rewrite from TTY script to greetd service
- **modules/packages/terminals.nix** — Expanded from 3 to 8 terminal configurations
- **users/mj/home.nix** — Added dconf settings, expanded XDG configs
- **PRD.md** — Updated to version 2.1, reflecting actual implementation
- **implementation_plan.md** — Converted to implementation status document

### Fixed

- **XKB layout conflict** — Removed duplicate keyboard layout from leftwm.nix
  - Host configuration (`us,ara`) is now the single source of truth
  - Desktop modules no longer set conflicting layouts

### Removed

- TTY-first `gui` session selector script (replaced by greetd)

---

## [2.0.0] — 2026-04-02

### Added

- **Complete architecture rewrite** — Modular, opt-in design with `steelbore.*` namespace
- **Four desktop environments**
  - Niri (Wayland) — Scrolling tiling compositor with Ironbar
  - LeftWM (X11) — Tiling WM with Polybar
  - COSMIC (Wayland) — Full desktop from System76
  - GNOME (Wayland) — Full desktop with extensions

- **Steelbore color palette** — Unified theming across all components
  - Void Navy (`#000027`) — Mandatory background
  - Molten Amber (`#D98E32`) — Primary text
  - Steel Blue (`#4B7EB0`) — Accents
  - Radium Green (`#50FA7B`) — Success
  - Red Oxide (`#FF5C5C`) — Errors
  - Liquid Coolant (`#8BE9FD`) — Info

- **Module categories**
  - `steelbore.desktops.*` — Desktop environments
  - `steelbore.hardware.*` — Hardware support (fingerprint, Intel)
  - `steelbore.packages.*` — Application bundles (10 categories)

- **Terminal configurations**
  - Alacritty with Steelbore theme
  - WezTerm with Steelbore theme
  - Rio with Steelbore theme

- **Home Manager integration**
  - Starship prompt with Steelbore palette
  - Nushell configuration with aliases
  - Git configuration with SSH signing

- **PRD.md** — Product Requirements Document
- **implementation_plan.md** — Architecture and migration plan

### Changed

- Migrated from monolithic configuration to modular flake structure
- Replaced sudo with sudo-rs (Rust implementation)
- Updated to XanMod kernel

---

## [1.0.0] — 2026-03-15

### Added

- Initial NixOS flake configuration
- Basic GNOME desktop support
- Home Manager for user configuration
- Hardware configuration for bravais host

---

*--- Forged in Spacecraft Software ---*
