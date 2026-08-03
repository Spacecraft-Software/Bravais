# Changelog

All notable changes to Bravais are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added

- **`mcpctl` is now a declared flake input** — `mcp-servers`
  (`git+file:///spacecraft-software/mcp-servers`), installed into
  `home.packages`. It was previously installed imperatively via
  `nix profile install`, which a fresh machine would not reproduce, and
  `rebuild`'s MCP drift probe compensated by hunting for it on `PATH` and
  falling back to a `cargo build --release` artifact. That probe now calls it
  by store path, so the fallback and the "mcpctl not built" branch are gone;
  a failing probe reports its stderr instead of being silently skipped.
  - `git+file:` rather than `path:` deliberately: a path input is
    content-addressed and drifts its NAR hash on every source edit (constraint
    #10 — the reason the five local Rust-app path inputs were dropped). A git
    input pins a rev, so the working tree can change freely and only
    `nix flake update mcp-servers` moves it. The trade-off is that `git+file:`
    sees **committed** content only, so an mcpctl change must be committed
    before a Bravais rebuild picks it up.
  - **Action required once:** `nix profile remove mcpctl`. `~/.nix-profile/bin`
    precedes `/etc/profiles/per-user/mj/bin` on `PATH`, so until the imperative
    copy is gone it shadows the declarative one for interactive use.

- **`theme.nix`, local themes, and a `theme` command** — the palette was already
  swappable, but not conveniently: the knob sat at line 135 of a 380-line
  `flake.nix`, trying a theme meant editing a tracked file, and every palette
  came from Construct's upstream TOML with nowhere to put your own.
  - The active theme moved to **`theme.nix`** at the repo root — a four-line file
    whose only job is naming it.
  - **`themes/<slug>.nix`** adds local themes. Either derive from a registered
    palette (`{ base = "steelbore"; accent = "#FF8A3D"; }`) or bind the roles
    outright. They resolve through the same path as registered palettes, so they
    inherit role completion, the hue-derived ANSI map and xterm-256 handling.
    Unknown role names, malformed hex, missing required roles and unknown `base`
    slugs are all rejected at eval time — previously a typo'd role was silently
    ignored and a bad hex failed deep inside the color converter naming neither
    the file nor the token.
  - Every selectable theme gets a buildable system at
    **`themeSystems.<system>.<slug>`**, so a theme can be applied with nothing in
    the repo changing. These are deliberately *not* `nixosConfigurations`
    entries: `nix flake check` force-evaluates every one of those, and a full
    system costs ~1.9 GB in the evaluator plus ~1.3 GB for each additional one
    held alongside it — fifteen variants needed ~23 GB and were OOM-killed on a
    31 GB machine, taking an unrelated process with them. As a non-standard
    output they stay lazy: the check skips them with a warning (3.4 GB peak,
    ~100s) and only the theme you build is ever evaluated. `theme try`
    consequently activates the way `nixos-rebuild` does internally — set the
    system profile, then `switch-to-configuration switch`.
  - **`theme list` / `show` / `set` / `try`** (Nushell, beside `rebuild`). Reads
    a new `theme-registry` package output — every theme resolved to JSON — which
    evaluates only the palette library, so `theme list` is instant where walking
    `nixosConfigurations` costs about a minute per theme. `list`/`show` print
    truecolor swatches rather than returning a table, because Nushell strips ANSI
    inside table cells; `theme registry` remains the structured, pipeable view.
  - The `bravais` alias now points at `nixosConfigurations.bravais-thinkpad`
    instead of calling `mkBravais` a second time, dropping a full duplicate
    evaluation from `nix flake check`.

### Changed

- **Palette is now the Standard §11 family, and switchable** — Standard v1.35
  turned §11 from a single palette into a family of seven adoptable palettes
  and renamed the six-token palette Bravais shipped to *Steelbore Classic*.
  Bravais named those colors by brand (`steelborePalette.moltenAmber`) in 428
  places, so changing palette meant editing all 428. §11.1 requires references
  to go through *role* tokens precisely so the palette can be swapped without
  touching consumers; that indirection now exists. `lib/colors.nix` became
  `lib/palette.nix`, which selects a member by slug and resolves it to a
  complete role record, reading values out of the canonical `steelbore.toml`
  shipped by the `construct` input rather than restating them (§11.4). Roles a
  palette omits resolve through a fallback chain (`info` → `structure`,
  `surface` → `background`, `warning` → `error`, `focus` → `success`), so
  consumers never branch on which palette is active. Switching the whole
  system — ~15 terminals, both bars, every WM, the TTY console, greetd — is one
  word in `flake.nix`.

- **Adopted Steelbore Modern** (`steelbore`, the Standard default) in place of
  Classic. Text moves from Molten Amber to Platinum Mist on the same Void Navy
  canvas, with Plasma Orange accents, Pulse Violet structure and a real
  Plasma Magenta warning role distinct from Mars Red error. `SPACECRAFT_WARNING`
  had been carrying the *error* color — a six-token palette had no separate
  warning — and is now correct, with `SPACECRAFT_ERROR`, `SPACECRAFT_SURFACE`
  and `SPACECRAFT_STRUCTURE` added.

- **16-color ANSI mapping is derived, not hand-collapsed.** It also existed
  twice — in `lib/terminal-theme.nix` and `modules/theme/default.nix` — kept in
  step by hand; it is single-sourced in `lib/palette.nix` now. `red` and `green`
  stay pinned to the error and success roles (every terminal reads them that
  way), and the remaining color slots go to whichever role token sits nearest
  the slot's canonical hue. A fixed role→slot table could only ever be
  hue-correct for one palette — Classic's `accent` is Steel Blue where Modern's
  is Plasma Orange — so the assignment is measured per palette instead. Slots
  still collide where a palette genuinely lacks a hue (Modern has no cyan), but
  nothing is collapsed by hand. Applied to Classic the derivation reproduces the
  previous hand-written mapping exactly.

- Bumped `actions/checkout@v4` → `@v5` in all four workflows; v4 targets the
  deprecated Node 20 and was annotating every run.

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
- **steelbore-bt-state** — single source of truth for the Bluetooth
  indicator. Emits `off | on | connected` by combining the rfkill
  soft-block check with a `bluetoothctl info` walk of paired devices.
  Consumed by both Eww bars (the `bt`/`bt_state` defpolls) and the
  toggle OSD so the icon, color, and notification stay consistent.
- **nix-ld enabled** (`programs.nix-ld.enable = true` in
  `modules/packages/development.nix`) — allows running unpatched dynamic
  binaries (npm packages, Python wheels with native extensions, VS Code
  server, pre-built toolchains).
- **Adit flake input placeholder** in `flake.nix` — commented-out `adit`
  input with activation checklist for when Adit (Spacecraft Software's
  universal SSH_ASKPASS helper) ships its flake.

### Changed

- **Eww indicator icons overhauled (Niri + LeftWM)** — all status-bar
  glyphs now resolved from the installed JetBrainsMono Nerd Font v3.4.0
  cmap (verified codepoints, not guessed):
  - **Bluetooth** — three-state: `nf-md-bluetooth_off` (red) when
    soft-blocked, `nf-fa-bluetooth` (dim steel blue) when on but idle,
    `nf-md-bluetooth_connect` (green) when a paired device is linked.
    The old single `mdi-bluetooth` glyph is gone; the CSS grew a
    `bt-connected` class.
  - **Network** — `nf-fa-wifi` (wireless), `nf-fa-ethernet` (wired),
    `nf-fa-plane` (red when down). Replaces the v2-era `mdi-wifi` /
    `mdi-ethernet` / `mdi-lan-disconnect` codepoints, which point at
    the wrong glyphs under Nerd Font v3.
  - **Caffeine indicator** — new bar widget mirroring the
    `steelbore-caffeine` toggle: `nf-md-coffee_outline` (green) when
    staying awake, `nf-md-coffee_off` (red) when idle. Reads the
    `XDG_RUNTIME_DIR/steelbore-caffeine.active` flag file every 3 s.
  - **Metric labels** — the `CPU` / `RAM` / `BAT` words are replaced by
    `nf-oct-cpu`, `nf-fa-memory`, and `nf-md-battery` glyphs (the
    percentage text and amber/red threshold colors are unchanged).
- **Bluetooth toggle OSD** — the toggle-off branch now fires with
  `dunstify -u critical`, so dunst renders "Bluetooth Off" in the red
  oxide urgency palette (frame + foreground) just as prominently as the
  toggle-on message. The off event is no longer a quiet blue notification.

### Fixed

- **Antigravity loading stale Construct skills** — `spacecraft.construct.agentPaths`
  omitted Gemini entirely on the assumption that "Gemini reads `~/.agents/`
  directly". That holds for Gemini CLI, but Antigravity scans
  `~/.gemini/config/skills` (via the `~/.gemini/antigravity/skills` symlink),
  which was an unmanaged hand-copy last refreshed 2026-05-27. Every one of its
  16 skills had drifted, 26 skills were missing, and 2 removed ones
  (`spacecraft-standard`, since renamed `spacecraft-standard-constitution`;
  `android-intent-security`, moved into `android-skills/`) were still being
  served — which is why Antigravity kept citing "SFRS", a term the Construct
  repo replaced with "Dual-Mode Self-Documenting CLI Standard". Added
  `.gemini/config/skills` to `agentPaths` so the activation script replaces the
  stale directory with a symlink to `~/.agents/skills`.

- **Copilot reading stale Construct skills** — `.github/skills/`, which the
  GitHub Copilot coding agent, Copilot CLI and the VS Code agent mode all load,
  was a hand-vendored copy last refreshed 2026-05-20. Eight of its ten skills
  had drifted from Construct and two no longer existed upstream under those
  names (`rust-guidelines`, since split into `microsoft-rust-guidelines` and
  `spacecraft-rust-guidelines`; `spacecraft-standard`, renamed
  `spacecraft-standard-constitution`). Same failure as the Antigravity entry
  above, in the one place the `agentPaths` symlink cannot reach it: the cloud
  agent gets a plain `git clone`, with no Nix store and no flake input to
  resolve, so these skills genuinely have to be vendored. Replaced the hand-copy
  with `pkgs/sync-skills.nu`, which materialises the directory from the
  `construct` rev already pinned in `flake.lock` — the same rev Home Manager
  installs into `~/.agents/skills`, so local and cloud agents now read
  byte-identical skills — plus a `Skills Drift` workflow running its `--check`
  mode, so a stale copy fails CI instead of quietly mis-instructing the agent.
  The vendored set went 10 → 13: both orphans resolved to their upstream
  successors, and `spacecraft-nix-guidelines`, `spacecraft-nu-guidelines` and
  `spacecraft-rust-guidelines` were added — the three that match what actually
  gets written in this repo.

- **REUSE mis-crediting vendored Microsoft prose** — the blanket `.github/**`
  annotation in `REUSE.toml` is `precedence = "aggregate"`, so once the
  refreshed `microsoft-rust-guidelines` brought in files tagged
  `GPL-3.0-or-later OR MIT` / `(C) Microsoft Corporation`, REUSE flattened that
  `OR` into an aggregate and named Mohamed Hammad a copyright holder of
  Microsoft's text — contrary to Standard §4.2, which requires
  third-party-derived artifacts to preserve their upstream license. Added a
  `.github/skills/**` stanza with `precedence = "closest"` so a vendored file's
  own header wins wherever it has one, and `LICENSES/MIT.txt` for the MIT text
  now in-tree. (`reuse lint` still reports one invalid expression in
  `spacecraft-cli-standard/references/testing-compliance.md` — an upstream
  Construct bug, a table cell quoting `rg -L 'SPDX-License-Identifier: …'` that
  the scanner reads as a real tag. It predates this change.)

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
