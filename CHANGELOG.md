# Changelog

All notable changes to Bravais are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Changed

- **Vendored skill renamed: `spacecraft-standard-constitution` →
  `spacecraft-steelbore-standard`** (Steelbore Standard v1.49, Construct PR
  #42). The `pkgs/sync-skills.nu` allow-list is updated — without it the
  skill would silently stop being vendored — along with
  `.github/copilot-instructions.md`, the vendored bundle directory (refreshed
  to the v1.49 content it will re-sync to), and the cross-references inside
  the other vendored skills. `flake.lock` still pins a pre-rename Construct
  rev; the next `sync-skills` run after a flake bump regenerates the vendored
  tree verbatim.

### Added

- **Vacuum, Engram and crates-mcp are declarative.** All three were
  `cargo install` builds under `~/.cargo/bin`, so a fresh machine reproduced
  none of them. The Engram case was the sharp one: `mcp-servers/mcp.toml`
  registers that server as `command = "engram"`, resolved by *bare name on
  PATH*, so whatever cargo last built from an uncommitted working tree was
  literally what every MCP host spawned.
  - `vacuum` and `engram` join as `github:` flake inputs, threaded through
    `extraSpecialArgs` and installed user-scoped in `home.packages` — their
    state and config are entirely `$HOME`-side. Vacuum's own `nixosModule` is
    deliberately unused: its whole body is `environment.systemPackages`, which
    would put the binary in the system profile while the `roots` bounding its
    deletions stayed in one user's `$HOME`.
  - Engram had no `flake.nix` at all; one was written upstream (with the
    `srcOverride` idiom and a packaging version-skew fix) and the repo — the
    only private one among the inputs, which is why `github:` first 404'd —
    was made public like the rest.
  - `crates-mcp` is third-party, so it is packaged in `pkgs/` and pinned by
    version + hash rather than by rev. Its four live network tests against
    crates.io and docs.rs are skipped by name; the five offline ones still
    gate the build.

  Every binary `mcp.toml` resolves by bare name now comes from Nix.

### Fixed

- **A documented rule was unreadable from everywhere but one directory.**
  Engram's `--db` default is the bare *relative* path `engram.db` with no XDG
  fallback, so any run that did not pass `--db` minted a fresh, empty store in
  the current directory. Two had accumulated, and
  `skill-description-1000` — which `/spacecraft-software/CLAUDE.md` documents
  as readable via `engram rule list --scope spacecraft-software` — existed
  *only* in `/spacecraft-software/engram/engram.db`. The rule is back in the
  real store, both strays are deleted, and `ENGRAM_DB` now pins the path so
  the footgun cannot fire again. The store also moved off `~/.gemini/`, which
  was never Gemini-specific — just wherever the first harness registered it.

### Added

- **The system theme is now declared to running applications** (Standard
  §11.6.4, §11.6.5). `theme.nix` has re-themed this machine from one word for a
  long time, but only at *build* time: every terminal, both bars, the TTY and
  greetd get their colors baked into generated config, and
  `modules/theme/default.nix` exported per-role hex and never the slug. A
  program started afterwards could see individual colors and still not learn
  which theme was active, nor whether a high-contrast or mono sibling was in
  force. §11.6.5 makes closing that the OS's obligation.
  - `modules/theme/declaration.nix` (new) — options under `steelbore.theme.*`,
    rendering `/etc/steelbore/theme.toml`, exporting `SPACECRAFT_THEME`, and
    installing the advisory registry at `/etc/steelbore/themes.json`.
  - `environment.sessionVariables`, not `environment.variables`:
    `/etc/set-environment` is sourced by login shells but not by systemd user
    services or graphical `.desktop` launches, and §11.6.5 requires the export
    to reach graphical sessions.
  - The slug keeps exactly one source. `default.nix` sets
    `steelbore.theme.active = mkDefault steelborePalette.meta.slug` rather than
    re-importing `theme.nix`, so `theme try <slug>` — which deliberately builds
    a palette the file does not name — stays correct for free.
  - `lib/palette.nix` gains `meta.polarity`, `meta.pair` and a `resolution`
    attrset. `steelbore.toml` carries `[resolution.*]` only from 3.2.0 and the
    `construct` input is pinned, so the table is used when present and derived
    from the canvas otherwise. Verified against the currently pinned
    `construct`, which predates 3.2.0: the fallback yields identical answers, so
    nothing breaks in the window before `nix flake update construct`.
  - `flake.nix` hoists the theme registry into the outer `let` so `theme list`
    and `/etc/steelbore/themes.json` are one definition, and adds per-entry
    `polarity`/`pair` plus top-level `light`/`dark`.
  - `theme now <slug>` writes the per-user declaration, so §11.6-aware
    applications switch with **no rebuild** (§11.6.5's closing SHOULD).
    `theme now --clear` drops it.

### Fixed

- **The desktop was unconditionally dark regardless of the declared palette**
  (Standard §11.6.5). `color-scheme`, `gtk-theme`, `icon-theme` and the Qt style
  were hard-coded to their dark variants in `users/mj/desktop-theme.nix`, which
  was right for every palette except one: `steelbore-navywhite` is light-canvas
  (§11.3.4), so a NavyWhite system told toolkits `prefer-dark` — the precise
  inconsistency §11.6.5 forbids. Third-party applications read only the platform
  preference, so they rendered dark chrome around a light interface. All four now
  follow `steelborePalette.meta.polarity`.

- **`STEELBORE_THEME="true"` retired** from `home.nix` and
  `users/mj/shell.nix`. Nothing anywhere read it, and Standard §11.6.4 now names
  it as *not* a Standard interface — the theme variable carries a **slug**, so a
  boolean under a confusable name would make `STEELBORE_THEME=true` resolve to a
  theme that does not exist and fall through in silence. `PRD.md` documented it
  as `SPACECRAFT_THEME = true`, which matched neither the old code nor §11.6;
  corrected.

- **`reuse lint` passes again — 320/320, zero invalid expressions.** It had been
  failing at 316/319 with two invalid SPDX expressions, and the failure was
  invisible in normal use: `nix flake check --no-build` only *evaluates*
  `checks.reuse-lint`, so the derivation was never built and the gate never
  fired. Four causes, all pre-existing:
  - `pkgs/steelbore-niri-unmax/`'s `.gitignore` and `Cargo.lock` were missing
    from `REUSE.toml` — its sibling `steelbore-audio-led` and `bravais-mcp` were
    both listed, this package was simply never added.
  - `pkgs/steelbore-niri-unmax/Cargo.toml` carries an inline license tag but no
    copyright, and was missing from the stanza that supplies one.
  - `.github/skills/spacecraft-cli-standard/references/testing-compliance.md`
    quotes <!-- REUSE-IgnoreStart -->`rg -L 'SPDX-License-Identifier: …'`<!-- REUSE-IgnoreEnd --> in a compliance table, and REUSE
    reads to end of line, so it parsed the rest of the table cell as the file's
    license expression. Under the `closest` precedence that vendored tree uses,
    an invalid in-file expression beats `REUSE.toml`. Fixed with a **path-scoped**
    `precedence = "override"` rather than by editing the file (a synced copy —
    `REUSE-Ignore` comments would drift from upstream and be overwritten) and
    scoped to that one path rather than all of `.github/skills/**`, because a
    blanket override would flatten `microsoft-rust-guidelines`' upstream
    "GPL-3.0-or-later OR MIT" and credit the wrong holder (§4.2).
  - This changelog tripped the same scanner quirk in the entry that *documented*
    it; the quoted command is now wrapped in `REUSE-Ignore` markers.

  Also noted while fixing: `pkgs/steelbore-niri-unmax/src/main.rs` was passing
  only by accident — `main.rs` prints `Copyright (C) 2026 …` in its `--version`
  output and REUSE read that string as the file's copyright notice. It is now
  covered deliberately, so rewording a `println!` cannot silently break
  compliance.

- **`pkgs/update-vendored.nu` no longer abandons the run on the first
  failure.** `nix build` raising inside `update-one` propagated out through
  the `each` in `main`, so one broken package silently skipped every package
  after it in the list. This was not theoretical: claude-desktop 1.24012.11
  failed to build, and the other six packages were never attempted — the run
  looked like it had simply finished.
  - `nix build` is now `try { … ; true } catch { false }`, reporting
    `action: "build failed"` rather than raising.
  - Each package's dispatch in `main` is wrapped in its own `try`/`catch`, so
    an upstream 404, a moved release asset, or a prefetch timeout costs that
    one package instead of the rest of the list (`action: "error: …"`).
  - Failures are re-listed in a summary block after the table, because a bad
    row is easy to miss in an eight-row summary.
  - On a build failure the version/hash rewrite is deliberately **left in
    place**: the bump is nearly always correct and the packaging is what needs
    fixing, so the modified file is the starting point for that fix. The
    summary says so and points at `git diff`.
  - The script still exits zero; `rebuild`'s monthly `--check` nag depends on
    that. Revisit if this is ever wired into CI.

- **claude-desktop 1.24012.11 build failure.** Upstream renamed the desktop
  entry from `claude-desktop.desktop` to the reverse-DNS app ID
  `com.anthropic.Claude.desktop` (matching `StartupWMClass` so docks group
  windows correctly), and `installPhase` hardcoded the old path. The binary,
  icons and `Exec=` are unchanged. Now installed by glob
  (`install -Dm644 -t $out/share/applications usr/share/applications/*.desktop`)
  rather than re-hardcoding the new name, so the next rename cannot break the
  build either — nothing in this repo refers to the entry by filename.

- **Ollama's pinned version is no longer restated in five places.** The
  0.31.1 → 0.32.5 bump orphaned hardcoded version strings in
  `modules/services/ollama.nix`, `hosts/common.nix`, `modules/packages/ai.nix`,
  `PRD.md` and `TODO.md`. Rewritten to point at `pkgs/ollama/package.nix` as
  the single source of truth instead of naming a version that goes stale on
  every bump.

### Changed

- **Vendored binaries bumped** — ollama 0.31.1 → 0.32.5, goose-desktop
  1.43.0 → 1.45.0, opencode-desktop 1.18.4 → 1.18.12, github-copilot-app
  1.0.9 → 1.1.3, browseros 0.46.0 → 0.47.18, claude-desktop 1.18286.0 →
  1.24012.11. chrome-remote-desktop and adguardvpn-cli were already current.
  All build; the `bravais-thinkpad` toplevel builds with them.

### Added

- **Alpaca (`com.jeffser.Alpaca`, Flathub)** — GTK4/libadwaita GUI client for
  Ollama, GPL-3.0-or-later. It was already present in
  `modules/packages/flatpak.nix` but commented out under a note reading
  "DISABLED with Ollama", which had gone stale: the Ollama service is enabled
  again (`hosts/common.nix`, `steelbore.services.ollama.enable`). Flatpak
  rather than nixpkgs per the delivery policy — a sandbox-friendly GTK app
  Flathub ships ahead of the nixpkgs copy.
  - Operational note recorded in the module: Alpaca can manage its **own**
    bundled Ollama instance, but this host already runs one as a system
    service on `127.0.0.1:11434`. Point Alpaca at that instance rather than
    letting it start a second one — two servers compete for the same models
    and RAM.

- **AdGuard VPN CLI** (`pkgs/adguardvpn-cli/`, wired into
  `modules/packages/networking.nix`) — the inventory in `Packages.md` has
  listed it since the v0 rewrite, but it was never installed, and the note
  filing it under "available in nixpkgs" was wrong: neither 26.05 nor
  nixos-unstable package it. They ship `adguardhome` (a network-wide DNS
  blocker) and `adguardian` (a TUI for that), which are different products
  from the VPN client. So the official release tarball is vendored.
  - Unlike every other vendored binary here, this one needs **no
    `autoPatchelfHook` and no `buildInputs`** — upstream ships a fully static
    ELF, so it runs unmodified on NixOS. The derivation is an unpack plus two
    `install` calls. `dontStrip` is set so the shipped detached signature keeps
    matching the binary, and an `installCheckPhase` runs `--version` inside the
    sandbox (under a scratch `HOME`, since first run creates a data directory)
    to prove the static claim at build time rather than at first use.
  - Unfree (proprietary AdGuard EULA); `allowUnfree` is already set in
    `modules/core/nix.nix`, so no gate change was needed.
  - **TUN mode conflicts with `modules/core/dns.nix`.** It opens `/dev/net/tun`
    and rewrites `/etc/resolv.conf`, which systemd-resolved owns here while
    running DNS-over-TLS + DNSSEC — so a TUN connection displaces that
    encrypted resolver. `adguardvpn-cli config set-mode SOCKS` needs no
    privileges and leaves resolved alone. TUN mode needs `sudo`, or a
    `security.wrappers` entry granting `cap_net_admin`, because a store path
    cannot carry file capabilities.
  - The built-in `update` / `check-update` subcommands cannot write to the
    read-only store. `pkgs/update-vendored.nu` gains an eighth entry instead;
    its `up-github` helper grew optional `tag_pattern` / `strip_suffix`
    parameters because upstream tags read `v1.7.12-release` while the version
    string is `1.7.12`. Existing callers are unaffected — both parameters
    default to the previous behaviour.

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
  Construct bug, a table cell quoting <!-- REUSE-IgnoreStart -->`rg -L 'SPDX-License-Identifier: …'`<!-- REUSE-IgnoreEnd --> that
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
