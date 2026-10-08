# Bravais -- Product Requirements Document

**Project:** Bravais (A Steelbore OS NixOS Distribution)
**Version:** 3.2 | **Date:** 2026-09-28
**Author:** Mohamed Hammad | **License:** GPL-3.0-or-later
**Status:** Implemented on the reference machine — per-area status in §1.6

---

## 1. Executive Summary

Bravais is a flake-based NixOS configuration implementing the Spacecraft Software Standard. It delivers a complete, reproducible system with a modular, opt-in architecture supporting five desktop environments: GNOME (Wayland), COSMIC (Wayland), KDE Plasma 6 (Wayland), Niri (Wayland), and LeftWM (X11). All five are enabled together on purpose; `modules/desktops/assertions.nix` guards only the genuine invariants, not mutual exclusivity.

**Core Principles:**

- Memory-safe tooling preferred (Rust-first ecosystem)
- Opt-in modularity via `lib.mkEnableOption` in the `steelbore.*` namespace
- One theme word for the whole system: the Standard §11 palette family is resolved to Standard §11.1 **role tokens** (§2.2), so no consumer names a colour and switching palettes is one edit to `theme.nix`
- Registries instead of hardcoded choices: the active theme (`theme.nix`) and the default application per role (`default-apps.nix`, §2.6) are each one word, rewritten by the `theme` and `app` commands
- Dual-channel support (stable nixos-26.05 / unstable rolling), with the x86-64 march level pinned **per machine** in its host config rather than exploded into a build matrix (§2.4, §2.5)
- Every flake input is declared once in `flake.nix` with one comment each — nixpkgs and Home Manager for both channels, `nix-flatpak`, and first-party or forked inputs (§3.1)
- Terminals themed from role tokens through one source, `lib/terminal-theme.nix`, launching Nushell where the format allows it (§10)
- Declarative Flatpak management via nix-flatpak (§11.10)
- Podman (not Docker) with `dockerCompat`, and both Youki (Rust) and runc available as OCI runtimes (§12.1)
- `mjsh` (Operator, a Rust shell built on Nushell) as the user login shell; Brush (Rust, Bash-compatible) as root shell; the Bash module stays enabled (PAM and activation need it) but Bash is no one's login shell
- Agent skills delivered declaratively from the `construct` input through its Home Manager module (§16.2)
- Rebuilds driven by `preflight` (Rust, `pkgs/preflight/`), the supported rebuild orchestrator (§16.1)

### 1.1 Audience

- **The maintainer** — Bravais is first a daily-driver workstation: one person's machine, configured end to end and rebuilt from this tree.
- **Spacecraft Software developers** — a reference for how a Standard-conformant system looks in practice (role-token theming, Rust-first tooling, REUSE, agent skills).
- **Agents working in the repo** — `AGENTS.md` is their authoritative context; this PRD states what the system must be, not how to operate it (§1.5).
- **Forkers** — GPL-3.0-or-later, a personal hobby project with no warranty; PR acceptance is at the maintainer's discretion, and forking is encouraged when goals diverge (§16.7).

### 1.2 Scope and Supported Hardware

One reference machine today: a ThinkPad T490s-class laptop (Intel i7-8665U, Whiskey Lake), pinned to x86-64-v3 because the CPU has AVX2/BMI2/FMA but no AVX-512 (`hosts/thinkpad/default.nix`, §7.1.1, §7.3). It is built on both channels: `bravais-thinkpad` (stable 26.05), `bravais-thinkpad-unstable`, and the `bravais` alias for the stable build (§2.4).

**"Supported" means** the configuration builds (§17.1) and is switched and in daily use on that machine. Other hardware is untested. Adding a machine is a `hosts/<machine>/` directory carrying only genuinely per-machine settings plus two output lines in `flake.nix` (§2.3).

### 1.3 Principal Workflows

- **Rebuild** — `preflight`: bump the tracked inputs, GC, switch, then mirror to `/etc/nixos` and update Flatpaks detached (§16.1).
- **Switch theme** — `theme set <slug>` (persist), `theme try <slug>` (live, reverts at the next rebuild), `theme now <slug>` (Standard §11.6-aware apps, no rebuild) (§2.2, §16.3).
- **Change a default app** — `app set <role> <slug>` rewrites `default-apps.nix` (§2.6, §16.3).
- **Sync agent skills** — `skills-sync` moves the skill pointer ahead of a rebuild; follow with `nu pkgs/sync-skills.nu` (§16.2).
- **Bump vendored binaries** — `nu pkgs/update-vendored.nu` or `preflight --update-vendored`; never by hand (§16.4).
- **Add a package** — the matching `modules/packages/*.nix`, Rust preferred, with a language comment; then update this PRD's inventory and `TODO.md` (§11).

### 1.4 Non-Goals

- **Not a general-purpose, multi-user distribution.** The flake exports per-machine `nixosConfigurations`, `themeSystems`, `packages`, `checks`, `devShells` and a formatter — no installer ISO — and one `primaryUser` owns the Home Manager configuration (§7.2, §13).
- **No per-level build matrix.** The march level is a per-host pin; no v1–v4 set of `nixosConfigurations` is enumerated (the level flags themselves remain in §6.2).
- **No pick-one desktop.** All five desktops ship together; no third-party desktop flakes are used — every desktop comes from nixpkgs (§3.1, §9).
- **No Docker.** Podman with the `docker` compatibility alias covers it (§12.1).
- **No C `sudo`, no Bash login shell.** `sudo-rs` replaces `sudo` (§5.5); Bash stays enabled only for PAM and activation (CONSTRAINTS.md #1, #2).
- **No self-updating vendored binaries.** Pinned upstream packages are bumped declaratively (§16.4); the out-of-band agent CLIs of CONSTRAINTS.md #4 are the named exception.

### 1.5 Requirements Conventions

This PRD states requirements and the design decisions behind them, with enough "why" to keep them from being undone. Long-form operations — command chains, diagnostics, measured costs, trap histories — live in `docs/*.md`, `CONSTRAINTS.md` and `AGENTS.md`, which are the sources of truth for those topics; the map is §16.6. Where the two disagree, fix whichever is stale rather than copying one into the other.

### 1.6 Status

**Verified** = a check that has passed, recorded with its date and commit — a `checks.x86_64-linux` output run per §17.1, or a CI workflow. **Implemented** = present in the configuration and building; runtime validation is recorded separately (the Evidence column, `TODO.md` Phase 10). **Planned** = an open item.

| Area | Status | Evidence |
|------|--------|----------|
| Stable system build (§2.4, §17.1) | Verified | `bravais-thinkpad` toplevel built at `343510b` (nixpkgs `5e2305d`), 2026-09-28 — run manually per §17.1; not in CI |
| Unstable evaluation (§2.4, §17.1) | Verified (evaluation only) | `bravais-thinkpad-unstable` `drvPath` evaluated at `343510b` (nixpkgs-unstable `e158d9e`), 2026-09-28. This proves the configuration evaluates, not that it builds; a full unstable build is not part of the gate |
| REUSE / SPDX compliance (§17.3) | Verified | `checks.reuse-lint`; `.github/workflows/reuse.yml` on push and PR |
| LF line endings | Verified | `.github/workflows/text-file-format.yml` |
| Niri configuration (§9.4) | Verified | `checks.niri-config` (`niri validate` on the rendered `config.kdl`) passed at `343510b`, 2026-09-28 — run manually per §17.1; not in CI |
| `.github/skills/` Copilot copy (§16.2) | Verified | `.github/workflows/skills-drift.yml` runs `sync-skills.nu --check` |
| Skills delivery via Home Manager (§16.2) | Implemented | `spacecraft.construct` in `users/mj/home.nix`; `docs/skill-pointer.md` |
| Rebuild orchestrator `preflight` (§16.1) | Implemented | in daily use; its unit tests run at build time (`pkgs/preflight/`), but no `checks.*` output or CI workflow gates it |
| Role-token theming and theme registry (§2.2, §4, §16.3) | Implemented | `lib/palette.nix`, `theme.nix`, `themeSystems` |
| Default-application registry (§2.6) | Implemented | `lib/default-apps.nix`, `default-apps.nix` |
| Desktop sessions and login (§8, §9) | Implemented | GNOME, COSMIC, Plasma boots checked by hand; Niri partial ([~]); LeftWM unchecked (TODO Phase 10) |
| Terminals (§10) | Implemented | `lib/terminal-theme.nix`; per-terminal palette check partial (TODO Phase 10) |
| Security: sudo-rs, keyring, fingerprint (§5.5, §5.6, §6.1) | Implemented | fingerprint verified by hand; sudo-rs check open (TODO Phase 10) |
| Containers: Podman, AppImage (§12.1, §12.4) | Implemented | `docker` alias and AppImage binfmt checks open (TODO Phase 10) |
| Vendored upstream binaries (§16.4) | Implemented | `pkgs/update-vendored.nu` |
| Boot splash and startup sound (§5.2) | Implemented | builds and fits the ESP budget (CONSTRAINTS.md #43); not yet seen on a real boot (TODO Phase 10) |
| Secure Boot (§11.4) | Planned | `sbctl` installed (`modules/packages/security.nix`); key enrollment open in TODO.md Phase 6 |
| Waydroid (§12.7) | Planned | `waydroid init`, Niri start and APK install open (TODO.md) |
| KDE Connect pairing | Planned | firewall ports 1714–1764 and daemon choice open (TODO.md) |
| `gitway biometric` enrollment | Planned | open in TODO.md, after a healthy login keyring |
| Obscura MCP entry for Claude Code (§11.9) | Planned | the one host `mcpctl deploy` could not write (TODO.md) |
| Bitwarden browser-extension bridge (§11.4) | Planned | host browser vs `--filesystem=/nix/store:ro` vs desktop-only biometrics — open in TODO.md |

---

## 2. Architecture Overview

### 2.1 Directory Structure

```text
bravais/
+-- flake.nix, flake.lock          # Flake entry point (inputs, mkBravais, outputs); pinned deps
+-- theme.nix                      # THE ACTIVE THEME — one word; `theme set <slug>` (§2.2)
+-- themes/<slug>.nix              # Local themes (filename = slug)
+-- default-apps.nix               # THE ACTIVE HANDLERS — one word per role (§2.6)
+-- apps/<slug>.nix                # App drop-ins (filename = slug); may shadow a built-in
+-- lib/                           # builtins-level helper libraries
|   +-- palette.nix                # Standard §11 palette family: slug -> role tokens (§2.2)
|   +-- theme-assets.nix           # active slug -> the Theme repo's generated files
|   +-- default-apps.nix           # handler roles -> MIME lists, app catalog, resolver (§2.6)
|   +-- terminal-theme.nix         # terminal theme record + per-format emitters
+-- hosts/                         # Machine configurations
|   +-- common.nix                 # Shared by every machine: networking, X11/XKB, shells, steelbore.* toggles
|   +-- thinkpad/                  # ThinkPad (i7-8665U, Whiskey Lake)
|       +-- default.nix            # hostName, steelbore.hardware.*, CRD (off), Waydroid, march pin (v3)
|       +-- hardware.nix           # Hardware configuration (generated)
+-- modules/                       # NixOS modules (steelbore.* namespace)
|   +-- core/                      # Always-enabled: boot, memory, nix (the sole overlay location),
|   |                              #   nix-tmp (builder TMPDIR, CONSTRAINTS.md #28), locale, audio,
|   |                              #   security (sudo-rs, polkit, PAM), keyring, dns (DoT + DNSSEC)
|   +-- theme/                     # default (SPACECRAFT_* env, TTY colours), fonts, dark-mode,
|   |                              #   declaration (Standard §11.6.4 /etc/steelbore/theme.toml),
|   |                              #   boot-splash (Plymouth, §5.2; ESP budget CONSTRAINTS.md #43)
|   +-- hardware/                  # android, audio-led, bluetooth, fingerprint (explicit PAM policy), intel
|   +-- platform/x86-64.nix        # ISA level (v1–v4 enum) + compiler/linker flags
|   +-- desktops/                  # gnome, cosmic, cosmic-unmax, plasma, niri (eww bar + dunst),
|   |                              #   niri-unmax, leftwm (eww bar, X11), shared (bare-WM services),
|   |                              #   mouse-workspace-nav (xremap), assertions
|   +-- login/default.nix          # greetd + tuigreet + shell sessions
|   +-- services/                  # adguardvpn, chrome-remote-desktop, ollama, podman, waydroid
|   +-- compat/appimage.nix        # AppImage auto-run via binfmt
|   +-- packages/                  # Opt-in bundles: browsers, terminals, editors, development, security,
|                                  #   networking, multimedia, productivity, system, ai, games, orca,
|                                  #   flatpak, homebrew (distrobox escape hatch)
+-- users/mj/                      # primaryUser: default.nix (account, mjsh login shell),
|                                  #   home.nix (identity + imports), one-concern HM modules;
|                                  #   default-apps.nix holds the only xdg.mimeApps block;
|                                  #   rebuild.nu (deprecated in favour of preflight)
+-- pkgs/                          # In-tree packages; default.nix is the index (also packages.*)
|   +-- preflight/                 # Rust rebuild orchestrator (§16)
|   +-- steelbore-*/               # First-party Rust tools (audio-led, beacon, niri-unmax, cosmic-unmax, vpn, quantize)
|   +-- steelbore-plymouth/        # Plymouth theme: assets/boot/splash.png, quantized by steelbore-quantize
|   +-- <vendored>/                # Version+hash-pinned upstream binaries (docs/vendored-binaries.md)
|   +-- update-vendored.nu, sync-skills.nu   # vendored bumper; .github/skills/ regenerator
+-- assets/boot/                   # Boot media (CC-BY-SA-4.0): splash.png, startup-sound.mp3 (§5.2)
+-- bravais-mcp/                   # Source of the Rust MCP server built by pkgs/bravais-mcp/
+-- flakes/rapg/                   # Wrapper flake for rapg (upstream ships none)
+-- scripts/rebuild.sh             # POSIX port of `rebuild` (deprecated in favour of preflight)
+-- docs/                          # Long form of AGENTS.md sections
+-- AGENTS.md, CONSTRAINTS.md      # Agent context; long form of the numbered constraints
```

Overlays are defined inline in `modules/core/nix.nix` — the sole location.
Root-level `home.nix`, `system.nix`, `ARCHITECTURE.md`, `BRAVAIS.md`,
`USER_MANUAL.md`, `implementation_plan.md`, `PackagesMissing.md` and `v0.zip`
are legacy v0 artifacts; nothing in the flake imports them.

### 2.2 Module Design Pattern

All modules use the `steelbore.*` namespace with `lib.mkEnableOption`:

```nix
{ config, lib, pkgs, ... }:
{
  options.steelbore.desktops.niri = {
    enable = lib.mkEnableOption "Niri scrolling tiling compositor (Wayland)";
  };

  config = lib.mkIf config.steelbore.desktops.niri.enable {
    # Module implementation
  };
}
```

`mkBravais` imports every module directory plus `users/mj/default.nix` into
every configuration; the host decides what is switched on. Flake-input packages
and shared values (`steelborePalette`, `themeAssets`, `steelboreApps`,
`primaryUser`, `unstablePkgs`, …) reach modules through `specialArgs` and Home
Manager through `extraSpecialArgs` — never overlays (CONSTRAINTS.md #7).
`primaryUser = "mj"` is stated once in `flake.nix`; modules use
`users.users.${primaryUser}`, never a literal name.

Standard §11 is a *family* of adoptable palettes, not one palette (`theme list`
shows the set). `lib/palette.nix` selects a member by slug and resolves it to
the Standard §11.1 role tokens, threaded as `steelborePalette`. Consumers name
roles only — no brand colour name appears in any consumer, which is what makes
the palette swappable:

```nix
{ active = "steelbore"; }   # theme.nix — switches the entire system
```

The active theme lives in `theme.nix` at the repo root, not in `flake.nix`, so
the one word that re-themes the machine is not buried in build machinery.
Local themes go in `themes/<slug>.nix` and either derive from a registered
palette via `base` or bind the roles outright; a local slug shadows a registered
one. Every selectable theme also gets a buildable system at
`themeSystems.<system>.<slug>` (what `theme try` uses). It is deliberately not a
`nixosConfigurations` entry: `nix flake check` force-evaluates every one of
those, and fifteen full-system variants OOM-killed the evaluator; as a
non-standard output they stay lazy. The `theme-registry` output resolves every
theme to JSON for the `theme` command and evaluates only the palette library,
never a system config. `modules/theme/declaration.nix` publishes the selection
as `/etc/steelbore/theme.toml` and `SPACECRAFT_THEME` (Standard §11.6.4).

Values are read from `steelbore.toml` in the `construct` input, never retyped
(Standard §11.4). Palettes bind different role sets, so omitted roles resolve
through the fallback chain in §4.1. Unknown
slugs, Standard §11.5 fidelity palettes, `steelbore-mono` and malformed local
themes are rejected at eval time with a message naming the fix.
**`surface` / `surfaceAlt` are fills only, never text** (Standard §11.0.1),
which is why the eww bar and dunst stay on the `background` canvas.

Two rendering paths exist, on purpose: Bravais renders terminals, bars, WMs,
the TTY and greetd from role tokens (serving local themes too), while
`lib/theme-assets.nix` supplies the Theme repository's generated files for
formats Bravais never rendered (editor themes, GTK/KDE colours, Starship,
Nushell). Each asset is `null` for a local theme and consumers fall back to the
token path or toolkit default; `theme` is bumped with `construct` so both agree.
Details: AGENTS.md, Architecture.

### 2.3 Host Configuration Pattern

Toggles that describe the shared software set live in `hosts/common.nix`:

```nix
steelbore = {
  desktops = { gnome.enable = true; cosmic.enable = true; cosmicUnmax.enable = true;
               plasma.enable = true; niri.enable = true; niriUnmax.enable = true;
               leftwm.enable = true; mouseWorkspaceNav.enable = true; };

  # packages.<bundle>.enable = true for every bundle in modules/packages/, plus:
  packages.games = { enable = true; steam.enable = true;
                     wine.enable = false; };   # explicit OFF: large download, flip when wanted

  services.adguardvpn = { enable = true; routeScript.enable = true; };
  services.podman.enable = true;
  services.ollama.enable = true;
  compat.appimage.enable = true;
};
```

Only what is genuinely per-machine goes in `hosts/<machine>/default.nix` — for
the ThinkPad: `networking.hostName`, `steelbore.hardware.*` (android, audioLed,
bluetooth, fingerprint, intel), the TrackPoint exclusion for mouse workspace
navigation, Waydroid, Chrome Remote Desktop, and
`steelbore.platform.x86_64 = { enable = true; marchLevel = "v3"; }`.

`hosts/common.nix` also sets the machine-agnostic base (NetworkManager, X11 with
a `us,ara` XKB layout, printing, Brush as root's shell, `stateVersion = "26.05"`).

### 2.4 Dual-Channel Design

Bravais supports two nixpkgs channels, selectable per build via `mkBravais { channel = …; }`:

| Channel    | nixpkgs Branch    | Home Manager Branch           | Stability |
|------------|-------------------|-------------------------------|-----------|
| `stable`   | `nixos-26.05`     | `release-26.05`               | Tested    |
| `unstable` | `nixos-unstable`  | default branch (follows nixpkgs-unstable) | Rolling   |

Independently of the channel, every configuration also receives `unstablePkgs`
(`nixpkgs-unstable` with `allowUnfree`) for packages that are unstable-only on
26.05 or lag upstream. Package names that differ between channels use the `or`
fallback (CONSTRAINTS.md #5; the `gcr_3 or gcr` order is load-bearing, #32).

### 2.5 Microarchitecture Profiles

`nixosConfigurations` are generated **per physical machine** (stable + unstable each).
The x86-64 march level is pinned in each machine's host config, not exploded into a matrix:

| Configuration               | Machine                            | Channel  | March                          |
|-----------------------------|------------------------------------|----------|--------------------------------|
| `bravais-thinkpad`          | ThinkPad (i7-8665U, Whiskey Lake)  | stable   | v3 (AVX2; CPU has no AVX-512)  |
| `bravais-thinkpad-unstable` | ThinkPad                           | unstable | v3                             |
| `bravais` (alias)           | → `bravais-thinkpad` (stable)      | stable   | v3                             |

`modules/platform/x86-64.nix` supports `v1`…`v4` as an enum; a machine picks one.
The alias points at the existing attribute, so it costs no second evaluation.

Adding a machine = drop a `hosts/<machine>/` directory (importing `hosts/common.nix`
and its own `hardware.nix`, §2.3) + two output lines in `flake.nix`.

`checks.x86_64-linux` holds both toplevels plus the fast `niri-config` and
`reuse-lint` checks. `nix flake check` is not a usable gate
(CONSTRAINTS.md #17); the Verification Plan (§17) uses the stable toplevel build, the unstable
`drvPath` eval and the two fast checks instead.

### 2.6 Default Applications

Which program handles what is a registry, shaped like the palette family in §2.2
and for the same reason: the active choice is one word, no consumer names an
application, and switching is a single edit.

```nix
{ editor = "cosmic-edit"; browser = "chrome"; fileManager = "cosmic-files";
  imageViewer = "oculante"; termEditor = "msedit"; }   # default-apps.nix
```

`lib/default-apps.nix` — builtins-only, like `lib/palette.nix`, so it never
drags in a system config — defines five **handler roles** and resolves each to a
catalog entry, threaded as `steelboreApps`. `users/mj/default-apps.nix` is the
only consumer, and holds the only `xdg.mimeApps` block in the tree.

| Role | Drives |
|---|---|
| `editor` | Text MIME types — what double-clicking a text file opens |
| `browser` | `text/html`, `application/xhtml+xml`, `x-scheme-handler/*`, and `$BROWSER` |
| `fileManager` | `inode/directory` **and** the `org.freedesktop.FileManager1` D-Bus name, which "Show in folder" resolves instead |
| `imageViewer` | Image types incl. PSD, EXR and camera RAW formats |
| `termEditor` | `$EDITOR`, `$VISUAL`, the `edit` alias, `git core.editor`. Binds no MIME types |

**The role owns the MIME list, not the application** (CONSTRAINTS.md #22). An
application's own `MimeType=` line is not a reliable statement of what it can
open: a zero-byte file is `application/x-zerosize`, which is *not* a subclass of
`text/plain`, so an editor declaring only `text/plain` left new empty files to
desktop-entry cache ordering. Binding the role's complete list wholesale removes
that class of hole; an entry may *narrow* the list (`loupe`, `feh`), never widen it.

Selection errors (unknown slug, role mismatch, missing selection, malformed
drop-in, doubly-claimed MIME type) fail at evaluation, naming the fix.

Applications not in nixpkgs join through `apps/<slug>.nix`, which shadows the
built-in catalog exactly as `themes/<slug>.nix` shadows a registered palette; a
drop-in that supplies `package` installs itself while active. The pkgs-free
`app-registry` output feeds the `app` command, so `app list` is instant. Usage:
the `default-apps` skill and `apps/README.md`.

---

## 3. Flake Configuration

### 3.1 Inputs

Every active input declared in `flake.nix` (commented-out inputs — `adit`, `kimi-cli` — are omitted; each carries its own re-enable steps in `flake.nix`).

| Input                    | URL                                                    | Follows            | Purpose |
|--------------------------|--------------------------------------------------------|--------------------|---------|
| `nixpkgs`                | `github:nixos/nixpkgs/nixos-26.05`                     | --                 | Stable channel |
| `home-manager`           | `github:nix-community/home-manager/release-26.05`      | `nixpkgs`          | Stable Home Manager |
| `nixpkgs-unstable`       | `github:nixos/nixpkgs/nixos-unstable`                  | --                 | Unstable channel; also the `unstablePkgs` instance |
| `home-manager-unstable`  | `github:nix-community/home-manager`                    | `nixpkgs-unstable` | Unstable Home Manager |
| `nix-flatpak`            | `github:gmodena/nix-flatpak`                           | --                 | Declarative Flatpak management |
| `gitway`                 | `github:Spacecraft-Software/Gitway` (tracks `main`)    | `nixpkgs-unstable` | SSH transport for Git; its NixOS module is imported |
| `construct`              | `github:Spacecraft-Software/Construct` (tracks `main`) | `nixpkgs-unstable` | Agent skill catalogue **and** the canonical `steelbore.toml` the palette is read from |
| `theme`                  | `github:Spacecraft-Software/Theme` (`flake = false`)   | --                 | Generated per-platform theme files, consumed by path through `lib/theme-assets.nix`; bump together with `construct` |
| `rapg`                   | `path:./flakes/rapg` (wrapper flake)                   | `nixpkgs-unstable` | Local-first secret manager (upstream has no flake) |
| `antigravity-nix`        | `github:UnbreakableMJ/antigravity-nix`                 | `nixpkgs-unstable` | Antigravity IDE package (pin lives upstream — CONSTRAINTS.md #27) |
| `nil`                    | `github:UnbreakableMJ/nil`                             | `nixpkgs-unstable` | Nix language server (fork; outputs identical to upstream) |
| `mcp-servers`            | `github:Spacecraft-Software/mcp-servers`               | `nixpkgs-unstable` | `mcpctl` — generates and deploys each MCP host's config |
| `vacuum`                 | `github:Spacecraft-Software/Vacuum`                    | `nixpkgs-unstable` | Disk-space recovery CLI + TUI (binary only; config in `users/mj/apps.nix`) |
| `engram`                 | `github:Spacecraft-Software/Engram`                    | `nixpkgs-unstable` | Shared chat memory (CLI + MCP server), resolved by bare name on PATH (CONSTRAINTS.md #23) |
| `pathfinder`             | `github:Spacecraft-Software/Pathfinder`                | `nixpkgs`          | jq-compatible shim over jaq; follows stable so its pinned jaq (3.1.0) is the CI-tested engine |

**Why `github:` rather than local `git+file://` / `path:` for first-party inputs:** a `path:` input is content-addressed and drifts its NAR hash on every source edit (CONSTRAINTS.md #10), and a `git+file:///spacecraft-software/…` URL resolves on exactly one machine — CI, a fresh clone and the Copilot coding agent could not evaluate the flake. The consequence is that `github:` sees **pushed** content only: a change to `mcp-servers`, `vacuum` or `engram` must be committed *and* pushed before `nix flake update <input>` can pick it up.

**`vacuum` ships the binary only.** Its own `nixosModules.default` is deliberately not imported: that module only adds the binary to `environment.systemPackages`, which would separate the binary from the per-user `roots` list that bounds its deletions.

**`nil` is overridden in `flake.nix`:** `doCheck = false` (upstream builtins-doc test is broken, CONSTRAINTS.md #13) and `CFG_DEFAULT_FORMATTER` is repointed at canonical `nixfmt`, so evaluating any configuration that installs nil no longer prints the `nixfmt-rfc-style` deprecation warning.

### 3.2 Steelbore Palette Resolution

The palette is **not** defined in `flake.nix`. Registered palette values are imported from `steelbore.toml`, never retyped (Standard §11.4), and consumers use role tokens only. No colour value is typed in Bravais: none ships in `themes/`, and the curated xterm-256 indices in `lib/palette.nix` are keyed by Steelbore Classic's roles, with their hex keys read from the TOML. A local theme (step 2) is the one sanctioned place a hand-written value could appear, and it would sit outside the verified contrast matrices. The pipeline:

1. **Selection** — `theme.nix` at the repo root holds one word, `active = "<slug>"` (currently `steelbore`, Steelbore Modern). `theme set <slug>` rewrites it; `theme try <slug>` builds a theme without editing it; `theme list` shows every selectable theme.
2. **Local themes** — `flake.nix` collects every `themes/<slug>.nix` (optional directory; filename = slug) into `localThemes`. A local theme either derives from a registered palette via `base = "<slug>"` or binds its roles outright; a local theme may shadow a registered palette of the same name.
3. **Resolution** — `lib/palette.nix` is called with `tomlFile = "${construct}/steelbore-color-palette/assets/steelbore.toml"`, the slug and `localThemes`. It reads the canonical TOML from the `construct` input (so an upstream palette fix arrives with `nix flake update construct`), validates the slug (unknown slugs, Standard §11.5 fidelity palettes and `steelbore-mono` fail at evaluation time with a message naming the fix) and returns:
   - the twelve Standard §11.1 **role tokens** — `background`, `surface`, `surfaceAlt`, `foreground`, `accent`, `structure`, `success`, `error`, `warning`, `info`, `focus`, `border`, with fallbacks for roles a palette omits;
   - `ansi` — the 16-colour mapping (§4.2);
   - `convert` — notation converters (`bareHex`, `rgbTriple`, `srgbaFloat`, `srgbaChannels`, per-role `x256`) so no consumer ever restates a value in another notation;
   - `counterpart` — the `pair` palette, resolved the same way, for a consumer that renders both polarities (COSMIC's Light Builder, §9.2);
   - `meta` (`slug`, `version`, `family`, `hasSurfaceClass`, `polarity`, `pair`) and `resolution` (the Standard §11.6 env-var name and file paths — slugs and paths only, never colours).
4. **Threading** — `mkBravais` binds the result as `steelborePalette` and passes it to every NixOS module via `specialArgs` and to Home Manager via `extraSpecialArgs`. Consumers name roles only; **never a brand colour**, which is what makes switching palettes a one-word edit.
5. **Theme repository assets** — `lib/theme-assets.nix` maps the same slug to the `theme` input's generated files and is threaded as `themeAssets`. Per-slug attributes (`starship`, `nushell`, `gtk4Css`, `gtk3Css`, `kde`, `claudeCode`) are store paths for a registered palette and `null` for a local theme, so every consumer falls back to the token path (Starship, Nushell) or the toolkit default (GTK, KDE). Family-wide attributes (`zedFamily`, `lapceThemes`, `vscodeExtension`, `antigravityExtension`, `kdeSchemes`) install every theme, because editors keep their own pickers.
6. **Registry** — `flake.nix` also renders every selectable theme, resolved, into `themeRegistry` (a JSON file). It is exposed as `packages.x86_64-linux.theme-registry` (what `theme list` reads — it evaluates only the palette library, never a system config) and installed at `/etc/steelbore/themes.json` by `modules/theme/declaration.nix`.

### 3.3 mkBravais Function

```nix
mkBravais = { host, channel ? "stable", palette ? defaultPalette }: ...
```

- `host` is a machine path from the `hosts` map in `flake.nix` — currently only `thinkpad = ./hosts/thinkpad`. Each host module imports `hosts/common.nix` plus its own `hosts/<machine>/hardware.nix` (for the ThinkPad, `hosts/thinkpad/hardware.nix`).
- `channel` selects the nixpkgs + home-manager pair: `stable` → `nixpkgs` / `home-manager`, `unstable` → `nixpkgs-unstable` / `home-manager-unstable`.
- `palette` defaults to the slug in `theme.nix`; it is overridden only by the per-theme `themeSystems` output that `theme try` builds.
- The march level is **not** a parameter — it is pinned inside the host config via `steelbore.platform.x86_64.marchLevel` (ThinkPad = `v3`). The option itself accepts `v1`–`v4` and defaults to `v2`, but there is no v1–v4 build matrix.
- Instantiates `unstablePkgs` from `nixpkgs-unstable` with `config.allowUnfree = true` (the system's `nixpkgs.config.allowUnfree` does not reach a separate evaluation) and a `nixfmt-rfc-style = nixfmt` overlay.
- **`specialArgs`** (NixOS modules): `steelborePalette`, `themeAssets`, `themeRegistry`, `steelboreApps`, `primaryUser`, `gitway`, `construct`, `rapg`, `unstablePkgs`, `antigravity-nix`, `nil`, `mcp-servers`, `pathfinder`.
- **Module load order:** external (`home-manager` of the selected channel, `nix-flatpak`, `gitway.nixosModules.default`), then `host`, `modules/core`, `modules/theme`, `modules/hardware`, `modules/platform`, `modules/desktops`, `modules/login`, `modules/services`, `modules/compat`, `modules/packages`, then `users/mj/default.nix` (the system user account), then the Home Manager block.
- **Home Manager:** `useGlobalPkgs = true`, `useUserPackages = true`, `backupFileExtension = "backup"`, `home-manager.users.${primaryUser} = import ./users/mj/home.nix`. **`extraSpecialArgs`**: `steelborePalette`, `themeAssets`, `steelboreApps`, `primaryUser`, `gitway`, `construct`, `constructSkills`, `rapg`, `unstablePkgs`, `antigravity-nix`, `nil`, `mcp-servers`, `vacuum`, `engram`, `pathfinder`.
- `primaryUser = "mj"` is stated once in `flake.nix`; `steelboreApps` is `lib/default-apps.nix` applied to the one-word-per-role selection in `default-apps.nix` plus any `apps/<slug>.nix` drop-ins.
- `constructSkills` is bound **once** and handed to both `packages.skills` and Home Manager, because three nixpkgs instantiations would otherwise give three store paths for a byte-identical skill tree and the drift probe would report drift forever.

**Outputs built from it:** `nixosConfigurations.bravais-thinkpad` (stable), `bravais-thinkpad-unstable`, and `bravais` — an alias that points at the `bravais-thinkpad` attribute rather than calling `mkBravais` again (an identical second call is a full duplicate evaluation). `themeSystems.x86_64-linux.<slug>` holds one buildable toplevel per selectable theme; it is deliberately **not** in `nixosConfigurations`, because `nix flake check` force-evaluates every entry there and holding all theme variants in one evaluator was OOM-killed.

**All flake outputs** (`flake.nix`, `x86_64-linux`):

| Output | Contents |
|--------|----------|
| `nixosConfigurations` | `bravais-thinkpad`, `bravais-thinkpad-unstable`, `bravais` (alias) |
| `themeSystems.<slug>` | One toplevel per selectable theme — what `theme try` builds |
| `packages.*` | The `pkgs/default.nix` index (`nix build .#<name>`), plus `theme-registry`, `app-registry` and `skills` |
| `checks` | `bravais-thinkpad` and `bravais-thinkpad-unstable` toplevels, `niri-config` (`niri validate` over the rendered KDL), `reuse-lint` |
| `devShells.android` | Android SDK, JDK 17, Gradle (§6.0); enter with `nix develop .#android -c nu` |
| `devShells.default` | nil, nixfmt, statix, deadnix |
| `formatter` | nixfmt — what `nix fmt` runs |

### 3.4 Overlays

Defined inline in `modules/core/nix.nix` via `nixpkgs.overlays` (the sole
location — the former `overlays/` reference copy was removed as dead code).

**sequoia-wot:** Disables failing tests (`doCheck = false`).

**cosmic-comp:** A `substituteInPlace` with two single-line `--replace-fail` substitutions on cosmic-comp's own `src/input/mod.rs` (upstream source, not a Bravais file) makes a 3-finger touchpad swipe switch workspaces under COSMIC (sharing the 4-finger arm rather than replacing it: the `3 => None` TODO arm is deleted first, then `4 => {` becomes `3 | 4 => {`), matching niri. Neither compositor exposes a finger count in configuration, so parity needs a source patch; patching cosmic-comp's unused 3-finger TODO arm loses nothing, whereas moving niri to 4 fingers would collide with its Overview gesture. `--replace-fail` is deliberate — if upstream fills in the TODO the build fails loudly instead of silently reverting. It costs a from-source build of a large Rust package and requires `doCheck = false` because `checkPhase` exhausts memory — rather than capping build parallelism (CONSTRAINTS.md #35).

**nixfmt-rfc-style:** Aliased to `prev.nixfmt` so the nixpkgs deprecation warning never fires when a flake input (gitway) still references the old name; Bravais itself uses `nixfmt` everywhere.

**claude-code:** No longer overlaid. The npm-pinning overlay was dropped;
claude-code is installed out-of-band via the official installer (see
`CONSTRAINTS.md` #4), with a commented-out `claude-code` entry in the
`with unstablePkgs;` list of `modules/packages/ai.nix` as the re-enable path.

**bash→brush (not implemented):** Replacing `pkgs.bash` via a nixpkgs overlay is architecturally infeasible — every nixpkgs derivation uses `final.bash` as its build shell via stdenv, creating an unavoidable bootstrapping cycle (CONSTRAINTS.md #1). Bash is excluded from all login shell assignments; users get Nushell and root gets Brush.

---

## 4. Steelbore Visual Identity

### 4.1 Color Palette

Standard §11 is a **family** of adoptable palettes, not one palette; `theme list` (or `lib/palette.nix`'s `meta.family`) names every selectable member, including each `<slug>-high-contrast` sibling (Standard §11.1.1) and any local theme. The active member is the slug in `theme.nix` (currently `steelbore`, Steelbore Modern). **Palette values live only in `steelbore.toml` in the `construct` input** (a local theme could bind its own, §3.2; none ships) — this document, like every module, refers to Standard §11.1 role tokens and never to a brand colour or hex value.

| Role          | Usage                                                                 | Fallback when the palette omits it |
|---------------|-----------------------------------------------------------------------|------------------------------------|
| `background`  | Canvas for every surface; ANSI black                                  | required                           |
| `surface`     | Elevated panel fill — **fill only, never text** (Standard §11.0.1)             | `background`                       |
| `surfaceAlt`  | Secondary panel fill — **fill only, never text**                      | `surface`                          |
| `foreground`  | Primary text / active readout; ANSI white                             | required                           |
| `accent`      | Primary accent; terminal selection background                         | required                           |
| `structure`   | Links, borders, structural chrome; ANSI bright black ("dim text")     | `accent`                           |
| `success`     | Success / safe status; ANSI green                                     | required                           |
| `error`       | Error status; ANSI red                                                | required                           |
| `warning`     | Warning status                                                        | `error`                            |
| `info`        | Informational status                                                  | `structure`                        |
| `focus`       | Focus indication                                                      | `success`                          |
| `border`      | Borders                                                               | `structure`                        |

"Required" is the set a local theme without `base` must bind (`lib/palette.nix` rejects it otherwise). Steelbore Classic binds only its legacy six tokens and defines no surface class, so `meta.hasSurfaceClass` lets a consumer test for a genuinely distinct panel fill.

**Surfaces are fills only.** Putting status-coloured text on a surface drops `structure` and `error` below the 4.5:1 AA floor on Modern, which is why the eww bar and dunst deliberately stay on the `background` canvas.

### 4.2 16-Color Terminal Palette Mapping

Single-sourced as `steelborePalette.ansi` in `lib/palette.nix` and consumed by both every terminal emulator (`lib/terminal-theme.nix`) and the TTY console (`modules/theme/default.nix`), which used to carry duplicate copies.

| Index | Slot    | Normal (0–7)                  | Bright (8–15)                 |
|-------|---------|-------------------------------|-------------------------------|
| 0     | Black   | `background`                  | `structure`                   |
| 1     | Red     | `error`                       | `error`                       |
| 2     | Green   | `success`                     | `success`                     |
| 3     | Yellow  | nearest hue to 60°            | nearest hue to 60°            |
| 4     | Blue    | nearest hue to 240°           | nearest hue to 240°           |
| 5     | Magenta | nearest hue to 300°           | nearest hue to 300°           |
| 6     | Cyan    | nearest hue to 180°           | nearest hue to 180°           |
| 7     | White   | `foreground`                  | `foreground`                  |

**Why hue-matched rather than a fixed role table:** ANSI slots are named by hue, role tokens by function, and the two do not correspond across palettes (one palette's `accent` is blue, another's orange), so any fixed role→slot table is correct for exactly one palette. Red and green are pinned to `error` and `success` because every terminal reads them as status; the other four colour slots take whichever candidate among `accent`, `structure`, `warning`, `info`, `focus` and `foreground` sits nearest the canonical hue. Candidates with chroma below 80 (near-neutrals) and any role that fell back onto `error` or `success` are excluded, so a neutral foreground cannot win a colour slot and yellow cannot collapse into green. Slots may still coincide where a palette genuinely lacks a hue; nothing is collapsed by hand.

**Why bright black is `structure`:** it is the conventional dim-text slot (comments, inactive UI) and must stay legible; `surface` is forbidden as a text colour (Standard §11.0.1).

Other fixed terminal fields in `lib/terminal-theme.nix`: cursor = `foreground` on `background`, selection = `background` text on `accent`, opacity `0.95`, scrollback 10000.

### 4.3 Typography

**The fonts are a deliberate, pinned choice** — they are not changed because a skill, theme or brand guideline prescribes a different typeface, only on an explicit request for that specific font change. Two font roles, both defined in `modules/theme/fonts.nix` (source of truth).
**To change a font, follow the "Changing fonts" section in `AGENTS.md`** (procedure: the `changing-fonts` skill in `.claude/skills/`) — the
family string for terminals lives once in `lib/terminal-theme.nix` (`theme.font`; all terminal configs are generated from it) and the exact Nerd Font
family name must be read from the package with `fc-scan`, not guessed (the build does not catch a wrong family name).

| Role                | Font                  | License | Fallback             |
|---------------------|-----------------------|---------|----------------------|
| Main / UI (sans+serif) | Hack Nerd Font     | MIT     | —                    |
| Terminal / code (mono) | JetBrainsMono Nerd Font | OFL | CaskaydiaMono Nerd Font |
| Icon glyph fallback | Symbols Nerd Font / Symbols Nerd Font Mono | MIT | —          |

**Font packages installed:** `nerd-fonts.hack`, `nerd-fonts.jetbrains-mono`, `nerd-fonts.caskaydia-mono`, `nerd-fonts.symbols-only` (the last is required by Rio for icon glyph fallback).

**Fontconfig defaults:**

- Monospace: JetBrainsMono Nerd Font, CaskaydiaMono Nerd Font
- Sans-serif: Hack Nerd Font
- Serif: Hack Nerd Font

Rio alone uses the `JetBrainsMono Nerd Font Mono` variant with the two Symbols families as extras (CONSTRAINTS.md #11).

### 4.4 Theme Environment Variables

**Per-role colour variables** — exported via `environment.variables` (`/etc/set-environment`, i.e. login shells) by `modules/theme/default.nix`, each set from the corresponding role token of the active palette:

| Variable               | Role         |
|------------------------|--------------|
| `SPACECRAFT_BACKGROUND` | `background` |
| `SPACECRAFT_SURFACE`    | `surface`    |
| `SPACECRAFT_TEXT`       | `foreground` |
| `SPACECRAFT_ACCENT`     | `accent`     |
| `SPACECRAFT_STRUCTURE`  | `structure`  |
| `SPACECRAFT_SUCCESS`    | `success`    |
| `SPACECRAFT_ERROR`      | `error`      |
| `SPACECRAFT_WARNING`    | `warning`    |
| `SPACECRAFT_INFO`       | `info`       |

These exist for shell scripts and third-party programs with no Standard §11 theme of their own and are **not** a Standard interface (Standard §11.6.4): a conforming application reads values from `steelbore.toml` and learns the active theme from `SPACECRAFT_THEME` or the declaration file. `SPACECRAFT_WARNING` formerly carried the error colour; the two are separate roles now.

**`SPACECRAFT_THEME`** — the active slug, exported by `modules/theme/declaration.nix` via `environment.sessionVariables` (not `environment.variables`), so it reaches graphical sessions and systemd user services, not only login shells (Standard §11.6.5). The variable name comes from `steelborePalette.resolution.envVar`.

**System theme declaration (Standard §11.6.4)** — `modules/theme/declaration.nix` also renders `/etc/steelbore/theme.toml` (slugs only: `active`, the derived `dark`/`light` pair, `follow-color-scheme`, `high-contrast`) and installs the advisory registry at `/etc/steelbore/themes.json`. The file is rendered from `steelbore.theme.active`, which defaults (`lib.mkDefault`, `modules/theme/default.nix`) to the resolved palette's slug (`steelborePalette.meta.slug`). That is `theme.nix`'s `active` for a normal build and the tried slug for a `themeSystems` build, so `theme try` never gives two answers. Options live under `steelbore.theme.*` (`active`, `dark`, `light`, `followColorScheme`, `highContrast`, `declare`, `installRegistry`); an unknown `dark`/`light` slug fails evaluation. `theme now <slug>` writes the per-user override at `$XDG_CONFIG_HOME/steelbore/theme.toml`, which outranks the system file and needs no rebuild for Standard §11.6-aware applications.

### 4.5 TTY/Virtual Console Colors

Set via `console.colors` in `modules/theme/default.nix`: the 16-entry list `ansi.normal ++ ansi.bright` from `lib/palette.nix` (§4.2), each passed through `convert.bareHex` to give the 16 hex values without `#` prefix that `console.colors` expects — normal 0–7 then bright 8–15. No colour is written in the module, so the TTY follows the active theme with the terminals.

---

## 5. Core System Modules

`modules/core/default.nix` imports nine modules from `modules/core/`, all unconditional (no `steelbore.*` toggle): boot, memory, nix, nix-tmp, locale, audio, security, keyring, dns.

### 5.1 Nix Settings (`modules/core/nix.nix`)

- **Experimental features:** `nix-command`, `flakes`
- **Store optimisation:** `auto-optimise-store = true` — hardlink-deduplicates identical store files at a small CPU cost per store add
- **`warn-dirty = false`:** silences the "Git tree is dirty" warning that would otherwise print on every evaluation while iterating on uncommitted config
- **Garbage collection:** `nix.gc` automatic, weekly, `--delete-older-than 30d`. This is the unattended backstop; the `preflight` rebuild path runs its own GC that keeps a week of generations (`--delete-older-than 7d`; `--gc-all` collects every old generation) — see §16
- **Flake-only:** `nix.channel.enable = false` — the flake is the single source of truth; `<nixpkgs>` and the `nixpkgs` registry entry stay pinned to the flake's nixpkgs (the `nixpkgs.flake.setNixPath` / `setFlakeRegistry` defaults), so `nix-shell -p` and `nix shell nixpkgs#…` track the same release. This retired a stale imperative channel that was independent of the flake
- **nixpkgs.config:** `allowUnfree = true`
- **FHS compatibility:** `services.envfs.enable` (FUSE `/usr/bin/env`, so `#!/usr/bin/env …` shebangs work) and `programs.nix-ld.enable` with `zlib`, `openssl` and `stdenv.cc.cc.lib` for unpatched dynamic binaries
- **Overlays:** defined inline — the sole overlay location; contents and rationale in §3.4.

### 5.2 Boot (`modules/core/boot.nix`)

- **Bootloader:** systemd-boot, EFI variables writable, `configurationLimit = 3` — the 196 MiB ESP holds three XanMod kernel+initrd pairs, and the installer prunes entries beyond the limit before copying the new kernel (CONSTRAINTS.md #42). Single-boot: an `extraInstallCommands` hook deletes any `EFI/Microsoft` loader on each install, since systemd-boot would otherwise auto-list it as "Windows Boot Manager"
- **Kernel:** `linuxPackages_xanmod_latest` (performance-optimized)
- **Boot splash:** Plymouth `script` theme `steelbore` (`modules/theme/boot-splash.nix`, `pkgs/steelbore-plymouth`), toggled by `steelbore.boot.splash.enable`; shows the still image `assets/boot/splash.png` (at most 1920 px wide, palette-quantized by `pkgs/steelbore-quantize` — the Rust `imagequant` crate, no C) scaled to fit, on the palette canvas, with `quiet splash`, rendered on `simpledrm` (no `i915` in the initrd). Initrds are zstd `-19`. Budgeted against the ESP (CONSTRAINTS.md #43)
- **Startup sound:** `users/mj/startup-sound.nix` — `pw-play` of `assets/boot/startup-sound.mp3` once per boot at the first graphical login (marker in `/tmp`)
- **Module lists:** none here (initrd modules: generated `hosts/<machine>/hardware.nix`; `kvm-intel`: `modules/hardware/intel.nix`). The generated `hosts/thinkpad/hardware.nix` also declares `kvm-intel` and `hardware.cpu.intel.updateMicrocode`; the list options merge and the microcode line is the same `mkDefault`, so the duplication is harmless

### 5.3 Locale (`modules/core/locale.nix`)

- **Timezone:** `Asia/Bahrain`
- **Default locale:** `en_US.UTF-8`
- **All LC_* variables:** `en_US.UTF-8` (ADDRESS, IDENTIFICATION, MEASUREMENT, MONETARY, NAME, NUMERIC, PAPER, TELEPHONE, TIME)
- **Why `LC_TIME` is not an ISO locale:** `en_DK.UTF-8` was tried for system-wide ISO 8601 and reverted. Qt reads CLDR, not glibc, and CLDR's `en_DK` short time format uses a dot separator, which broke the Plasma panel clock; glibc also never generated the locale, so `date` fell back to C. ISO 8601 in the Plasma clock is pinned in `users/mj/plasma.nix` instead. Any new locale must keep a colon time separator under CLDR and be verified with `LC_ALL=<locale> date` (CONSTRAINTS.md #31)
- **Console keymap:** `console.keyMap = "us"`, set in the shared host config (`hosts/common.nix`)
- **Input method:** iBus enabled with an empty engine list — the daemon idles on US-only input but provides the D-Bus surface that the iBus Wayland panel autostart expects, which otherwise surfaces an error popup (notably under COSMIC)

### 5.4 Audio (`modules/core/audio.nix`)

- **PulseAudio:** Disabled
- **PipeWire:** Enabled (ALSA, 32-bit ALSA, PulseAudio compatibility)
- **RTKit:** Enabled (real-time scheduling privileges)
- **JACK:** Available but commented out

### 5.5 Security (`modules/core/security.nix`)

- **sudo (C):** Disabled
- **sudo-rs (Rust):** Enabled, `execWheelOnly = true`
- **Polkit:** Enabled
- **gtklock PAM:** `security.pam.services.gtklock` is declared explicitly — the package's own `etc/pam.d/gtklock` is invisible to PAM otherwise, and gtklock would reject every password (CONSTRAINTS.md #9). It carries `enableGnomeKeyring = true` so a password screen-unlock re-opens a keyring that something locked mid-session. gtklock is in `fprintAllow`, so a fingerprint unlock short-circuits `auth` before `pam_gnome_keyring`; that is tolerable here only because locking the screen does not lock the keyring — it is not precedent for fingerprint on anything that starts a session (§6.1)
- **passwd PAM:** `security.pam.services.passwd.enableGnomeKeyring = true` — `passwd(1)` is the only place the login keyring is re-keyed; without it the Unix password changes while the keyring stays encrypted under the old one, and greetd's auto-unlock then fails silently at every login. Pairs with `passwd` being in `fprintDeny` (`modules/hardware/fingerprint.nix`), since a fingerprint never populates `PAM_OLDAUTHTOK`
- **SSH agent:** **`programs.ssh.startAgent = false`** — `services.gitway-agent.enable = true` owns `$SSH_AUTH_SOCK` at `${XDG_RUNTIME_DIR}/gitway-agent.sock`, and the system `ssh-agent.service` would race it (CONSTRAINTS.md #8). `services.gnome.gcr-ssh-agent.enable = false` and a `Hidden=true` `gnome-keyring-ssh.desktop` shadow (`users/mj/desktop-theme.nix`) keep gnome-keyring off the socket too. The agent's user unit is overridden to append `-t 86400` (a 24 h key lifetime, which the gitway NixOS module does not expose), and `environment.sessionVariables.SSH_AUTH_SOCK` makes the socket visible to shells greetd execs directly, which never read `environment.d`. The OpenSSH CLI tools remain available for non-Git SSH
- **Fingerprint-gated passphrase:** `gitway biometric` releases the key passphrase from the login keyring behind an fprintd check — a convenience layer, not a security boundary: the passphrase is protected by the login keyring, which the greetd password opens (`modules/hardware/fingerprint.nix`)
- **seatd:** enabled for the `cage`-wrapped shell session entries, whose libseat tries the seatd backend first
- **Tmpfiles rules:** `/tmp 1777`, `/var/tmp 1777`

### 5.6 Keyring (`modules/core/keyring.nix`)

- **Secret Service provider:** `services.gnome.gnome-keyring.enable = true` — pinned here explicitly and DE-independently, since Bravais's primary sessions (Niri, LeftWM) are window managers that pull in nothing (GNOME's own module would also enable it when that desktop is installed)
- **Unlock paths:** the primary one is `security.pam.services.greetd.enableGnomeKeyring` (`modules/login/default.nix`) — greetd authenticates by password (`greetd` is in `fprintDeny`, §6.1), so pam_gnome_keyring auto-unlocks at login. `steelbore-keyring-unlock` (`Mod+Shift+U` under Niri and LeftWM, `modules/desktops/shared.nix`) is a **rescue** path for a keyring locked mid-session; it raises the Secret Service `Unlock` prompt over D-Bus (gcr-prompter draws the dialog) and then hands off to the read-only check. That sibling, `steelbore-keyring-check`, runs ~5 s into every Niri session (`users/mj/niri.nix`) and LeftWM session (`modules/login/default.nix`) and exits `0` ok / `2` default collection locked / `3` `default` alias unset or not pointing at `login` / `4` dangling browser Safe Storage items
- **Prompter:** the unlock dialog is drawn by `gcr-prompter`, which ships in **gcr 3 only** — gcr 4 dropped it. `modules/core/keyring.nix` pins `services.dbus.packages = [ gcr3 ]` with `gcr3 = pkgs.gcr_3 or pkgs.gcr`, and asserts `lib.versionOlder gcr3.version "4"` so an upstream move fails at eval rather than silently removing every keyring dialog. The `or` order is load-bearing: unstable has `gcr_3` and a *throwing* `gcr`, stable has only `gcr`, so the surviving name must come first (CONSTRAINTS.md #5, #32)
- **Tools:** `libsecret` (`secret-tool` — store/lookup/clear round-trip is the "is the bus up?" diagnostic), `seahorse` (GUI manager)
- **Chromium/Electron backend pinning:** Chromium reads `XDG_CURRENT_DESKTOP` to select a credential backend; under Niri/LeftWM it reads `niri`/`leftwm` → `DE_OTHER` → plaintext fallback ("An OS keyring couldn't be identified…"). Two routes, one cause:
  - **Nix-installed** (Cursor, Kiro, VSCodium, Antigravity Desktop + IDE): wrapped with the read-only option `steelbore.keyring.chromiumFlag` = `--password-store=gnome-libsecret` (`modules/packages/editors.nix`) — the single place that flag is spelled
  - **Flatpak** (Chrome, Edge, Opera, Brave, Discord, Wavebox, VS Code, VSCodium, GitHub Desktop): rather than the imperative per-app flags file under `~/.var/app/`, `services.flatpak.overrides.settings.<app>.Environment.XDG_CURRENT_DESKTOP = "GNOME"` — declarative and scoped to the sandbox, so host portal-backend selection is untouched (`modules/packages/flatpak.nix`)

### 5.7 DNS (`modules/core/dns.nix`)

- **Resolver:** `systemd-resolved` (NetworkManager → `dns = "systemd-resolved"`)
- **Primary:** Cloudflare malware-blocking — `1.1.1.2` / `1.0.0.2` (+ v6) with TLS SNI `security.cloudflare-dns.com`
- **Fallback:** Plain Cloudflare — `1.1.1.1` / `1.0.0.1` (+ v6) with TLS SNI `cloudflare-dns.com`; keeps DoT and DNSSEC but loses malware filtering while in use
- **DNS-over-TLS (DoT):** Enforced (`DNSOverTLS=true` — refuses plaintext)
- **DNSSEC:** Enforced (`DNSSEC=true` — drops responses that fail validation)
- **Routing:** Global `~.` Domains entry forces every query through the global DNS list, ignoring link-specific DNS pushed by DHCP
- **Channel portability:** Schema differs between stable (legacy `services.resolved.{dnssec,dnsovertls,domains,fallbackDns}` flags) and unstable (renamed to `services.resolved.settings.Resolve.*`); the module uses an `options.services.resolved ? settings` check to pick the right form per channel — the same pattern as CONSTRAINTS.md #5 — so both mkBravais variants evaluate clean
- **VPN interaction:** `adguardvpn-cli` in TUN mode can displace this resolver — prefer SOCKS, or TUN with `script` routing (CONSTRAINTS.md #19, #37)

### 5.8 Memory & OOM Resilience (`modules/core/memory.nix`)

Why: the machine has no disk swap, and systemd-oomd was active but monitored no cgroups, so a heavy `cargo`/`rustc`/`mold` build could exceed RAM and the kernel's hard kill took the zellij server — and every pane in it — down with it. The module adds headroom and a name-aware guard that kills the *build* instead of the multiplexer.

- **zram:** `zramSwap` with `zstd`, `memoryPercent = 50`, `priority = 100` (fills before any future disk swap)
- **earlyoom (primary guard):** SIGTERM below 8 % free RAM, SIGKILL below 4 %, `freeSwapThreshold = 10`, desktop notification naming the victim; `--prefer` compilers and linkers (`cargo`, `rustc`, `cc1`, `cc1plus`, `lld`, `ld`, `mold`, `rust-analyzer`, `clippy-driver`, `cargo-clippy`), `--avoid` the session (`zellij`, `claude`, `node`, `nu`, `bash`, `sshd`, `systemd`, `niri`, `Xwayland`)
- **systemd-oomd (backstop):** enabled on the root slice and all user slices, catching sustained pressure after earlyoom
- **Diagnostics:** persistent journald storage and `systemd.coredump.enable` — both NixOS defaults, affirmed so a recurrence leaves evidence. The journald option is selected with an `options.services.journald ? settings` check, since unstable renamed it to `settings.Journal.Storage` and stable declares only the old name

### 5.9 Builder TMPDIR (`modules/core/nix-tmp.nix`)

Moves Nix's build scratch off the system disk and onto a removable external drive, falling back to the system disk when the drive is absent (CONSTRAINTS.md #28).

- **Target:** `nix.settings.build-dir` and `nix-daemon`'s `TMPDIR` are both `/mnt/nix-tmp`. `build-dir` is needed too because root callers build in-process and bypass the daemon's environment
- **Loop image:** an 80 GiB sparse ext4 image at `/run/media/<primaryUser>/Expansion/nix-tmp.img` on a removable external drive. A path unit (`nix-tmp-loop.path`) watches for the udisks2 mountpoint; the oneshot `nix-tmp-loop.service` creates and formats the image if missing, runs `e2fsck -p` (an aborted journal otherwise remounts read-only and fails every build), and loop-mounts it. The size governs only fresh creation; an existing image is grown by hand
- **Mount guard:** the path unit fires on a *directory* existing, not on a mount — udisks2 can leave a stale empty mountpoint behind. The service therefore waits for a real mount and refuses memory-backed filesystems; unguarded, the image once landed on the tmpfs behind `/run`, filled RAM and drove the machine into OOM
- **Fallback:** with the drive absent, `/mnt/nix-tmp` is a plain tmpfiles directory and builds fall back transparently
- **Mode `0755 root:root`, not `1777`:** Nix 2.31+ refuses a world-writable `build-dir`; only the daemon writes here
- **Age `10d`:** `nix-collect-garbage` never touches the builder TMPDIR, so a build killed part-way leaves its scratch tree behind while the rebuild's GC reports success. The tmpfiles age (formerly `-`, never clean) bounds that leak at ten days; tmpfiles ages each file individually and no build runs that long, so it cannot race a live build (CONSTRAINTS.md #28)

---

## 6. Hardware Modules

All hardware modules live under `modules/hardware/` (imported by
`modules/hardware/default.nix`) and are toggled per machine in
`hosts/<machine>/default.nix`. The ThinkPad enables all five:
`android`, `audioLed`, `bluetooth`, `fingerprint` and `intel`. The x86-64 ISA
level is a separate, vendor-neutral platform module (§6.2).

### 6.0 Android (`modules/hardware/android.nix`)

**Option:** `steelbore.hardware.android.enable`

The **device** half of Android support: installs `pkgs.android-tools` (adb,
fastboot) and accepts the SDK license. **Not `programs.adb.enable`** — that option was removed and fails evaluation;
systemd's uaccess rules give the seat user device access with no group and no
re-login, and the `adbusers` group no longer exists (CONSTRAINTS.md #33).

The **SDK is not installed system-wide.** It lives in `devShells.<system>.android`
(`flake.nix`), entered with `nix develop .#android -c nu` (Nushell is the login
shell; `nix develop` would otherwise drop into bash), carrying the composed SDK,
`jdk17` (AGP 8.x needs JDK 17+) and `gradle`. Platform and build-tools versions
belong to a project, not a machine, and the emulator plus system images would
add several GB to every system closure.

Versions are explicit because `androidenv` fails on anything absent from its
pinned `repo.json`. NDK, emulator and system images are off; enable per project.

`accept_license` is set **twice** (module and the flake's `androidPkgs`): a
flake output's nixpkgs inherits nothing from a NixOS module.

### 6.1 Fingerprint Reader (`modules/hardware/fingerprint.nix`)

**Option:** `steelbore.hardware.fingerprint.enable`

**Driver.** fprintd plus the **TOD** `libfprint-2-tod1-vfs0090` driver for the
Synaptics `06cb:00bd` sensor (the stock driver cannot read prints back), with a
local patch for the upstream `broken` mark.

**Power.** udev rules keep the sensor out of USB runtime suspend (the firmware
does not survive its wake mid-scan) and set `power/persist = 1` so S3 does not
re-create it under a fprintd with no hotplug path. **Deliberately no** sleep
hooks stop fprintd — they raced the lock screen. See CONSTRAINTS.md #39.

**Policy.** `fprintAuth` defaults to `services.fprintd.enable`, which silently
put `pam_fprintd` into 28 of 32 PAM services. The module replaces that
inheritance with two explicit lists:

| | Services |
|---|---|
| **`fprintAllow`** | `sudo`, `sudo-i`, `polkit-1`, `gtklock`, `swaylock`, `xlock`, `vlock`, `kde-fingerprint`, and `cosmic-greeter` while it is only the COSMIC lock screen |
| **`fprintDeny`** | session entry (`greetd`, `login`); `PAM_OLDAUTHTOK` users (`passwd`, `chpasswd`); account mutation (`chsh`, `chfn`, `user*`, `group*`); `su`, `su-l`; `i3lock` (runs PAM only after Enter, so a scan would delay every password unlock); non-conversational (`runuser`, `runuser-l`, `systemd-run0`, `systemd-user`, `cups`); and `cosmic-greeter` if it becomes the display manager |

**The rule:** fingerprint *authenticates*, it cannot *decrypt*. Wherever it
touches a secret it gates release of something the **login keyring** holds,
and that keyring is opened by the password typed at greetd — so
password-at-greetd is the root of trust and fingerprint is the layer above it.

**The mechanism:** `pam_fprintd` is `sufficient` and ordered before
`pam_gnome_keyring`, so a successful scan short-circuits `auth` before the
keyring module runs. Any service that starts a session or needs
`PAM_OLDAUTHTOK` must therefore refuse it: a fingerprint login leaves the
keyring locked (Chromium-family browsers then mint a fresh Safe Storage key and
drop saved logins), and a fingerprint at `passwd` cannot re-key the keyring.
The **lock screens** are the deliberate exception — locking the screen does not
lock the keyring, which stays open from the greetd password
(`modules/core/security.nix`). A failed or unsupported scan always falls
through to the password prompt, so the user can never be locked out.

**Why `su` is denied while `sudo` is allowed:** `sudo` authenticates the
*invoking* user and is wheel-gated (`execWheelOnly`); `su` authenticates the
*target* (root) with no `pam_wheel` entry, so a root enrolment would let any
local account become root with that finger. Use `sudo -i`.

`cosmic-greeter` is classified by whether it is the display manager: under
greetd it is only the COSMIC **lock screen** (the primary fingerprint surface);
making it the greeter moves it to `fprintDeny` automatically.

Declaring a PAM service *creates* it (CONSTRAINTS.md #9 in reverse), so a
rebuild must not grow `/etc/pam.d`, and the files naming `pam_fprintd` must
equal `fprintAllow`.

**Consumer: Bitwarden biometric unlock.** A polkit `auth_self` check on
`com.bitwarden.Bitwarden.unlock` gating release of a vault key held in the
Secret Service — the rule above restated in another application. The action
file ships with **`pkgs.bitwarden-desktop` itself**, so nothing in this tree
declares it; **never add a second copy** (`buildEnv` collision, same shape as
CONSTRAINTS.md #12). It was declared here only while the client was the
Flatpak, which cannot install polkit actions from its sandbox. `polkit-1` is in
`fprintAllow`, so a failed scan falls through to the password.

### 6.2 CPU Vendor (`modules/hardware/intel.nix`) + x86-64 Platform Flags (`modules/platform/x86-64.nix`)

**Vendor:** `steelbore.hardware.intel.enable` is vendor-only (`kvm-intel`,
microcode updates when redistributable firmware is enabled).

**Platform:** the x86-64 ISA level and **all** compiler/linker flags live in
`modules/platform/x86-64.nix` under `steelbore.platform.x86_64.enable` with the
`marchLevel` suboption (enum `v1`–`v4`, default `v2`) — an x86-64-vN level is
not Intel-specific, so it is decoupled from the vendor module. The default is
v2, **not** v4: a v4 default emits AVX-512 that SIGILLs on any CPU without it,
while v2 runs on every x86-64 CPU from about 2009 on. Each host pins its true
level; the ThinkPad (i7-8665U, no AVX-512) pins `v3`. There is no v1–v4 build
matrix.

Flags are session variables, so they shape **user-driven** builds only
(`nixos-rebuild` sandboxes its own environment). **Sources:** CachyOS for
v1/v3/v4, ALHP for v2.

#### Common C Flags (v1, v3, v4):
```
-O3 -pipe -fno-plt -fexceptions -flto=auto
-Wp,-D_FORTIFY_SOURCE=3 -Wformat -Wformat-security
-fstack-clash-protection -fcf-protection
```

Dropped from the CachyOS original: `-Werror=format-security` (breaks
legitimate user builds; it stays a warning) and hardening flags nixpkgs stdenv
already covers.

#### Linker Flags (v1, v3, v4):
```
-fuse-ld=mold
-Wl,-O1 -Wl,--sort-common -Wl,--as-needed
-Wl,-z,relro -Wl,-z,now -Wl,-z,pack-relative-relocs
```

#### ALHP Linker Flags (v2 only):
The block above without `-Wl,-z,pack-relative-relocs`, per ALHP.

**Why mold, not gold:** gold is deprecated and lacks `-z pack-relative-relocs`;
mold supports it, handles the GCC LTO plugin and links faster (installed
system-wide so user builds resolve it).

#### Per-Level Flag Table

| Level | CFLAGS | RUSTFLAGS | GOAMD64 |
|-------|--------|-----------|---------|
| v1 | `-march=x86-64 -mtune=generic` + common | `-C target-cpu=x86-64 -C opt-level=3` + mold + `pack-relative-relocs` | v1 |
| v2 | `-march=x86-64-v2 -mtune=generic -O3 -mpclmul -falign-functions=32 -flto=auto` | `-Copt-level=3 -Ctarget-cpu=x86-64-v2` + mold | v2 |
| v3 | `-march=x86-64-v3 -mtune=native -mpclmul` + common | `-C target-cpu=x86-64-v3 -C opt-level=3` + mold + `pack-relative-relocs` | v3 |
| v4 | `-march=x86-64-v4 -mtune=native -mpclmul` + common | `-C target-cpu=x86-64-v4 -C opt-level=3` + mold + `pack-relative-relocs` | v4 |

v1 and v2 use `-mtune=generic` to stay portable. **CXXFLAGS** = `${CFLAGS} -Wp,-D_GLIBCXX_ASSERTIONS`;
**LTOFLAGS** = `-flto=auto`. **AR / NM / RANLIB** point at `gcc-ar` /
`gcc-nm` / `gcc-ranlib`, because plain binutils cannot autoload the LTO plugin
on NixOS and static-library LTO breaks without them.

### 6.3 Bluetooth (`modules/hardware/bluetooth.nix`)

**Option:** `steelbore.hardware.bluetooth.enable`

Enables BlueZ with `powerOnBoot` and `Experimental` (battery levels). Ships two memory-safe (Rust), GPL-3.0 BlueZ clients — **bluetui** (TUI, default;
Niri `Mod+B`) and **overskride** (GTK GUI + OBEX; Niri `Mod+Shift+B`) — which
coexist as D-Bus clients of one `bluetoothd`. Niri has no Bluetooth applet; the
`XF86Bluetooth` key (`steelbore-bt-toggle`) only toggles the radio via `rfkill`
and posts a dunst notification, so these clients are what actually pair/connect
devices. Audio routing uses the PipeWire mixers (`wpctl` / `wiremix` /
`pavucontrol`).

### 6.4 Audio Mute LEDs (`modules/hardware/audio-led.nix`)

**Option:** `steelbore.hardware.audioLed.enable` (asserts PipeWire, without
which the daemon would flap).

Lights the ThinkPad **mute** and **mic-mute** keyboard LEDs to follow the real
mute state. The kernel triggers follow the ALSA *hardware* mute, but PipeWire
mutes in *software*, so the LEDs would otherwise never light. Ships
**steelbore-audio-led** (`pkgs/steelbore-audio-led/`; Rust, GPL-3.0-or-later),
an event-driven daemon mirroring default sink/source mute onto the LEDs however
mute was toggled — a systemd **user** service, so session-agnostic. A udev rule sets each LED's `trigger` to `none`
so the daemon owns it; `brightness` is `input`-group-writable via the
brightnessctl udev rules. **CapsLock** and **FnLock** LEDs already work and need
no module.

### 6.5 Status-Bar Hardware Indicators (`pkgs/steelbore-beacon`)

The eww bar carries live **audio**, **microphone**, **backlight** and
**lock-key** indicators from one daemon, **steelbore-beacon** (Rust,
GPL-3.0-or-later), emitting JSON lines that both bars (Niri's and LeftWM's)
read with one `deflisten`. It is event-driven rather than polled: a poll cheap enough to run all day visibly
lags the key, and one fast enough to feel instant wakes the CPU for state that
rarely changes.

The sources: the **PulseAudio** mainloop (default sink/source resolved by name
per event, so a headset swap follows); **`EV_LED`** from LED-capable input
devices, emitted whoever toggled the lock and so correct under X11 and Wayland
alike; and **`POLLPRI`** on the `intel_backlight` brightness node (hardcoded, so
a multi-backlight machine never silently picks the wrong one). All are readable
rootless via `input` and `video` membership.

Rendering follows Standard §18.2.1 (glyph changes with state; lock badges drawn
only while engaged — never colour alone), with Standard §11 role tokens on the canvas,
never a surface fill (Standard §11.0.1). Bar SCSS rules: CONSTRAINTS.md #26.

**FnLock is deliberately not indicated** (CONSTRAINTS.md #25): the embedded
controller handles Fn+Esc without telling the kernel, so an indicator could
only infer the state and would drift after the first resume. (The *physical*
FnLock LED in §6.4 is EC-driven and unaffected.)

---

## 7. Host Configuration (`hosts/`)

`hosts/` holds one directory per physical machine plus a shared `hosts/common.nix`. Each
`hosts/<machine>/default.nix` imports `../common.nix` and its own `./hardware.nix`, then sets
only what is genuinely per-machine: `networking.hostName`, the `steelbore.hardware.*`
toggles, machine-specific services, and the x86-64 march pin. Every other toggle belongs in
`hosts/common.nix`. The only machine today is `thinkpad`.

`flake.nix` names each machine once in its `hosts` attribute set and passes it to
`mkBravais { host, channel }`, which yields `bravais-thinkpad` (stable 26.05),
`bravais-thinkpad-unstable` (nixos-unstable) and the `bravais` alias. The alias points at the
`bravais-thinkpad` attribute instead of calling `mkBravais` a second time, because a second
identical call would evaluate the whole system again. **Adding a machine** means adding a
`hosts/<machine>/` directory plus two output lines in `flake.nix`.

### 7.1 Shared Host Settings (`hosts/common.nix`)

- **Networking:** NetworkManager enabled
- **X11:** `services.xserver.enable = true` (for LeftWM). Keyboard layouts are `us,ara`, toggled with `grp:ctrl_space_toggle`
- **Touchpad:** natural (reverse) scrolling on X11 sessions (`services.libinput.touchpad.naturalScrolling`). Niri sets its own equivalent in its `config.kdl`
- **Console keymap:** `us`, because ckbcomp can't resolve multi-layout XKB configs
- **Printing:** Enabled
- **Root shell and login shells:** see §7.2
- **Desktop toggles:** `steelbore.desktops.{gnome,cosmic,cosmicUnmax,plasma,niri,niriUnmax,leftwm,mouseWorkspaceNav}.enable`
- **Package toggles:** `steelbore.packages.{browsers,terminals,editors,development,security,networking,multimedia,productivity,system,ai,games,orca,flatpak,homebrew}.enable`, plus `packages.games.steam.enable = true` and `packages.games.dosGames` (one entry per DOS title, each generating a `play-<slug>` command). `packages.games.wine.enable` is explicitly `false`. It is written out rather than omitted so the option is easy to find: Wine + Lutris measured 665 MiB to download and 2.8 GiB unpacked
- **Service toggles:** `steelbore.services.adguardvpn` (with `routeScript.enable`), `services.podman.enable`, `services.ollama.enable` (version pinned in `pkgs/ollama/`)
- **Compatibility:** `steelbore.compat.appimage.enable`
- **State version:** `system.stateVersion = "26.05"` (§7.4)

The user account is **not** defined here. It is defined once in `users/mj/default.nix` (§7.2), so it can't drift into a second, duplicate definition.

### 7.1.1 ThinkPad (`hosts/thinkpad/default.nix`)

The machine is an Intel i7-8665U (Whiskey Lake). A T490s-specific comment in this file names the pointing stick.

- **Hostname:** `bravais-thinkpad`
- **Hardware toggles:** `steelbore.hardware.{android,audioLed,bluetooth,fingerprint,intel}.enable`
- **Mouse-nav exclusion:** `steelbore.desktops.mouseWorkspaceNav.ignoredDevices = [ "Elan TrackPoint" ]`. This is per-machine because the device name is. Keeping xremap off the TrackPoint preserves libinput's middle-button scrolling for the pointing stick (CONSTRAINTS.md #29)
- **Services:** `steelbore.services.waydroid.enable` (Wayland-only: works under Niri, GNOME, COSMIC and Plasma Wayland, not under LeftWM) and `steelbore.services.chromeRemoteDesktop = { enable = false; user = primaryUser; }` (disabled since 2026-10-02; when enabled, a headless X11 virtual session running LeftWM; the one-time Google authorization is manual)
- **March level:** `steelbore.platform.x86_64 = { enable = true; marchLevel = "v3"; }`. The i7-8665U supports x86-64-v3 (AVX2/BMI2/FMA) but has **no AVX-512**, so v4 would emit illegal instructions on this CPU

The platform module (`modules/platform/x86-64.nix`) accepts `marchLevel` as an enum of `v1`…`v4`, with a default of `v2`. The default is deliberately not v4, because a v4 default would SIGILL on any CPU without AVX-512. Every host is expected to pin its real level. There is no v1–v4 build matrix: each machine builds at exactly one level.

### 7.2 User Account (`users/mj/default.nix`)

The primary user is stated once in `flake.nix` as `primaryUser = "mj"` and passed to modules through both `specialArgs` and `extraSpecialArgs`. Modules refer to `users.users.${primaryUser}` / `home-manager.users.${primaryUser}` and never to a literal `mj`. The `users/mj/` directory name is a stable path, not a second statement of the username. `users/mj/default.nix` is imported directly in `mkBravais`'s module list.

- **Username:** `primaryUser` (`mj`)
- **Full name:** Mohamed Hammad
- **Groups:**

| Group            | Why                                                                                              |
|------------------|--------------------------------------------------------------------------------------------------|
| `networkmanager` | Network control                                                                                  |
| `wheel`          | Privilege escalation via sudo-rs (`execWheelOnly`)                                               |
| `input`          | Read access to real input devices                                                                |
| `video`, `audio` | Device access                                                                                    |
| `seat`           | Access to `/run/seatd.sock`, which cage needs for the shell sessions in §8.2 (`services.seatd.enable` in `modules/core/security.nix`) |
| `uinput`         | Write access to `/dev/uinput`, so xremap can create its virtual output device under GNOME. The group is created by `hardware.uinput.enable` in `modules/desktops/mouse-workspace-nav.nix`. `input` covers only *reading* devices |

`chrome-remote-desktop` is added to the configured CRD user's groups by `modules/services/chrome-remote-desktop.nix`, not here. There is no `adbusers` group: that option was removed from nixpkgs (CONSTRAINTS.md #33).

- **Shell:** `mjsh` — Operator's standalone shell (Rust, built on Nushell), at `/home/<primaryUser>/.local/bin/mjsh`; installed out-of-band, not by Nix
- **Root shell:** `pkgs.brush` (Brush, a Rust Bash-compatible shell), set in `hosts/common.nix`
- **Valid login shells:** nushell, brush, ion and mjsh (added in `users/mj/default.nix`), registered through `environment.shells`. Bash is left out of `environment.shells` and isn't assigned to any user. The bash module itself stays enabled, because NixOS activation and PAM tooling depend on it (CONSTRAINTS.md #1, #2)

### 7.3 Hardware (`hosts/thinkpad/hardware.nix`)

This file was originally generated by `nixos-generate-config` and has been hand-maintained since. It carries an SPDX header, which the generator doesn't emit. Regenerating it therefore means reconciling by hand (re-add the SPDX line, then `nix fmt`), not overwriting the file wholesale. Key details:

- **Platform:** `nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux"`
- **initrd modules:** `xhci_pci`, `nvme`, `usb_storage`, `sd_mod`, `rtsx_pci_sdmmc`; kernel module `kvm-intel`
- **Root filesystem:** ext4, `/dev/disk/by-uuid/667c95b9-16ac-449a-b36c-7a4e156620c3`
- **Boot partition:** vfat, `/dev/disk/by-uuid/30F4-BB7D`, `fmask=0077`, `dmask=0077`. This is a small ESP, which is why `systemd-boot.configurationLimit = 3` (CONSTRAINTS.md #42)
- **Swap:** None (`swapDevices = [ ]`)
- **Microcode updates:** `hardware.cpu.intel.updateMicrocode` follows `hardware.enableRedistributableFirmware`

`hardware.nix` declares the ext4 root above, but on the running system `df /` reports a 16 GiB tmpfs, while `/nix`, `/var` and `/home` are bind-mounted subtrees of the real partition (a measurement recorded in CONSTRAINTS.md #28, not something this file configures). Disk checks must therefore target a real path such as `/nix`.

### 7.4 State Version

`system.stateVersion = "26.05"` (`hosts/common.nix`). Home Manager's `home.stateVersion` is also `"26.05"` (`users/mj/home.nix`).

---

## 8. Login Manager (`modules/login/default.nix`)

### 8.1 greetd + tuigreet

```
tuigreet \
  --time \
  --time-format "%Y-%m-%d %H:%M:%S UTC%:z" \
  --remember \
  --remember-session \
  --asterisks \
  --greeting "STEELBORE OS :: BRAVAIS" \
  --sessions <sessionData.desktops>/share/wayland-sessions \
  --xsessions <sessionData.desktops>/share/xsessions \
  --no-xsession-wrapper
```

The greeter runs as user `greeter`.

**Why `UTC%:z`:** tuigreet renders `--time-format` through chrono's strftime. `%:z` computes the offset from the system's own time zone (`time.timeZone` in `modules/core/locale.nix`) instead of hardcoding it, so the line stays correct if the zone changes and across any DST transition. `%Z` (a bare `+03`) and `%z` (`+0300`) don't read as an offset. Labelling the offset makes the greeter's local time unambiguous, which Standard §14.3 allows as a human-facing companion to UTC.

**Default session:** `services.displayManager.defaultSession = "niri"` is a plain definition. It has to be set because the upstream nixpkgs modules `plasma6.nix` and `niri.nix` (the latter on nixos-unstable only) both `mkDefault` this option and would otherwise collide (these are nixpkgs' own NixOS modules, not Bravais's `modules/desktops/niri.nix` or `users/mj/niri.nix`). A plain definition outranks both without `mkForce` (CONSTRAINTS.md #21). tuigreet itself reads `--sessions` and `--xsessions`, and `--remember-session` still wins for a returning user.

**Why `--xsessions`:** tuigreet stamps every `--sessions` entry `XDG_SESSION_TYPE=wayland` and every `--xsessions` entry `x11`. Passing the X sessions through `--sessions` made Plasma X11 run as "Wayland", and Electron apps such as Orca refused to start. `--no-xsession-wrapper` drops tuigreet's default `startx /usr/bin/env` prefix, because each X session's `Exec` already starts its own server (CONSTRAINTS.md #44).

### 8.2 Shell Sessions

Shell sessions are built by a `mkShellSession` helper: a `pkgs.runCommand` that writes a `share/wayland-sessions/<name>.desktop` and sets `passthru.providedSessions`. Each entry's `Exec` wraps the shell as **`cage -- rio -e <shell>`**. Without that wrapper, greetd execs a bare shell with no TTY and no compositor: brush blocks on stdin, ion fails immediately, and nushell silently swallows its own startup error. cage supplies the compositor and rio supplies the PTY. cage relies on `seatd` (§7.2 `seat` group).

| Session Name | Session id  | Binary  | Comment              |
|--------------|-------------|---------|----------------------|
| Nushell      | `nushell`   | `nu`    | Drop to Nushell      |
| Brush Shell  | `brush`     | `brush` | Drop to Brush shell  |
| Ion Shell    | `ion-shell` | `ion`   | Drop to Ion shell    |
| mjsh         | `mjsh`      | the primary user's `shell` | Drop to mjsh (Operator) |

mjsh is out-of-band (`~/.local/bin/mjsh`, not a Nix package), so its entry reads the path back from `users.users.<primaryUser>.shell` (set in `users/mj/default.nix`) instead of restating it, and `/etc/greetd/environments` lists it by that full path — greetd's `PATH` does not include `~/.local/bin`.

### 8.2.1 X11 Sessions and Launchers

greetd doesn't start an X server (SDDM, GDM and LightDM do), so X11 sessions bring up Xorg themselves through `startx`. A `mkXSession` helper writes `share/xsessions/<name>.desktop` entries. `startx` calls `xinit`, `xauth`, `xrdb` and `mcookie` by bare name, so the launchers prepend them to `PATH`, using the `pkgs.xinit or pkgs.xorg.xinit` style of fallback that works on both channels (CONSTRAINTS.md #5). Each launcher pre-creates `~/.serverauth.$$` so xauth doesn't complain before startx creates it.

- **LeftWM** (`leftwm`): `start-leftwm` → `startx leftwm-xinitrc`. `leftwm-xinitrc` exports `GDK_BACKEND=x11`, `XDG_SESSION_TYPE=x11`, `ELECTRON_OZONE_PLATFORM_HINT=x11` (without these, Chromium and Electron apps probe Wayland and crash), `NO_AT_BRIDGE=1`, the gitway `SSH_AUTH_SOCK`, and `XDG_CURRENT_DESKTOP=leftwm` (which routes xdg-desktop-portal to the GTK appearance backend). It then runs `dbus-run-session`, because eww (GTK) fails to initialize without a session bus. The inner script starts `numlockx`, `gitway-add`, the polkit-gnome authentication agent (started here rather than in the theme's `up` script, which re-runs on every `LoadTheme`), and `steelbore-keyring-check` after a 5 s delay. One second after starting leftwm it issues `LoadTheme` and `xsetroot -solid` with the `background` role token. Both must run after leftwm starts, because leftwm neither auto-loads its theme nor keeps the root background.
- **Plasma X11** (`plasma-x11-startx`): `start-plasma-x11` → `startx startplasma-x11`.

LeftWM is registered through this xsession, **not** through `services.xserver.windowManager.leftwm.enable`. That module's xsession runs leftwm without an X server and crash-loops under greetd.

Every desktop gets a `start-<de>` launcher on `PATH`: `start-niri`, `start-plasma`, `start-plasma-x11`, `start-gnome` and `start-leftwm` are defined here. `start-cosmic` is **not**, because `pkgs.cosmic-session` already ships one, and defining a second would collide in `/run/current-system/sw/bin`.

### 8.3 Registered Session Packages

```nix
services.displayManager.sessionPackages = [
  gnome-wayland-hidden
  plasmax11-hidden
]
++ (with pkgs; [
  niri
  cosmic-session
  ion-shell-session
  nushell-session
  brush-session
])
++ [
  mjsh-session
  leftwm-xsession
  plasma-x11-xsession
];
```

The two `*-hidden` packages come **first**, because `symlinkJoin` keeps the first copy of a file. Each ships a `NoDisplay`/`Hidden` desktop entry that shadows a broken or duplicate upstream one:

- **`gnome-wayland`:** a duplicate of `gnome.desktop` with a different localized name
- **`plasmax11`:** runs `startplasma-x11` without Xorg and fails with "$DISPLAY is not set". The working entry is `plasma-x11-xsession` (§8.2.1)

GNOME's session is registered automatically by its NixOS module. GNOME on X11 isn't offered, because gnome-session 49 ships no `xsessions/`.

### 8.4 greetd Environments

`/etc/greetd/environments` uses the same `start-<de>` naming throughout:

```
start-niri
start-cosmic
start-plasma
start-plasma-x11
start-gnome
start-leftwm
nu
brush
ion
/home/mj/.local/bin/mjsh
```

### 8.5 PAM

`security.pam.services.greetd.enableGnomeKeyring = true`. The password typed at greetd unlocks the login keyring through `pam_gnome_keyring`. Fingerprint authentication is therefore **denied** for `greetd` and TTY `login` in `modules/hardware/fingerprint.nix`: a fingerprint login would start a session with the keyring still locked, and Chromium-family browsers would then create fresh Safe Storage keys and lose saved logins. The keyring prompter is `pkgs.gcr_3 or pkgs.gcr`, in that order (`modules/core/keyring.nix`, CONSTRAINTS.md #32).

---

## 9. Desktop Environments

All desktop modules are imported by `modules/desktops/default.nix` and toggled under `steelbore.desktops.*`. Enabling several desktops at once (the "kitchen sink") is intentional: `hosts/common.nix` enables GNOME, COSMIC, Plasma, Niri and LeftWM together, plus the three helper modules (`cosmicUnmax`, `niriUnmax`, `mouseWorkspaceNav`). greetd (`modules/login`) is the display manager for all of them.

**Composition guards** (`modules/desktops/assertions.nix`) deliberately do **not** enforce mutual exclusivity — they assert only the genuine invariants, so a future edit cannot silently produce a broken session: LeftWM requires `services.xserver.enable` (X11-only, via startx); Niri and COSMIC require greetd (their only route in); GNOME requires greetd **or** GDM and Plasma greetd **or** SDDM (their native DMs are only `mkDefault`-disabled). Each helper module asserts the desktop(s) it serves.

**Portal routing:** each full DE adds an explicit `xdg.portal.config.<de>` block so that, with several DEs installed, interfaces resolve deterministically for the active session instead of spilling over from another DE's `configPackages`. Niri keeps the upstream module default (`gnome;gtk`); LeftWM gets `gtk` plus Secret → `gnome-keyring` in `modules/theme/dark-mode.nix`.

### 9.1 GNOME (Wayland)

**Option:** `steelbore.desktops.gnome.enable`

**Services:** `services.xserver.enable = true`; `services.desktopManager.gnome.enable = true`; `services.displayManager.gdm.enable = lib.mkDefault false` (greetd used instead). GNOME 50 is always Wayland, so `gdm.wayland` is no longer set.

**Extensions (14 enabled):**
  caffeine, just-perfection, window-gestures, wayland-or-x11, toggler, vim-alt-tab, open-bar, tweaks-in-system-menu, launcher, window-title-is-back, yakuake, forge, warp-toggle, resource-monitor

**Tiling:** `forge` is *the* tiling extension. `tiling-shell`, `smart-tiling` and `simple-tiling` stay commented out because they conflict with forge; re-enabling one means disabling forge first. `ollama-indicator` is also commented out.

**Utilities:** gnome-tweaks, dconf-editor, gnome-extension-manager, gnome-browser-connector

**Portals:** the NixOS GNOME module registers the gnome + gtk portals; routing is `gnome`, `gtk`.

**Excluded packages:** gnome-tour, gnome-music, epiphany, geary, totem

### 9.1a Mouse side-button workspace nav (`modules/desktops/mouse-workspace-nav.nix`)

**Option:** `steelbore.desktops.mouseWorkspaceNav.enable` (plus `…ignoredDevices` and the read-only `…command`)

Makes the two thumb buttons (`BTN_SIDE`/`BTN_EXTRA`) switch workspaces under **GNOME, Plasma, COSMIC and LeftWM**. Direction is deliberate: **back goes right, forward goes left** — do not "fix" it; `users/mj/niri.nix` is swapped to match and the two must move together.

Only Niri can bind a mouse button natively; Mutter, KWin and cosmic accept keyboard accelerators only, and no nixpkgs GNOME extension binds side buttons. The remap therefore happens **below the compositor** via `xremap` (Rust, `--watch=device` so a Bluetooth mouse reconnecting after suspend is picked up), emitting **Super+Ctrl+Left/Right** — already the shipped default in Plasma and COSMIC, so only GNOME needed a binding, appended to its stock list in `users/mj/desktop-theme.nix` rather than replacing it. LeftWM binds it to `FocusPreviousTag`/`FocusNextTag`.

**Niri is deliberately excluded:** it handles the buttons natively, and xremap grabs and re-emits the device, so a unit on `graphical-session.target` would consume them first. The unit is wanted only by the GNOME, COSMIC and Plasma session targets (CONSTRAINTS.md #29).

**Blast radius:** xremap grabs every device it listens to, so all input is proxied through it; `Restart=on-failure` makes a crash cost a keystroke rather than the session. **Pointing sticks must be ignored** (a grabbed TrackPoint loses libinput's middle-button scrolling); `ignoredDevices` feeds `xremap --ignore`, and the ThinkPad sets its TrackPoint in `hosts/thinkpad/default.nix`.

**LeftWM is the other exception** (startx, no systemd graphical session): its theme `up` hook starts the same command — exposed as the read-only `…command` option so the two cannot drift — and `down` kills it by pidfile.

Requires `hardware.uinput.enable` plus `uinput` group membership (`input` alone covers only reading real devices).

### 9.2 COSMIC (Wayland)

**Option:** `steelbore.desktops.cosmic.enable`

**Services:** `services.desktopManager.cosmic.enable = true`; `services.displayManager.cosmic-greeter.enable = false` (greetd used).

Fully Rust-based desktop from System76. The upstream module wires portals, dconf and D-Bus; this module adds only explicit portal routing (Screenshot/ScreenCast → `cosmic`, FileChooser → `gtk`) — without it, with GNOME and Plasma also enabled, requests could resolve to the wrong backend.

**Theming:** Home Manager writes cosmic-theme **Builder** overrides for Dark and Light from Standard §11.1 role tokens via `lib/palette.nix`'s converter: the active palette supplies its own polarity and its Standard §11.6.2 `counterpart` (Steelbore Modern → `steelbore-navywhite`) supplies the other, so both builders use registered, contrast-verified values and cannot drift from the palette; `cosmic-settings-daemon` applies them without logout. `auto_switch` is on for time-of-day dark/light; `is_dark` is deliberately **not** managed, because the daemon must be able to flip it and cannot write a read-only store symlink.

### 9.3 KDE Plasma 6 (Wayland)

**Option:** `steelbore.desktops.plasma.enable`

**Services:**

- `services.desktopManager.plasma6.enable = true`
- `services.displayManager.sddm.enable` / `sddm.wayland.enable = lib.mkDefault false` (greetd used)
- `services.xserver.enable = true` (XWayland support)
- `programs.ssh.askPassword = lib.mkForce …ksshaskpass` (avoids askpass conflicts when multiple desktop modules are enabled)

**KDE packages:**
kdeconnect-kde, plasma-systemmonitor, filelight, kcalc, ark, kate, kwalletmanager, kwallet, pinentry-qt, krohnkite (KWin tiling script). `plasma-browser-integration` comes from the Plasma 6 module. Firefox (system Mozilla manifest) and the Flatpaks on Plasma's own list (Chrome among them) are registered by Plasma; `users/mj/browser-integration.nix` registers Brave, Edge and Opera through a relay that calls Plasma's `FlatpakIntegrator.Link` (bus permission in `modules/packages/flatpak.nix`), and BrowserOS directly. Tor Browser is left out on purpose. The KDE portal is registered by the Plasma 6 module itself; routing is `kde`, `gtk` with FileChooser → `kde`.

**Excluded packages:** oxygen, elisa, khelpcenter

### 9.4 Niri (Wayland -- Scrolling Tiling)

**Option:** `steelbore.desktops.niri.enable`

**Service:** `programs.niri.enable = true`

**Companion packages** (`modules/desktops/niri.nix` — the stack matches LeftWM where cross-platform: eww, dunst):
niri, xwayland-satellite, eww (status bar), anyrun (launcher), dunst (notifications), gtklock (locker), swayidle, wl-clipboard, wl-clipboard-rs, grim, slurp, swayosd (OSD for the XF86 keys — Niri has no built-in daemon), polkit_gnome (auth agent — Niri needs one explicitly), and the wallpaper daemon `pkgs.awww or pkgs.swww` (upstream rename; the `or` picks per channel).

**Niri Configuration** (`~/.config/niri/config.kdl`, single source via `users/mj/niri.nix` — niri prefers the user config over `/etc/niri`, so a system copy would be dead and previously drifted). The wrappers, brightnessctl udev rule and dunst config live in `modules/desktops/shared.nix` (§9.6). `XDG_CURRENT_DESKTOP "niri"` routes portal lookups.

Output: `eDP-1` is pinned to `scale 1.0` — niri's `auto` picks 1.25 for this ~157 DPI panel, laying the desktop out as 1536x864 and blurring Xwayland and every client without fractional scaling.

Layout: gaps 8, focus-ring width 2 (active: `foreground` role, inactive: `accent` role), borders off, default column width 50%, center-focused-column on-overflow.

Window rule: `open-maximized false` **and** `open-maximized-to-edges false` globally, because clients (Chrome, Electron apps) re-request a persisted maximize on launch and override the default column width; since niri 25.11 that request is refused only by the second flag. `open-fullscreen` is left alone so media players can still launch fullscreen.

**Self-maximizing clients** (`modules/desktops/niri-unmax.nix`, `steelbore.desktops.niriUnmax.enable`): the rule is map-time only — Chrome maps at tile size, then requests maximize a moment later, and `max-width` does not cap it. **steelbore-niri-unmax** (`pkgs/steelbore-niri-unmax/`, Rust) is an event-driven systemd **user** service on the niri IPC stream that toggles maximized-to-edges back off only inside a short post-open grace window, after a settle and re-confirm (the action is a toggle), so a maximize the user performs later is never touched. Detection is geometric and so **requires `gaps > 0`**; fullscreen is exempt; it exits 0 outside niri and holds a single-instance lock so two copies cannot double-toggle.

**Self-maximizing clients under COSMIC** (`modules/desktops/cosmic-unmax.nix`, `steelbore.desktops.cosmicUnmax.enable`): COSMIC has no setting or window rule to refuse a client's `set_maximized` at map time. **steelbore-cosmic-unmax** (`pkgs/steelbore-cosmic-unmax/`, Rust + wayland-client) is a user service bound to `cosmic-session.target`. It is a sibling rather than a backend switch of the niri daemon because the transports share nothing (JSON IPC vs Wayland protocols); detection is explicit via `zcosmic_toplevel_handle_v1.state`, so no `gaps > 0` precondition. The protocol XMLs are vendored so the crate builds from crates.io alone, and pre-existing windows are settled after the first roundtrip so a window maximized before login is not reverted.

**Startup** (`spawn-at-startup`, in order): the wallpaper daemon, then the Steelbore wallpaper from `~/Pictures/Wallpapers/Steelbore/` (not Nix-managed, so it falls back to a `background`-role fill); `eww open bar` (§9.4.1); `dunst`; `swayosd-server`; `swayidle -w`; `gitway-add ~/.ssh/id_ed25519`; the polkit-gnome agent; and a delayed `steelbore-keyring-check`, which runs before any browser can mint a fresh Safe Storage key off a broken keyring.

Input: keyboard layouts `us,ara` (switched by `Mod+Space`; `grp:ctrl_space_toggle` is kept for X11 parity), touchpad with tap/natural-scroll/accel-speed 0.3.

Key bindings (Mod = Super; primary binds carry `hotkey-overlay-title`, aliases are silent):

- **Session:** `Mod+Shift+E` quit, `Mod+Shift+L` lock (gtklock), `Mod+Shift+C` Caffeine (pauses swayidle), `Mod+Shift+Slash` hotkey overlay, `Mod+Shift+U` keyring unlock (rescue — `pam_gnome_keyring` normally unlocks at login)
- **Idle:** swayidle locks at 5 min, powers off monitors at 6 min, locks before suspend
- **Applications:** `Mod+Return` alacritty, `Mod+D` anyrun; `Mod+B`/`Mod+Shift+B` bluetui/overskride, `Mod+A`/`Mod+Shift+A` wiremix/pavucontrol
- **Windows:** `Mod+Q` close, `Mod+F` maximize column, `Mod+Shift+F` fullscreen, `Mod+V` / `Mod+Shift+V` floating, `Mod+O` overview
- **Focus / move:** `Mod+Arrows` or Vim keys; `Mod+Ctrl+Arrows` move (`Mod+Shift+L` is reserved for gtklock); `Mod+BracketLeft/Right` consume/expel
- **Workspaces:** `Mod+1-9` focus, `Mod+Shift+1-9` move column, `Mod+Page_Down/Up` (+`Ctrl` to move), `Mod+Tab` previous
- **Mouse side buttons** (no Mod): back → column right, forward → column left, matching the other desktops' horizontal direction since Niri's workspaces stack vertically. Binding without Mod costs browser back/forward, because niri grabs the buttons compositor-wide.
- **Resize / scale:** `Mod+R` preset, `Mod+Minus/Equal` ∓10%; `Mod+Shift+Minus/Equal` steps the output scale live via `steelbore-output-scale` (forgotten on config reload — the persistent value is the `output` block)
- **Screenshots:** `Print`, `Mod+Print` window
- **XF86 keys** (hidden from the overlay; all but media `allow-when-locked`): brightness and volume via `swayosd-client` (volume capped at 100%); mic mute via `wpctl` then swayosd for the OSD only (swayosd's own mic toggle is a no-op here); media via `playerctl`; keyboard backlight via `steelbore-kbd-light-cycle` / `brightnessctl`; radios via `steelbore-bt-toggle` / `steelbore-airplane-toggle` (rootless rfkill, dunst feedback). The swayosd OSD is themed from role tokens in `users/mj/niri.nix`.

#### 9.4.1 Niri status bar (Eww, `users/mj/eww.nix`)

A 32 px exclusive top bar opened by `eww open bar`. Left: `STEELBORE OS :: BRAVAIS`. Centre: clock in `%Y-%m-%d %H:%M:%S` plus the UTC offset, so the reading is unambiguous. Right: keyboard language, Bluetooth three-state glyph, Caffeine, network link, the hardware indicators, and CPU/RAM/battery with warn/critical thresholds.

Audio, mic, backlight and Caps/Num Lock come from one event-driven `deflisten` on **`steelbore-beacon`** (`pkgs/steelbore-beacon`). There is deliberately **no FnLock indicator** — the ThinkPad EC exposes nothing to read (CONSTRAINTS.md #25). Colours come from role tokens; only `//` comments are allowed in `eww.scss` (CONSTRAINTS.md #26), and the Niri and LeftWM bars are kept in step.

### 9.5 LeftWM (X11 -- Tiling WM)

**Option:** `steelbore.desktops.leftwm.enable`

**Services:** `services.xserver.enable = true`, `services.xserver.displayManager.startx.enable = true`. LeftWM is intentionally **not** registered via `services.xserver.windowManager.leftwm.enable`: that xsession runs `leftwm` directly, and since greetd does not start Xorg, leftwm panics in a respawn loop. `modules/login/default.nix` registers its own xsession that wraps LeftWM in `startx`.

**Companion packages:**
leftwm, leftwm-theme, leftwm-config, rlaunch, rofi, dmenu, eww, picom, dunst, xss-lock + i3lock (`programs.i3lock`), feh, xclip, xsel, maim, xdotool, numlockx, xkb-switch (layout for the eww language indicator)

**LeftWM Configuration** (`~/.config/leftwm/config.ron`, written by Home Manager from `modules/desktops/leftwm.nix`):

- Modkey and mousekey Mod4 (Super); tags 1-9; layout mode Tag, insert Bottom; sloppy focus; scratchpad "Terminal" (alacritty)
- `layouts` is **intentionally omitted**: lefthk-core and leftwm-core expect incompatible schemas, and a lefthk parse failure silently falls back to a default keymap that turns every Mod-only bind into a no-op.

Key bindings:

- **Session:** `Mod+Shift+E` kill session, `Ctrl+Alt+L` lock (`loginctl lock-session` → xss-lock → i3lock), `Mod+Shift+C` Caffeine, `Mod+Shift+U` keyring unlock (rescue)
- **Idle:** xss-lock (started by `leftwm-session-inner`) runs i3lock when the X screensaver fires at 300 s and before sleep; DPMS powers the panel off at 360 s — the same timings as Niri's swayidle. gtklock cannot run under X (CONSTRAINTS.md #45).
- **Applications:** `Mod+Return` alacritty (rio renders blank under startx-spawned Xorg), `Mod+D` rlaunch, `Mod+Shift+D` rofi
- **Windows:** `Mod+Q` close, `Mod+F` fullscreen, `Mod+Shift+F` float
- **Focus / move:** `Mod+K/J` or `Mod+Up/Down`; `Mod+Shift+K/J`. Up/down only: lefthk-core lacks the Left/Right commands and one panics its parser, disabling every bind; sloppy focus and tile-drag cover left/right.
- **Layouts / workspaces:** `Mod+Space` / `Mod+Shift+Space` cycle layouts; `Mod+1-9` goto, `Mod+Shift+1-9` move; `Mod+Ctrl+Left/Right` previous/next tag (the side-button combo, §9.1a)
- **Resize / scratchpad:** `Mod+Equal/Minus` ±5 main width; `Mod+Grave` scratchpad terminal
- **Screenshots:** `Print` region, `Mod+Print` full screen — to `~/Pictures/Screenshots/` with an ISO timestamped name, and to the clipboard
- **Multimedia / hardware keys** mirror Niri, but without `allow-when-locked` (lefthk-core has no analog) and with `steelbore-osd` dunstify popups since swayosd is Wayland-only. `Mod+Shift+Slash` shows a rofi keybinding help list, kept by hand in sync because lefthk-core has no introspection.

**Theme** (`~/.config/leftwm/themes/current` — one symlink to a store derivation, because leftwm intermittently fails to find `current/up` when `current` is a real directory):

- `theme.ron`: border width 2, margin 8; borders from the `accent` (default), `info` (floating) and `foreground` (focused) roles
- `up`: starts picom, dunst and the eww bar (here, so the GTK dock registers with an active WM), plus the xremap command when `mouseWorkspaceNav` is on; `down` kills that xremap so it cannot keep holding the mouse after the session ends

**Session bring-up** (`leftwm-session-inner`): numlockx, `gitway-add`, the polkit agent (not in `up`, which re-runs on every `LoadTheme` and would accumulate agents), a delayed keyring check, then an explicit `LoadTheme` (leftwm does not auto-load it and falls back to red) and a `background`-role root fill (leftwm clobbers the root to grey).

**Status bar:** `eww open bar --config ~/.config/eww-leftwm` — a LeftWM-specific config (clickable workspace tags via `leftwm-state`, window title, the same indicators as the Niri bar, and a systray), kept under `eww-leftwm/` so it does not collide with `users/mj/eww.nix`.

**Picom** (`picom.conf`): GLX backend, vsync, inactive opacity 0.95, fading (delta 5), no shadows, no rounded corners.

### 9.6 Shared bare-WM services (`modules/desktops/shared.nix`)

Config and wrappers used by **both** bare window managers live here — active when Niri **or** LeftWM is enabled — so disabling one WM cannot silently strip the other's config.

**Dunst** (`/etc/dunst/dunstrc`): 350x150, top-right, Hack Nerd Font 12, 2 px `accent`-role frame; urgencies on the `background` role with `info` (low), `foreground` (normal) and `error` (critical, no timeout) text. Bluetooth-off uses critical urgency so it is as unmistakable as the toggle-on event.

**Wrappers on PATH:**

- `steelbore-bt-state` — `off` / `on` / `connected`, one truth source for the bar and the toggle
- `steelbore-bt-toggle`, `steelbore-airplane-toggle` — rfkill toggles with dunstify feedback that replaces rather than stacks
- `steelbore-caffeine` — pauses swayidle under Niri; under LeftWM it clears the X idle timers through `steelbore-x-idle`, which also arms them at session start (CONSTRAINTS.md #45)
- `steelbore-kbd-light-cycle`, `steelbore-output-scale`, `steelbore-layout-state`, `steelbore-osd` (LeftWM's X11 OSD)
- `steelbore-keyring-check` — read-only keyring diagnosis, safe unattended, with distinct exit codes for a wrong `default` alias, a locked keyring, and dangling items
- `steelbore-keyring-unlock` — drives the Secret Service Unlock prompt through one long-lived D-Bus client, so the password is collected by gcr-prompter and never enters the script, replacing the old path that killed the PAM-seeded daemon (CONSTRAINTS.md #32)
- Plus `brightnessctl` and `playerctl`.

**Backlight ACL:** `services.udev.packages = [ pkgs.brightnessctl ]` makes display and keyboard backlight group-writable, so both are controllable rootless; swayosd-server relies on the same rule.

---

## 10. Terminal Emulators (`modules/packages/terminals.nix`)

Enabled by `steelbore.packages.terminals.enable` (set in `hosts/common.nix`). Every Nix-installed terminal whose colours Bravais can set from a config file is themed from the active Steelbore palette's Standard §11.1 role tokens (via `steelborePalette`, resolved by `lib/palette.nix` from `steelbore.toml` in the `construct` input) — Termius is themed in-app only, and WaveTerm is an unthemed AppImage (§10.1) — and where Bravais sets or inherits the shell, it launches Nushell — most via an explicit `${pkgs.nushell}/bin/nu` at the system and user level, the rest by inheriting `$SHELL`, which is the mjsh login shell (see **Shell** in §10.3).

**Single source:** the terminal theme exists once, in `lib/terminal-theme.nix` — one data record (`theme`: the 16-colour ANSI table from `lib/palette.nix`, background/foreground, cursor and selection roles, font, opacity, scrollback) plus one small emitter per config format (`tt.foot`, `tt.ghostty`, `tt.weztermLua`, `tt.rioToml`, `tt.alacrittyToml`, `tt.alacrittyColors`, `tt.konsoleColorscheme`/`tt.konsoleColorschemePlain`, `tt.konsoleProfile`, `tt.xfce`, `tt.xresources`/`tt.xresourcesProps`, `tt.warpYaml`, `tt.cosmicTermScheme`, and `tt.ansi16`, the flat 16-entry list Ptyxis uses). Both `modules/packages/terminals.nix` and `users/mj/terminals.nix` import it, so a palette change is a one-file edit that reaches every terminal in lockstep. Font and opacity changes are too, except for literals in `users/mj/terminals.nix` that bypass the `theme` record and must be edited by hand: the Home Manager Alacritty font family and opacity, the Ptyxis font and opacity (dconf), and the GNOME Console font. All per-format colour conversion (bare hex, decimal R,G,B) happens inside the emitters. The emitters were migrated to reproduce the earlier hand-written configs byte-for-byte, so their formatting quirks are deliberate.

**Default terminal:** Alacritty (`Mod+Return`) under both Niri and LeftWM. LeftWM requires it: Rio's wgpu backend renders blank under LeftWM's startx-spawned Xorg (rationale in `modules/desktops/leftwm.nix`). Rio stays installed and themed.

### 10.1 Terminal Package List

Taken from `environment.systemPackages` in `modules/packages/terminals.nix`, plus Warp and WaveTerm (AppImages, installed outside Nix).

| Terminal       | Package                     | Language | Category   |
|----------------|-----------------------------|----------|------------|
| Alacritty      | `alacritty`                 | Rust     | Primary (default) |
| WezTerm        | `wezterm`                   | Rust     | Primary    |
| Rio            | `rio`                       | Rust     | Primary    |
| Ghostty        | `ghostty`                   | Zig      | Primary    |
| Ptyxis         | `ptyxis`                    | C (VTE)  | GNOME — host install so distrobox/container integration works out of the box |
| Warp           | — (AppImage in `~/Applications/`) | Rust | AI-powered — not a Nix package: the self-updating AppImage replaced nixpkgs' `warp-terminal`, which lagged months behind and put a second "Warp" in the app menu; Bravais still ships its theme YAML |
| Termius        | `termius`                   | —        | SSH client (no system-level theming; configured in-app) |
| COSMIC Term    | `cosmic-term`               | Rust     | COSMIC     |
| Konsole        | `kdePackages.konsole`       | C++      | KDE        |
| Yakuake        | `kdePackages.yakuake`       | C++      | KDE drop-down (Konsole backend) |
| GNOME Console  | `gnome-console` (kgx)       | C        | GNOME      |
| Foot           | `foot`                      | C        | Wayland    |
| XTerm          | `xterm`                     | C        | X11        |
| XFCE4 Terminal | `pkgs.xfce4-terminal or pkgs.xfce.xfce4-terminal` | C | XFCE — top-level on unstable, under `xfce.` on stable; the `or` fallback evaluates on both channels (CONSTRAINTS.md #5) |
| WaveTerm       | — (AppImage in `~/Applications/`) | Go | AI-native — not a Nix package: nixpkgs-unstable removed `waveterm` (EOL Electron), so the package, `/etc/waveterm/config.json` and its generator were dropped; the AppImage runs through the binfmt AppImage handler (§12.4) and is not themed by Bravais |

### 10.2 System-Level Configuration Files

`modules/packages/terminals.nix` writes these under `/etc/` as system-wide fallbacks. Where a user-level file also exists (§10.4), the user-level one wins.

| Terminal       | Config Path                                      | Format  | Source |
|----------------|--------------------------------------------------|---------|--------|
| Alacritty      | `/etc/alacritty/alacritty.toml`                  | TOML    | `tt.alacrittyToml` |
| WezTerm        | `/etc/wezterm/wezterm.lua`                       | Lua     | `tt.weztermLua` |
| Ghostty        | `/etc/ghostty/config`                            | key = value | `tt.ghostty` |
| COSMIC Term    | `/etc/cosmic/com.system76.CosmicTerm/v1/syntax_theme_dark` | RON (`"Steelbore"`) | inline |
| COSMIC Term    | `/etc/cosmic/com.system76.CosmicTerm/v1/color_schemes_dark` | RON | `tt.cosmicTermScheme` |
| COSMIC Term    | `/etc/cosmic/com.system76.CosmicTerm/v1/profiles` (profile 0: Nushell command, Steelbore scheme) | RON | inline |
| COSMIC Term    | `/etc/cosmic/com.system76.CosmicTerm/v1/default_profile` (`Some(0)`) | RON | inline |
| Ptyxis/VTE     | `/etc/gtk-4.0/gtk.css` (10px `vte-terminal` padding only — colours come from dconf, §10.4) | CSS | inline |
| Warp           | `/etc/warp/themes/steelbore.yaml`                | YAML    | `tt.warpYaml` |
| Konsole        | `/etc/xdg/konsole/Steelbore.colorscheme`         | INI     | `tt.konsoleColorscheme` |
| Konsole        | `/etc/xdg/konsole/Steelbore.profile`             | INI     | `tt.konsoleProfile` |
| Konsole        | `/etc/xdg/konsolerc` (default profile = Steelbore, tab bar on top, no new-tab button) | INI | inline |
| Yakuake        | `/etc/xdg/yakuakerc`                             | INI     | inline |
| Foot           | `/etc/xdg/foot/foot.ini`                         | INI     | `tt.foot` |
| XTerm          | `/etc/X11/Xresources`                            | Xresources | `tt.xresources` |
| XFCE4          | `/etc/xdg/xfce4/terminal/terminalrc`             | INI     | `tt.xfce` |

Rio has **no** system-level file — it is configured at the user level only (§10.4). Termius, GNOME Console and WaveTerm have none either.

cosmic-term shlex-splits `profile.command` for the PTY, so a single `/nix/store` path with no spaces yields one program token and no arguments — which is why the profile names the Nushell binary directly.

### 10.3 Common Terminal Settings

All values below come from the `theme` record and emitters in `lib/terminal-theme.nix` unless noted.

- **Font:** JetBrainsMono Nerd Font (`theme.font`) — pinned; UI font is separate (Hack Nerd Font, `modules/theme/fonts.nix`). Sizes:
  - 12 — Foot, XTerm, XFCE4 Terminal, Ghostty, WezTerm (`12.0`), Konsole profile, Ptyxis and GNOME Console (dconf)
  - 10 — Alacritty (both the `/etc` TOML and the Home Manager settings)
  - 14 — Rio
- **Opacity:** `0.95` (`theme.opacity`) — used by Alacritty, WezTerm, Ghostty, Rio, XFCE4 (`BackgroundDarkness`), and the Konsole colorscheme. The Home Manager Alacritty settings and Ptyxis (dconf) hardcode `0.95` in `users/mj/terminals.nix` instead of reading `theme.opacity`.
- **Padding:** 10px — Alacritty, WezTerm, Ghostty (`window-padding-x/y`), XTerm (`internalBorder`), Ptyxis/VTE (`gtk.css`).
- **Scrollback:** 10000 lines (`theme.scrollback`) — Foot, XTerm, XFCE4.
- **Colour roles:** background/foreground from the matching role tokens; cursor = foreground on background; selection = accent background with background-coloured text. Alacritty's `/etc` TOML also uses `success` for the vi-mode cursor and focused search match, and `info` for search matches.
- **Shell:** the explicit path `${pkgs.nushell}/bin/nu` goes to Alacritty, WezTerm, Ghostty, Rio, Foot, XFCE4 Terminal, Konsole and COSMIC Term (via each emitter's `shell` argument or the terminal's own shell/command key), plus Yakuake, which gets it through the Konsole `Steelbore.profile` `Command=` (its `yakuakerc` sets `DefaultProfile=Steelbore.profile`). GNOME Console, XTerm (`XTerm*loginShell: true` with no shell set) and Ptyxis (its dconf profile sets no custom command) get no explicit path and inherit `$SHELL` (the mjsh login shell; one started from a Nushell prompt gets bash, §13.7). Warp is outside both groups: only a theme YAML is shipped, so Bravais does not set its shell and it uses Warp's own default/login-shell detection.
- **Foot quirk:** colours are bare hex without a `#` prefix — handled inside the `tt.foot` emitter via `convert.bareHex` from `lib/palette.nix`.
- **Konsole quirk:** colours are decimal `R,G,B` triples via `convert.rgbTriple`; the scheme carries Normal/Faint/Intense variants per slot (Intense = the bright ANSI colour, bold).
- **Rio font config:** Mono variant (`"JetBrainsMono Nerd Font Mono"`) for regular/bold/italic/bold-italic with `weight = N` integers (400 regular, 700 bold) and no `style` key, plus `Symbols Nerd Font` / `Symbols Nerd Font Mono` extras. The Mono variant is enforced by `tt.rioToml` because the proportional face renders icons wider than one cell (CONSTRAINTS.md #11). The same constraint records Rio's upstream bug: closing it with the X or a WM close keybind hangs at 100% CPU on Wayland — type `exit` instead.
- **Konsole:** profile with 160×48 geometry, unlimited history (`HistoryMode=2`), blinking cursor.
- **XFCE4 Terminal:** 160×48 default geometry, transparent background, no menubar or scrollbar.
- **Yakuake:** height 50%, width 100%, no keep-open, no animation, default profile `Steelbore.profile` (inherits the Konsole colours and shell).
- **GNOME Console:** colour theme is fixed by kgx (`night` / `day` / `auto` only) — `night` is used; only the font is customised.

### 10.4 User-Level Configs (Home Manager, `users/mj/terminals.nix`)

Home Manager additionally writes user-level terminal configs, rendered through the same `lib/terminal-theme.nix` emitters:

| Terminal       | Mechanism | Path / Keys |
|----------------|-----------|-------------|
| Alacritty      | `programs.alacritty.settings` (structured Nix; colours from `tt.alacrittyColors`) | `~/.config/alacritty/` |
| WezTerm        | `xdg.configFile` (`tt.weztermLua` — one canonical body shared with `/etc`) | `~/.config/wezterm/wezterm.lua` |
| Rio            | `xdg.configFile` (`tt.rioToml`) | `~/.config/rio/config.toml` |
| Ghostty        | `xdg.configFile` (`tt.ghostty`) | `~/.config/ghostty/config` |
| Foot           | `xdg.configFile` (`tt.foot`) | `~/.config/foot/foot.ini` |
| XFCE4 Terminal | `xdg.configFile` (`tt.xfce`) | `~/.config/xfce4/terminal/terminalrc` |
| Konsole        | `xdg.configFile` + `xdg.dataFile` (`tt.konsoleColorschemePlain`, `tt.konsoleProfile`) | `~/.config/konsolerc`, `~/.local/share/konsole/Steelbore.{colorscheme,profile}` |
| Yakuake        | `xdg.configFile` | `~/.config/yakuakerc` |
| COSMIC Term    | `xdg.configFile` with `force = true` | `~/.config/cosmic/com.system76.CosmicTerm/v1/{profiles,default_profile}` |
| XTerm          | `xresources.properties` (`tt.xresourcesProps`, the attrset twin of `tt.xresources`) | `~/.Xresources` |
| Ptyxis         | `dconf.settings` | `org/gnome/Ptyxis` (font, default profile) + `org/gnome/Ptyxis/Profiles/steelbore` (16-colour `tt.ansi16` palette, background/foreground roles, opacity 0.95) |
| GNOME Console  | `dconf.settings` | `org/gnome/Console` (`theme = "night"`, custom font) |

**Why COSMIC Term is owned at the user level:** cosmic-config layers per key with the **user** file winning over `/etc/cosmic`, and cosmic-term writes its own `profiles` file into `~/.config` (profile 0 with an empty command, meaning `$SHELL`), which shadows the system default. Home Manager therefore owns `profiles` and `default_profile` so cosmic-term always launches Nushell on the Steelbore scheme; `force = true` overwrites the app-written file without a backup deadlock (CONSTRAINTS.md #30).

The Niri, eww and dunst configs are not terminal configs. The Niri and eww configs live in `users/mj/niri.nix` and `users/mj/eww.nix`; the dunst config lives in `modules/desktops/shared.nix` (shared with LeftWM) (see the desktop sections).

---

## 11. Package Inventory

Every bundle below is an opt-in `steelbore.packages.<name>` module (`lib.mkEnableOption`)
imported by `modules/packages/default.nix` and switched on in `hosts/common.nix`. Package
lists are taken from the `.nix` files; `modules/packages/flatpak.nix` is the authoritative
Flatpak list (§11.10). Delivery policy: an app ships from nixpkgs **unless** it is a huge
source build (Chromium-family browsers, VLC, LibreOffice) or a sandbox-hostile /
self-updating GUI (VS Code, RustRover) — then Flatpak. Never both, with two deliberate
exceptions (VSCodium, §11.2; Ptyxis, §10.1).

### 11.1 Browsers (`modules/packages/browsers.nix`)

- **BrowserOS** (Chromium/AppImage) — agentic browser shipped upstream only as an x64
  AppImage; packaged inline with `appimageTools.wrapType2` (pinned `fetchurl` + SRI hash)
  so it runs reproducibly from the Nix store rather than as a loose AppImage. Bumped only by
  `nu pkgs/update-vendored.nu browseros` (pin: `browserosVersion` in the module)
- **Tor Browser** (`unstablePkgs.tor-browser`) — nixpkgs, as it repacks the Tor Project's
  prebuilt tarball and substitutes from cache; unstable, because a stale Tor Browser misses
  Firefox-ESR security patches (its updater is disabled, so only `nix flake update
  nixpkgs-unstable` moves it). Not bound to the `browser` role: every link would go via Tor
- **Firefox** (`programs.firefox.enable = true`) — from nixpkgs, not Flathub: the march
  level never touches the system nixpkgs, so it substitutes from cache; `programs.firefox`
  also carries the policy and native-messaging-host plumbing
- **Flatpak browsers** (§11.10): Google Chrome, Microsoft Edge, Opera, Brave. LibreWolf and
  Zen are commented out — not installed. Their keyring override is in §11.10

### 11.1a Orca computer-use (`modules/packages/orca.nix`)

The AT-SPI accessibility stack backing Orca's computer-use feature, gathered behind
`steelbore.packages.orca` so the whole set is removed with one toggle when Orca goes. Do
not migrate individual entries into `ai.nix` or `system.nix` — that is the coupling this
module exists to prevent.

- **python3Packages.pygobject3** — Python GObject/`gi` bindings
- **python3Packages.pyatspi** — Python AT-SPI bindings
- **at-spi2-core** — the AT-SPI accessibility bus/runtime
- **gobject-introspection** — supplies the runtime typelibs `gi` needs
- **`orca-python`** — a wrapped interpreter that can actually `import pyatspi`: system-wide
  `python3Packages.*` never reach `sys.path`. Rejected: a global `PYTHONPATH` (leaks into
  every Python) and replacing `python3` (`ignoreCollisions` picks an arbitrary winner)

The AT-SPI bus comes from GNOME's `services.gnome.at-spi2-core` — this module's to state if
GNOME goes. Orca itself is a self-updating AppImage (the CONSTRAINTS.md #4 class);
`pkgs.orca` is the unrelated GNOME **screen reader**, not installed here.

### 11.1b Codex Desktop (`pkgs/codex-desktop/`)

Installed by the AI bundle (§11.9). OpenAI's official Codex app (upstream package
`chatgpt`), repackaged from the amd64 `.deb` as `codex-desktop`; unfree. Three decisions:

- **No versioned URL** — upstream publishes only a `latest` `.deb`, so the pin breaks
  whenever OpenAI ships and the old artifact cannot be refetched; the updater keys off the
  ETag instead (`docs/vendored-binaries.md`).
- **`MimeType` stripped** to its own `x-scheme-handler/codex` — upstream claims http/https
  and office types, which would expose CONSTRAINTS.md #22's cache-ordering failure;
  handlers are decided in `default-apps.nix` alone.
- **Qt shims ignored, musl prebuilds deleted** — rather than pull Qt5+Qt6 into a GTK app's
  closure; the musl trap is CONSTRAINTS.md #15.

### 11.2 Editors (`modules/packages/editors.nix`)

- **Linting:** markdownlint-cli2
- **TUI Editors (Rust):** helix, amp, msedit (MS-DOS style), zee (minimal terminal editor)
- **TUI Editors (Standard):** neovim, vim, mg (micro Emacs), zile (lightweight Emacs clone),
  mc (Midnight Commander)
- **GUI Editors (Rust):** zed-editor, lapce, neovide, cosmic-edit; cosmic-files (COSMIC file
  manager) is also listed here
- **GUI Editors (Standard):** emacs-pgtk (pure-GTK, Wayland-native), gedit. VS Code is the
  Flatpak `com.visualstudio.code` (§11.10), not `vscode-fhs`; RustRover is the Flatpak
  `com.jetbrains.RustRover`.
- **GUI Editors (Unstable, FHS, keyring-wrapped):** code-cursor-fhs, kiro-fhs,
  vscodium-fhs. VSCodium is **also** the Flatpak `com.vscodium.codium` (§11.10) — one of the
  two deliberate exceptions to "never both", by user request; the two copies keep separate
  state. Taken from unstable because stable trails upstream meaningfully.
- **Antigravity** (from the `antigravity-nix` flake input, keyring-wrapped):
  `google-antigravity-desktop` (standalone agent-orchestration app) and `google-antigravity-ide`;
  not the `-with-cli` variants, as `agy` is installed out-of-band. Pin: CONSTRAINTS.md #27.
- **Keyring wrapping (`withKeyring`):** under Niri and LeftWM Chromium/Electron maps
  `XDG_CURRENT_DESKTOP` to "other" and falls back to plaintext credentials, so each Electron
  editor is re-wrapped with `config.steelbore.keyring.chromiumFlag` (`modules/core/keyring.nix`);
  its `.desktop` file still works because `Exec=` resolves through PATH.

### 11.3 Development (`modules/packages/development.nix`)

- **Git & VCS:** git, gitui (Rust), delta (Rust), jujutsu/jj (Rust), gh (Go). GitHub Desktop
  is the Flatpak `io.github.shiftey.Desktop` (§11.10).
- **Forgejo (self-hosted Git):** forgejo (Go), forgejo-cli (Rust), forgejo-runner (Go)
- **Rust Toolchain:** not in this module — per-user in `users/mj/home.nix` (`unstablePkgs`):
  rustup, cargo-update, cargo-watch, cargo-nextest, cargo-audit, sccache, cargo-expand.
  rustc/cargo/rustfmt/clippy/rust-analyzer are rustup shims, never declared separately
  (CONSTRAINTS.md #12).
- **Build & Task (Rust):** just, sad, pueue, tokei
- **Environment:** lorri (Rust), dotter (Rust)
- **Cloud CLIs:** google-cloud-sdk, awscli. azure-cli is commented out (massive dependency
  tree, slow to fetch from cache).
- **Languages:** guile + guile-json (Scheme), jdk, php, python3 + python3Packages.pip,
  nodejs (node/npm/npx), and `unstablePkgs.uv` (Rust — Python package + project manager)
- **Ada Toolchain:** `lib.lowPrio (pkgs.gnat16 or pkgs.gnat)` — GNAT (GCC Ada). `lowPrio` so
  GNAT's bundled compilers yield to the primary `gcc`; the `or` fallback (CONSTRAINTS.md #5)
  keeps the unstable eval working where gnat16 is absent.
- **C/C++ Toolchain & Libraries:** gcc, webkitgtk_4_1 (libwebkit2gtk-4.1, GTK3 — the ABI
  github-copilot-app's Tauri runtime links against), webkitgtk_6_0 (libwebkitgtk-6.0,
  GTK4). Both ABIs coexist (all version-suffixed); the one shared `bin/WebKitWebDriver` is
  settled on 4.1 via `lowPrio` so the winner is explicit, not list-order luck (cf. #12)
- **Nix Ecosystem:** nil (Rust — Nix LSP, `nil` flake input, CONSTRAINTS.md #13), nixfmt
  (Haskell), cachix, nix, nix-prefetch-github (Python). `guix` and `emacsPackages.guix` are
  commented out — not installed.
- **Git system config (`programs.git`):** `init.defaultBranch = "main"`, `color.ui = true`,
  and `core.editor` from the default-apps `termEditor` role — the same entry as `$EDITOR`, so
  `git commit` and the shell agree (§2.6).

### 11.4 Security (`modules/packages/security.nix`)

Enabled by `steelbore.packages.security.enable`.

- **Encryption:** age (Go), rage (Rust), sops (Go)
- **Sequoia PGP Stack (Rust):** sequoia-sq, sequoia-chameleon-gnupg, sequoia-wot, sequoia-sqv, sequoia-sqop
- **Password Managers:** bitwarden-desktop (TypeScript/Electron, official client), rbw (Rust, unofficial Bitwarden CLI — kept for scripting), authenticator (Rust, 2FA/OTP). The desktop client is the **nixpkgs package**; the `com.bitwarden.desktop` Flatpak is commented out (§11.10). The move was about the credential path, not the version.
- **Secret managers from flake inputs:** rapg (Go — AI-agent secret manager; NAR hash mismatch after a source change is CONSTRAINTS.md #10)
- **SSH:** openssh_hpn (general-purpose fallback; ships the OpenSSH tooling, so plain `openssh` is not added beside it), gitway (Spacecraft Software SSH transport for Git, via flake input — primary path). Enabled as `services.gitway-agent.enable` in `modules/core/security.nix`; `gitway-agent` owns `$SSH_AUTH_SOCK` (CONSTRAINTS.md #8), `gitway-keygen` is git's `gpg.ssh.program`, and `gitway-add` replaces `ssh-add`.
- **Backup:** pika-backup (Rust, Borg frontend)
- **Sandboxing:** sydbox (process sandbox / call-policy enforcement)
- **Secure Boot:** sbctl (Rust) — installed, not yet enrolled
- **Nix tooling:** hydra-check (Nix/Hydra build status checker)

#### Bitwarden biometric unlock

Fingerprint unlock has two halves; only the first needs anything from this flake.

**Desktop app** — a polkit check on `com.bitwarden.Bitwarden.unlock`, whose action ships with
`pkgs.bitwarden-desktop`; **never declare it again** (a #12-shaped collision). See §6.1.

**Why not the Flatpak.** A Flatpak encrypts its own credential store with a per-app master
key from the Secret portal, stored in the login keyring; any re-key of that keyring
destroys it, and the app then loops on `Incorrect secret` — an unusable UI rather than a
visible keyring fault (hit 2026-09-15). The unsandboxed client talks to
`org.freedesktop.secrets` directly and has none of this.

**Browser extension** — Bitwarden bridges native messaging via the **browser's own
`NativeMessagingHosts` directory** (proxy copy, manifest, IPC socket), not `flatpak-spawn`:

- **ELF interpreter.** A nixpkgs-built proxy names a `/nix/store` `ld-linux`, and `/nix` is
  not mounted in a Flatpak browser's sandbox, so the exec fails silently. Ways out, in order:
  a host-installed browser; `--filesystem=/nix/store:ro` via `services.flatpak.overrides`
  (widens the sandbox); or desktop-app-only biometrics. **Still an open decision
  (`TODO.md`)**; until then the bridge does not work with the active browser.
- **Browser map.** The client's Flatpak map knows only Firefox, Chrome, Chromium and Edge,
  so the Brave and Opera Flatpaks can never drive the bridge (app-side, not a permission).
  Chrome — the active `browser` role — is in the map.

Once the proxy can execute, enabling it is two runtime toggles, not a rebuild. Bitwarden's
"browser integration fingerprint validation" is a pairing phrase, not fprintd.

### 11.5 Networking (`modules/packages/networking.nix`)

Enabled by `steelbore.packages.networking.enable`.

- **Network Mgmt:** impala (Rust, iwd TUI), iwd
- **HTTP Clients:** xh (Rust), monolith (Rust), curlFull, wget2
- **Diagnostics (Rust):** gping, trippy, lychee, rustscan, sniffglue, bandwhich
- **GUI Apps (Rust):** sniffnet, mullvad-vpn, rqbit (CLI + web UI)
- **Download Managers:** aria2, uget
- **Chat / IRC (Rust):** halloy (iced GUI, multi-server IRCv3), tiny (crossterm TUI)
- **Clipboard:** wl-clipboard, wl-clipboard-rs (Rust)
- **DNS & Services:** dnsmasq, atftp, adguardhome (a DNS blocker — a different product from the VPN below)

#### AdGuard VPN (`modules/services/adguardvpn.nix`)

adguardvpn-cli is deliberately **not** in the networking bundle: `steelbore.services.adguardvpn`
owns the package, the route script and the `steelbore-vpn` teardown helper as one subject,
because they drifted apart while split. `hosts/common.nix` enables it with
`routeScript.enable = true`.

- **Package:** the upstream static binary, vendored in `pkgs/adguardvpn-cli/` (not in
  nixpkgs; unfree). Its own `update` cannot write to the store — bump it with
  `nu pkgs/update-vendored.nu adguardvpn-cli`.
- **Routing mode** (CONSTRAINTS.md #19, #37): `AUTO` rewrites `/etc/resolv.conf` and displaces
  systemd-resolved's DoT + DNSSEC; `NONE` installs no routes, so the tunnel reports
  "connected" while carrying nothing; **`SCRIPT` is the mode this system uses** — the client
  runs our root-owned `0700` script on tunnel up, so we get the routes and resolved keeps the
  DNS. SOCKS mode remains the unprivileged alternative.
- **Route script:** installed root-owned `0700` on every boot by the oneshot
  `steelbore-adguardvpn-route-script` (a tmpfiles `C`/`C+` rule would leave stale contents);
  it adds the split `0.0.0.0/1` + `128.0.0.0/1` pair (so the LAN prefix and the original
  default route survive) and `2000::/3`, and does **no DNS handling** — keep
  `config set-change-system-dns off`. Never install it with `config create-route-script`
  (hangs, and writes it user-owned). The routing mode lives in the client's encrypted config:
  a one-time `adguardvpn-cli config set-tun-routing-mode script` (CONSTRAINTS.md #37).
- **Teardown:** `steelbore-vpn` (`pkgs/steelbore-vpn/`, Rust) replaces
  `adguardvpn-cli disconnect`, which hangs in TUN mode because the sudo shim blocks SIGTERM
  (CONSTRAINTS.md #36 — never SIGKILL it). `tunnel status` / `tunnel list` are unprivileged;
  `sudo steelbore-vpn tunnel stop --yes` tears down. It shells out to nothing, so it works
  when the session it is diagnosing is already unhealthy.

### 11.6 Multimedia (`modules/packages/multimedia.nix`)

Enabled by `steelbore.packages.multimedia.enable`.

- **Video Players:** mpv, cosmic-player (Rust). VLC is the `org.videolan.VLC` Flatpak (§11.10) under the huge-source-build policy (§11).
- **Audio Players (Rust):** amberol, termusic, ncspot, psst, shortwave
- **Image Viewers (Rust):** oculante (the active `imageViewer` role — §2.6), loupe, emulsion, viu (CLI)
- **Audio Recognition:** mousai (Rust)
- **Audio Mixers / Output Switchers:** wiremix (Rust TUI; Niri `Mod+A`, launched in Alacritty), pavucontrol (GTK GUI; Niri `Mod+Shift+A`) — PipeWire sink/stream routing, since Niri has no audio applet. CLI equivalents `wpctl`/`pactl` ship with the PipeWire stack.
- **Processing:** rav1e (Rust), gifski (Rust), oxipng (Rust), video-trimmer (Rust), ffmpeg, imagemagick (C), exiftool (Perl)
- **Downloaders:** yt-dlp

### 11.6a Games (`modules/packages/games.nix`)

Enabled by `steelbore.packages.games.enable`, with two independently gated heavy extras
(`steam.enable`, `wine.enable`) — all set in `hosts/common.nix`.

- **Doom engine:** gzdoom (C++ — Doom 1/2/Ultimate/Final, Heretic, Hexen), freedoom (data — free BSD-3 IWADs)
- **Quake 1:** ironwail (C — QuakeSpasm fork, the default), vkquake (C — Vulkan fork)
- **Build engine:** raze (C++ — Duke3D, Blood, Shadow Warrior, Redneck Rampage), eduke32 (C — classic Duke3D port; also voidsw, Ion Fury)
- **Wolfenstein 3D:** ecwolf (C++ — also Spear of Destiny and the shareware set via `--data`)
- **DOS:** dosbox-staging (C++)
- **WarCraft II:** wargus (C++ — Stratagus engine), **overridden** to build the engine alone,
  since `pkgs.wargus` fetches a commercial rip (a tier-3 violation; the URL also 403s). Data is
  read at run time from `~/.stratagus/data.Wargus`, imported via `play-warcraft2 --extract`;
  without it the wrapper exits with instructions instead of hanging on a GUI wizard.
- **Steam (`steam.enable`, on):** nixpkgs `programs.steam`, not the parked Flatpak — the module
  supplies Controller/Deck udev rules, the 32-bit graphics stack and Remote Play firewall
  options; its own toggle because it sets `hardware.graphics.enable32Bit` system-wide.
  Firewall openings, protontricks, gamescopeSession and extest stay off deliberately.
- **Wine (`wine.enable`, off):** wineWow64Packages.staging (C), winetricks (shell), lutris
  (Python) — for Blizzard titles with no source port; its own toggle because it is large.
  `wineWow64Packages`, not the deprecated `wineWowPackages` (warns on every eval). Runtime
  only; games self-update inside the Lutris prefix.
- **Commands:** every launcher is `play-`-prefixed (`play-doom`, `play-quake`, `play-quake-vk`,
  `play-duke3d`, `play-duke3d-eduke32`, `play-wolf3d`, `play-warcraft2`, one `play-<slug>` per
  DOS game). The prefix is load-bearing: freedoom's launcher searches PATH for a port named
  `doom`, and `system.path`'s `ignoreCollisions = true` would silently resolve a name clash
  (CONSTRAINTS.md #12); it also makes `play-<TAB>` list everything playable.
- **Why wrappers at all:** no engine defaults to a user-writable data directory (the store is
  read-only and their FHS fallbacks do not exist), so a thin wrapper per engine bakes the path
  in and travels with the binary. Each engine's mechanism (env var, `-basedir`, working
  directory) is documented in `modules/packages/games.nix`.
- **Registry:** `steelbore.packages.games.dosGames` in `hosts/common.nix` — one attrset per
  DOS game generates its `play-<slug>` wrapper (run directly under `dosbox --working-dir`) and
  launcher entry; `games.dataDir` (default `Games`) is the single source of every path.
  Entries: SkyRoads (packaged), Prince of Persia 1 and 2, Hocus Pocus, Rescue Rover 1 and 2,
  Commander Keen 1, Duke Nukem 1 and II (user-supplied).

#### Game data — the three tiers

Game data is deliberately **not** shipped except where the rightsholder granted
redistribution. `package` on a `dosGames` entry is the only difference between tiers, and
the difference is legal, not technical — set it only after reading that game's licence.

| Tier | What | Where it comes from |
|---|---|---|
| **Free content** | Freedoom WADs; SkyRoads | Installed — Freedoom symlinked into `~/Games/doom/`; SkyRoads seeded on first `play-skyroads` |
| **Freely redistributable shareware** | Doom 1, Quake and Duke3D shareware, shareware Apogee / id DOS episodes | Legal to download; **not** downloaded here |
| **Commercial — you must own it** | Full Doom/Quake/Duke3D data, WarCraft II, full editions of the `dosGames` titles | Your own Steam/GOG copy. Nothing in this repo downloads them and nothing should be added that does |

Layout: `~/Games/{doom,quake/id1,duke3d,wolf3d,dos/<dir>}` via `systemd.user.tmpfiles`
(`%h`, no literal user name), plus the launcher-owned `~/.stratagus/data.Wargus`.
`~/.local/share/games/doom` links there too, and the Freedoom symlinks are what stop a fresh
install failing with "Cannot find a game IWAD" (gzdoom's progdir is a different store path).
DOS data is seeded by the wrapper, not a tmpfiles `C` rule, which would keep the store's
read-only mode and stop the game saving.

#### SkyRoads (`pkgs/skyroads/`)

Fetched from the publisher's history page over **HTTP only** — the site refuses TLS there;
integrity comes from the pinned hash, so do not "fix" the scheme. The bundled `readme.txt`
grants redistribution but forbids modification (`unfreeRedistributable`), so all 29 files
are installed unmodified — the condition the grant is attached to. Not in
`update-vendored.nu`: frozen since the 1990s, no release feed (`docs/vendored-binaries.md`).

### 11.7 Productivity (`modules/packages/productivity.nix`)

The nixpkgs side is deliberately small: the large GUI suites moved to Flatpak under the
delivery policy (§11.10 lists the declared app IDs).

- **Knowledge Mgmt:** nb (CLI note-taking & knowledge base). AppFlowy is the Flatpak
  `io.appflowy.AppFlowy`; AFFiNE is not installed (no Flathub listing).
- **Office Suites:** none from nixpkgs — LibreOffice and ONLYOFFICE are Flatpaks (§11.10).
- **Utilities:** Qalculate is the Flatpak `io.github.Qalculate`.
- **Communication:** fractal (Rust, Matrix), newsflash (Rust, RSS), onedriver (Go,
  OneDrive). Tuta mail is the Flatpak `com.tutanota.Tutanota`.

### 11.8 System Utilities (`modules/packages/system.nix`)

This module installs packages only; Podman (`steelbore.services.podman`), AppImage
(`steelbore.compat.appimage`) and Flatpak (`steelbore.packages.flatpak`) are configured in
their own modules.

- **Modern Unix (Rust):** fd, ripgrep, bat, eza, sd, zoxide, procs, dust, dua
- **Coreutils (Rust):** uutils-coreutils, uutils-diffutils, uutils-findutils
- **File Management:** yazi (Rust), broot (Rust), superfile (Go), fclones (Rust),
  kondo (Rust), pipe-rename (Rust), ouch (Rust), spacedrive (Rust — added only while
  nixpkgs does not mark it `meta.broken`, so a broken upstream cannot fail the system build)
- **Disk Management:** gptman (Rust), parted, tparted (TUI), gparted (GUI)
- **System Monitoring:** bottom (Rust), kmon (Rust), macchina (Rust), bandwhich
  (Rust), mission-center (Rust), htop, btop, gotop, fastfetch, i7z, hw-probe
- **Text Processing:** jaq (Rust), jq (C — kept for scripts pinned to its exact semantics),
  teip (Rust), htmlq (Rust), skim (Rust), tealdeer (Rust), mdcat (Rust), difftastic (Rust),
  texinfo (C), pandoc (Haskell), reuse (Python — SPDX/REUSE checker), hunspell
  (+ `hunspellDicts.en_US`)
- **Shells:** nushell (Rust), brush (Rust), ion (Rust), starship (Rust), atuin
  (Rust), carapace (Go — completer for Nushell and Bash via `programs.carapace`),
  pipr (Rust), moor (Rust), powershell
- **Multiplexers:** zellij (Rust), screen
- **Recording:** t-rec (Rust)
- **Containers & Virtualization:** steam-run (FHS environment, `unstablePkgs`), distrobox,
  host-spawn, podman, runc, youki (Rust), oxker (Rust), qemu, flatpak, bubblewrap. BoxBuddy
  is the Flatpak `io.github.dvlv.boxbuddyrs`.
- **System Management:** topgrade (Rust), paru (Rust), doas, os-prober, kbd,
  numlockx, xremap (Rust), input-leap
- **Rebuild orchestrator:** `preflight` (Rust, `pkgs/preflight/`) — system-wide because it
  drives `sudo nixos-rebuild` and mirrors into `/etc/nixos`: machine maintenance, not a user
  tool (§16, `docs/rebuild.md`).
- **Archiving:** p7zip, zip, unzip
- **ZFS:** zfs
- **Benchmarking:** phoronix-test-suite, perf

### 11.9 AI (`modules/packages/ai.nix`)

- **CLI assistants (nixpkgs):** aichat (Rust), gpt-cli, gorilla-cli (Python)
- **Disabled (commented out):** gemini-cli, opencode (Go), codex, github-copilot-cli, llm;
  kilocode-cli is not in nixpkgs. The `task-master` npx wrapper is commented out too
  (CONSTRAINTS.md #3). `mcp-nixos` is disabled because fastmcp's tests hang in the sandbox.
- **Out-of-band:** claude-code, grok-cli, mimocode and qwen-code are installed outside Nix and
  self-update (CONSTRAINTS.md #4); `unstablePkgs.claude-code` stays commented out as the
  re-enable path.
- **Local models:** Ollama runs as a service from `modules/services/ollama.nix` (official
  prebuilt, pinned in `pkgs/ollama/`). Its GUI client Alpaca is a Flatpak (§11.10) pointed at
  that service, never its bundled one (CONSTRAINTS.md #18).

**MCP servers and agent tooling:** MCP hosts are configured from `mcp.toml` in the
`mcp-servers` input, deployed by `mcpctl`; servers are named by **bare name on PATH**, so
each must be Nix-provided (CONSTRAINTS.md #23).

| Tool | Source | Installed by | Notes |
|------|--------|--------------|-------|
| `bravais-mcp` | in-tree crate `bravais-mcp/`, packaged at `pkgs/bravais-mcp/` | `ai.nix` (system) | First-party Rust MCP server; main program `bravais-cli`. GPL-3.0-or-later. |
| `crates-mcp` | third-party crate, `pkgs/crates-mcp/` (version + hash pinned) | `home.nix` (user) | crates.io / docs.rs lookups; `cargoHash` must be regenerated on every bump. |
| `engram` | `engram` flake input (first-party) | `home.nix` (user) | Shared chat memory; needs an explicit `--db` (CONSTRAINTS.md #23). User-scoped because its state lives in `$HOME`. |
| `pathfinder-jq` | `pathfinder` flake input (first-party) | `home.nix` (user) | Provides `jq` for mj. Deliberately shadows the system reference jq (per-user profile precedes the system one on `PATH`); root and full-path callers keep jq 1.8.2. |
| `mcpctl` | `mcp-servers` flake input (first-party) | `home.nix` (user) | Renders and deploys each MCP host's config; user-scoped because it writes into `$HOME`. |
| `vacuum` | `vacuum` flake input (first-party) | `home.nix` (user) | Disk-space recovery CLI + TUI; config HM-managed (`users/mj/apps.nix`); its own NixOS module deliberately unused. |
| `obscura` | built from source, `pkgs/obscura/` | `ai.nix` (system) | Also an MCP server (`obscura mcp`); see below. |

The three first-party inputs are `github:` URLs, so a change to any of them must be
committed **and pushed** before `nix flake update <input>` sees it (§3.1).

**Headless browser:** `obscura` — headless browser for AI agents and scraping (Rust, Apache-2.0): real V8
  JavaScript, serves CDP and MCP, no Chromium or Node. Installs `obscura` and
  `obscura-worker` (spawned by `scrape`), built with `render` + `stealth`. Source-built
  because the nixpkgs release predates the render crate (CONSTRAINTS.md #24); system-wide
  because its MCP server resolves by bare name (#23). Bump with
  `nu pkgs/update-vendored.nu obscura`.

**GUI (vendored `.deb` repackages — pins live in each `pkgs/<name>/package.nix`; all but
`grok-bot` bump via `nu pkgs/update-vendored.nu <name>`, see `docs/vendored-binaries.md`):**

- `claude-desktop` — official Anthropic Linux beta (autoPatchelf + Wayland/MCP wrapper;
  unfree; not in nixpkgs); the Linux app does not self-update.
- `github-copilot-app` — official GitHub Tauri app (unfree); must keep `dontStrip = true`
  (CONSTRAINTS.md #40).
- `opencode-desktop` — official OpenCode app (MIT); deletes the musl binaries
  (CONSTRAINTS.md #15) and puts native EGL on `LD_LIBRARY_PATH` for Chromium's ANGLE.
- `goose-desktop` — Block's AI agent app (Apache-2.0; no Flathub listing); same ANGLE/EGL
  fix; the updater queries upstream's new `aaif-goose/goose` org.
- `codex-desktop` — OpenAI's Codex app (unfree); unversioned `latest` URL, ETag-keyed
  updater (§11.1b).
- `grok-bot` — Grok Bot desktop agent (unfree), published by Cursor/Anysphere despite the
  name; not in nixpkgs. Its `grokbot` and `sand` URL schemes are declared as
  `selfRegisteredSchemes` in `users/mj/default-apps.nix`. Bumped by hand — no release feed,
  opaque URL (`docs/vendored-binaries.md`).

### 11.10 Flatpak (`modules/packages/flatpak.nix`)

Managed declaratively through nix-flatpak (`services.flatpak.packages`).

- **Delivery policy:** as in §11. Never both: nixpkgs Emacs, Vim, Yakuake, Zed and Bitwarden
  replaced their Flatpak copies; VSCodium (separate state) and Ptyxis (host install keeps
  distrobox integration) are the two deliberate exceptions.
- **Remotes:** flathub (`https://dl.flathub.org/repo/flathub.flatpakrepo`) and
  cosmic (`https://apt.pop-os.org/cosmic/cosmic.flatpakrepo`, System76's origin
  for the COSMIC applets — declared as the `.flatpakrepo` so the GPG key travels
  with it).
- **Updates:** `services.flatpak.update.auto` weekly, deliberately not `onActivation` —
  entries pin only an app ID, so tying updates to activation would add an unbounded download
  to every switch. `preflight` also starts a detached update after a successful switch
  (`docs/rebuild.md`).
- **Install resilience:** `flatpak-managed-install` gets an unlimited start timeout and a
  generous restart budget, because multi-GB runtime pulls routinely trip libostree's curl
  timeouts and systemd's default start limit would give up after one retry.
- **Keyring override:** the Chromium-based Flatpaks (Chrome, Edge, Opera, Brave, Discord,
  Wavebox, VS Code, VSCodium, GitHub Desktop) get `XDG_CURRENT_DESKTOP=GNOME` inside the
  sandbox only, so Chromium uses the Secret Service instead of plaintext under niri/LeftWM.

> VS Code and VSCodium share one declarative user-level override (HM `xdg.dataFile` in
> `users/mj/apps.nix`) that keeps `/app/bin:/usr/bin` first on PATH so each entrypoint
> resolves inside the sandbox.

**Packages (36 declared; parked entries are commented out and not installed):**

| Category            | App IDs                                              |
|---------------------|------------------------------------------------------|
| COSMIC applets      | io.github.cosmic_utils.cosmic-ext-applet-clipboard-manager, io.github.cosmic_utils.minimon-applet (`cosmic` remote; system-wide to avoid a second, per-user installation that made unqualified `flatpak` commands ambiguous) |
| Browsers            | com.google.Chrome, com.microsoft.Edge, com.opera.Opera, com.brave.Browser (Zen and LibreWolf parked; Firefox is nixpkgs) |
| Communication       | com.discordapp.Discord, im.riot.Riot (Element), io.wavebox.Wavebox |
| Phone connectivity  | io.github.nwxnw.cosmic-ext-connected (front-end for the host KDE Connect daemon), io.github.hepp3n.kdeconnect (a second daemon overlapping `kdePackages.kdeconnect-kde` — if they fight, drop this, never the host daemon). Both `cosmic` remote; neither pairs until 1714-1764/tcp+udp are opened, which nothing here does yet |
| Networking / Internet | de.haeckerfelix.Fragments (Rust BitTorrent client) |
| Security & Remote   | com.rustdesk.RustDesk (com.bitwarden.desktop DISABLED — nixpkgs, §11.4) |
| Development         | com.jetbrains.RustRover, com.visualstudio.code, com.vscodium.codium (also nixpkgs — §11.2), io.github.shiftey.Desktop (GitHub Desktop). dev.zed.Zed DISABLED — nixpkgs `zed-editor` |
| System & Utilities  | com.daidouji.oneko, com.github.tchx84.Flatseal, io.github.dvlv.boxbuddyrs, io.github.prateekmedia.appimagepool, it.mijorus.gearlever, org.adishatz.Screenshot, org.flameshot.Flameshot, org.gnome.baobab |
| Multimedia          | org.gimp.GIMP, org.videolan.VLC                      |
| Office              | org.libreoffice.LibreOffice, org.onlyoffice.desktopeditors |
| Knowledge & Communication | io.appflowy.AppFlowy, com.tutanota.Tutanota (AFFiNE not on Flathub) |
| Terminals           | app.devsuite.Ptyxis (alongside the nixpkgs host install, §10.1; themed via shared host dconf) |
| Productivity        | io.github.Qalculate (org.kde.yakuake removed — nixpkgs `kdePackages.yakuake`) |
| AI                  | com.jeffser.Alpaca (GTK4 Ollama client — CONSTRAINTS.md #18) |
| Gaming              | **io.github.lavenderdotpet.LibreQuake** and **io.github.jotd666.gods-deluxe** active — in neither channel, so Flatpak is the fallback, not a preference. Parked: com.heroicgameslauncher.hgl, com.usebottles.bottles, com.valvesoftware.Steam (never alongside `programs.steam`), info.beyondallreason.bar, net.openra.OpenRA, net.wz2100.wz2100, org.libretro.RetroArch, org.openttd.OpenTTD |
| Retro / Classic     | All parked: com.dosbox.DOSBox, com.dosbox_x.DOSBox-X, com.play0ad.zeroad, com.remnantsoftheprecursors.ROTP, eu.jumplink.Learn6502, io.github.dosbox-staging, io.github.dman95.SASM, org.seul.crimson, org.zdoom.UZDoom, rs.ruffle.Ruffle — DOSBox and ZDoom ports ship from nixpkgs (§11.6a) |

`services.flatpak.uninstallUnmanaged` is not set, so removing an entry does not
uninstall the app — run `flatpak uninstall <app-id>` by hand.

### 11.11 Homebrew (`modules/packages/homebrew.nix`)

Linuxbrew as a **4th-priority escape hatch** (per the spacecraft-missing-pkg order Guix →
Nix → Cargo → **Homebrew** → Flatpak → Snap) for software with no Nix/Guix/Cargo packaging.
Brew expects an FHS layout, a system compiler and a `/home/linuxbrew` prefix that NixOS
lacks, so it runs inside a **distrobox container** (`brew`, Ubuntu toolbox image) where it
behaves as upstream intends.

**Dependency:** distrobox drives the host's rootless podman (`steelbore.services.podman`);
`hosts/common.nix` enables both, noted so the coupling is explicit.

**Commands installed** (`pkgs.writeShellApplication`, shellcheck-linted at build time):

| Command         | Purpose                                                                          |
|-----------------|----------------------------------------------------------------------------------|
| `brew-box-init` | One-time setup: create the container, install brew's deps, run the Homebrew installer. Idempotent. |
| `brew`          | Run `brew <args>` from the normal shell, proxied into the box. Errors with a hint if `brew-box-init` hasn't run. |
| `brew-box`      | Interactive shell inside the container. |

`brew-box-init` is separate so the first `brew` is not a surprise multi-minute image pull.

**Why distrobox over an FHS sandbox:** with `buildFHSEnv`, binaries installed *by* brew link
against the sandbox and only run inside it; the container removes that sharp edge. The image
is swappable in the module's `image` binding.

---

## 12. Virtualization & Containers

Opt-in system services live under `modules/services/` (`steelbore.services.*`) and
non-Nix escape hatches under `modules/compat/` (`steelbore.compat.*`). Shared toggles
are set in `hosts/common.nix`; the ThinkPad-only ones in `hosts/thinkpad/default.nix`.

| Toggle | Module | Enabled in |
|--------|--------|------------|
| `steelbore.services.podman.enable` | `modules/services/podman.nix` | `hosts/common.nix` |
| `steelbore.services.ollama.enable` | `modules/services/ollama.nix` | `hosts/common.nix` |
| `steelbore.services.adguardvpn.{enable,routeScript.enable}` | `modules/services/adguardvpn.nix` | `hosts/common.nix` |
| `steelbore.compat.appimage.enable` | `modules/compat/appimage.nix` | `hosts/common.nix` |
| `steelbore.services.chromeRemoteDesktop.{enable,user}` | `modules/services/chrome-remote-desktop.nix` | `hosts/thinkpad/default.nix` |
| `steelbore.services.waydroid.enable` | `modules/services/waydroid.nix` | `hosts/thinkpad/default.nix` |

The AdGuard VPN client is documented with networking (§11.5, AdGuard VPN).

### 12.1 Podman

```nix
virtualisation.podman = {
  enable = true;
  dockerCompat = true;       # docker -> podman drop-in alias
  extraPackages = [ pkgs.youki pkgs.runc ];
};
```

`youki` (Rust) ships alongside `runc`; the user `containers.conf` (§12.5) currently
selects `runc`.

### 12.2 Chrome Remote Desktop

`user` defaults to `primaryUser`. Not in nixpkgs — `pkgs/chrome-remote-desktop/`
repackages Google's official `.deb` with `autoPatchelfHook`, and every external
command its Python management script runs is substituted with a Nix-store /
`/run/wrappers` path, because the systemd unit has no `path` and a bare name resolves
to nothing. The headless X server's `dummy`/`void` drivers are unioned into the
package (CONSTRAINTS.md #38).

The module adds a `chrome-remote-desktop` group, a `pam_unix` PAM stack and a
`chrome-remote-desktop@<user>` system service. CRD runs a **headless virtual X11**
session and execs `~/.chrome-remote-desktop-session` (from `users/mj/apps.nix`),
which launches LeftWM directly under `dbus-run-session` — not via the startx
launcher, which would start a second physical Xorg; Niri/GNOME here are Wayland,
which CRD cannot drive. One-time authorization is manual
(`remotedesktop.google.com/headless` → `start-host --code=…` → PIN). Outbound HTTPS
only (no inbound firewall port). It is a vendored binary: bump it with
`update-vendored.nu` (docs/vendored-binaries.md; 404s: CONSTRAINTS.md #14).

### 12.3 Flatpak

`services.flatpak.enable = true`, set by `modules/packages/flatpak.nix` under
`steelbore.packages.flatpak.enable`; the declared app list is in §11.10.

### 12.4 AppImage

First-class support: `binfmt` auto-run for any `*.AppImage`, plus the AppImagePool
GUI (Flatpak, alongside Gear Lever). Loose AppImages live in `~/Applications/` by
convention. When an AppImage is used regularly, prefer packaging it as a Nix
derivation with `appimageTools.wrapType2` (see BrowserOS in §11.1) over a loose
binary. Implemented as `programs.appimage = { enable = true; binfmt = true; }`.

### 12.5 Container User Config

Home Manager (`users/mj/apps.nix`) writes `~/.config/containers/containers.conf`
with `[engine] runtime = "runc"`.

### 12.6 Ollama

nixpkgs' ollama lags upstream badly on stable, and current models 412-reject it, so
`pkgs/ollama/` repackages Ollama's **official prebuilt** binary (version pinned in
`pkgs/ollama/package.nix` only) with the CUDA and Vulkan runners **stripped** — the
ThinkPad has no NVIDIA GPU, so only CPU runners remain and no `acceleration` setting
is needed. It runs via the stock `services.ollama` module (daemon on
`127.0.0.1:11434`), which Alpaca is pointed at (CONSTRAINTS.md #18). It does not
self-update; bump it with `update-vendored.nu` (docs/vendored-binaries.md).

### 12.7 Waydroid (`modules/services/waydroid.nix`)

`virtualisation.waydroid.enable` — a full Android userspace in an LXC container
against the host kernel, for running and testing Android apps without a physical
handset. Filed under `services.*` because it is a long-running containerised service,
like Podman and Ollama. Complements `steelbore.hardware.android` (§6.0), the
*device* half; neither needs the other.

No extra kernel work is required: the XanMod kernel already builds in the binder IPC
and binderfs options, the usual Waydroid blocker on NixOS.

**Wayland only.** Works under Niri, GNOME, COSMIC and Plasma's Wayland session;
**not** under LeftWM (startx/X11), for which Waydroid has no backend.

The Android system image is a deliberate one-time imperative step — a
multi-hundred-MB download no NixOS option fetches (`sudo waydroid init`, then
`waydroid session start`). `adb` reaches the container once a session runs, which is
what makes `gradle installDebug` and Android Studio work against it.

---

## 13. User Configuration (Home Manager)

Home Manager runs as a NixOS module for the single user named by `primaryUser`
(`mj`), with `useGlobalPkgs`, `useUserPackages` and `backupFileExtension = "backup"`.
The system-side account (`users/mj/default.nix`) sets `mjsh` as the login shell and
the groups `networkmanager`, `wheel`, `input`, `video`, `audio`, `seat` and `uinput`.

### 13.1 Basic Settings (`users/mj/home.nix`)

`home.nix` holds identity, the Construct skill hub, user packages and imports; every
other concern lives in its own module:

`git.nix` (identity, signing, GPG agent), `shell.nix` (bash, Nushell, Ion,
Starship, session variables, PATH), `terminals.nix` (terminal configs + dconf),
`eww.nix` (Niri eww bar), `niri.nix` (compositor, bars, OSD/idle), `desktop-theme.nix`
(GTK/Qt, cursor, desktop dconf), `editor-themes.nix`, `plasma.nix` (date/time,
colour scheme), `apps.nix` (Zellij, IRC, Flatpak overrides, CRD session,
`containers.conf`) and `default-apps.nix` (the sole `xdg.mimeApps` block).

- **Username / home:** `primaryUser` (`mj`, never a literal in modules), `/home/${primaryUser}`; **state version** 26.05
- **Symlink:** `~/steelbore` -> `/spacecraft-software` (out-of-store symlink)
- **Skills:** `spacecraft.construct` with `mutablePointer` and `perSkillLinks`; see AGENTS.md (First-time bootstrap), `docs/skill-pointer.md` and CONSTRAINTS.md #41

### 13.2 Keyboard Layout

```nix
home.keyboard = {
  layout = "us,ara";
  options = [ "grp:ctrl_space_toggle" ];
};
```

### 13.3 Session Variables

Set in `users/mj/shell.nix`. `EDITOR`/`VISUAL`/`BROWSER` come from the handler-role
registry (`steelboreApps`), so `$BROWSER` and `mimeapps.list` cannot disagree.
`NIXPKGS_ALLOW_UNFREE = 1`. `ENGRAM_DB` is the interactive safety net for Engram's
relative-path `--db` default (CONSTRAINTS.md #23). The `*_DISABLE_*_SKILLS` switches
(and `GROK_CLAUDE_SKILLS_ENABLED = false`) turn off the Claude/Codex/OpenCode compatibility
scans of agents that already read `~/.agents/skills`, so each skill is listed once and
claude.ai's `synced/` copies are not scanned.

`SPACECRAFT_THEME` is **not** set here. It is a system-wide session variable
carrying the active theme **slug** (Standard §11.6.3 source 2), exported by
`modules/theme/declaration.nix` alongside `/etc/steelbore/theme.toml`. The old
`STEELBORE_THEME = "true"` boolean is retired; nothing read it, and Standard
§11.6.4 reserves that name against slug semantics.

**PATH:** `home.sessionPath` is deliberately unused — it prepends, letting
user-local bins shadow Nix-store ones. Out-of-band bin dirs are single-sourced in
`outOfBandDirs` (`shell.nix`) and **appended** in all three managed shells; see
AGENTS.md (Key conventions).

### 13.4 User Packages

`home.packages` in `users/mj/home.nix`:

- **Rust toolchain** (`unstablePkgs`): `rustup` + cargo subcommands and `sccache`;
  components come from `rustup`, never installed beside it (CONSTRAINTS.md #12).
- **Flake-input tools** (via `extraSpecialArgs`, CONSTRAINTS.md #7): `construct`,
  `mcpctl`, `vacuum`, `engram` (must stay Nix-provided; CONSTRAINTS.md #23).
- **In-tree:** `crates-mcp`, and `cargo-capped` (cargo in a memory-capped
  `systemd-run --user --scope`, so a runaway build is OOM-killed in its own cgroup).

`shell.nix` adds the `rebuild` binary (§16) and `steelbore-su-guard`;
`sequoia-chameleon-gnupg` is Git's `gpg.program` by store path (§13.5).

### 13.5 Git Configuration (`users/mj/git.nix`)

```nix
programs.git = {
  enable = true;
  lfs.enable = true;
  settings = {
    user.name = "UnbreakableMJ";
    user.email = "Mohamed.Hammad@SpacecraftSoftware.org";
    user.signingkey = "~/.ssh/id_ed25519.pub";
    gpg.program = "${pkgs.sequoia-chameleon-gnupg}/bin/gpg-sq";
    gpg.format = "ssh";
    gpg.ssh.program = "<gitway>/bin/gitway-keygen";
    commit.gpgsign = true;
    init.defaultBranch = "main";
  };
};
```

Commits are SSH-signed through `gitway-keygen`, with keys held by `gitway-agent`,
which owns `$SSH_AUTH_SOCK` (CONSTRAINTS.md #8); every managed shell re-points it at
the gitway-agent socket because `pam_gnome_keyring` otherwise pins it to its own.
`gh auth git-credential` serves GitHub credentials; `services.gpg-agent` uses `pinentry-qt`.

### 13.6 Starship Prompt (Steelbore powerline preset)

`programs.starship` (`shell.nix`). For a registered palette the settings
are the Theme repository's generated file for the active slug (`themeAssets.starship`),
so the prompt tracks that repository's rendering exactly. A **local** theme has no
such file, so the same powerline preset is kept inline as a fallback, its palette
resolved from Standard §11.1 role tokens (`steelborePalette`) — never hardcoded.

### 13.7 Nushell Configuration

`programs.nushell` in `users/mj/shell.nix`: `show_banner: false`, LS colours and
clickable links, block cursor shapes. `color_config` is the Theme repository's
module for the active slug (`themeAssets.nushell`), falling back to role tokens for a
local theme. Inside interactive Nushell, `$env.SHELL` is set to bash (for tools such as
Claude Code's Bash tool that spawn `$SHELL`); the login `$SHELL` seen by DE-launched
terminals stays Nushell. `PROMPT_MULTILINE_INDICATOR` is plain ASCII because
systemd's `import-environment` rejects control characters.

**Steelbore Telemetry Aliases:**

`ll` = `ls -l`, `lla` = `ls -la`, `telemetry` = `macchina`, `sensors` =
`^watch -n 1 sensors`, `sys-logs` = `journalctl -p 3 -xb`, `network-diag` =
`gping google.com`, `top-processes` = `bottom`, `disk-telemetry` = `yazi`,
`edit` = the `termEditor` role.

**Commands defined in `config.nu`:**

- `steelbore` — prints the Steelbore OS identity banner (STATUS: ACTIVE, LOAD: NOMINAL, INTEGRITY: VERIFIED).
- `rebuild` — read verbatim from `users/mj/rebuild.nu`, the same text as the `rebuild` binary, so the two cannot drift (§16).
- `skills-sync`, `skills-status`, `skills-reset`, `skills-ship` — wrappers over `construct skill …` (AGENTS.md, First-time bootstrap).
- `theme` — list / show / set / try / now over `theme-registry`; `theme now` writes the Standard §11.6.4 per-user declaration, picked up with no rebuild.
- `app` — list / show / candidates / set handler roles (`default-apps` skill).
- `su` — routes through `steelbore-su-guard` (CONSTRAINTS.md #34).

### 13.8 Ion Shell Init (`~/.config/ion/initrc`)

- `su` alias to `steelbore-su-guard` (Ion's `fn` rejects a variadic wrapper)
- `SSH_AUTH_SOCK` → gitway-agent socket; `outOfBandDirs` appended to PATH; Starship via `eval $(starship init ion)`
- Same aliases as Nushell except `network-diag`

### 13.9 Alacritty (Home Manager)

`programs.alacritty` in `users/mj/terminals.nix`: Nushell shell, JetBrainsMono Nerd
Font, colours from `lib/terminal-theme.nix` (role tokens). The same file writes
Nushell-shelled user configs for cosmic-term (`force = true`, since cosmic-term's own
`profiles` file would shadow the system default), WezTerm, Rio, Ghostty, Foot,
xfce4-terminal, Konsole/Yakuake and XTerm.

### 13.10 dconf Settings

- **Ptyxis:** default profile `steelbore`, JetBrainsMono Nerd Font 12, 16-colour
  palette and background/foreground from role tokens (`lib/terminal-theme.nix`),
  opacity 0.95.
- **GNOME Console:** night theme (kgx has only fixed themes), JetBrainsMono Nerd Font 12.
- **Desktop interface** (`desktop-theme.nix`): dark/light colour scheme, GTK and
  Papirus icon theme chosen by whether the active palette is light; Bibata cursor;
  UI font Hack Nerd Font, monospace JetBrainsMono Nerd Font. These keys are the
  appearance source for Niri and LeftWM.
- **GNOME workspace keys:** `Super+Ctrl+Left/Right` is added *alongside* the stock
  accelerators so the mouse side-button remap works under GNOME.

---

## 14. Keyboard Layout

- **Primary:** US English (`us`)
- **Secondary:** Arabic (`ara`)
- **Toggle:**
  - X11 sessions (LeftWM) and desktops that honour the system XKB options: `Ctrl+Space` (`grp:ctrl_space_toggle`).
  - Niri: `Mod+Space` (`switch-layout "next"`). Niri grabs keys for its own binds before xkbcommon's group-toggle action fires, so `grp:ctrl_space_toggle` is a no-op there; the option is kept in Niri's `xkb` block only for X11 parity.
- **Console:** the TTY stays on `us` (`console.keyMap = "us"`) — `ckbcomp` cannot resolve a multi-layout XKB config.
- **Configuration:** `layout = "us,ara"` with `grp:ctrl_space_toggle` is stated in three places, which must agree:
  - `hosts/common.nix` — system XKB (`services.xserver.xkb`)
  - `users/mj/home.nix` — user XKB (`home.keyboard`)
  - `users/mj/niri.nix` — Niri's own `input { keyboard { xkb { … } } }` block and the `Mod+Space` bind
- **Layout indicator:** `steelbore-layout-state` (`modules/desktops/shared.nix`) backs the eww language indicator on both bars. On Niri it reads `niri msg --json keyboard-layouts`; on X11 it uses `xkb-switch -p`, because the active group lives in the X server and `setxkbmap -query` only echoes the static config.

---

## 15. Desktop Environment Summary

All five sessions are enabled together in `hosts/common.nix` (`steelbore.desktops.*`) and are entered through greetd + tuigreet (`modules/login/default.nix`); the GNOME, COSMIC and Plasma modules disable their own display managers.

| Desktop | Protocol | Bar                          | Launcher                                | Notification         | Lock                              |
|---------|----------|------------------------------|-----------------------------------------|----------------------|-----------------------------------|
| GNOME   | Wayland  | GNOME Shell (+ `open-bar` ext.) | GNOME Shell (+ `launcher` ext.)      | GNOME Shell          | upstream (GNOME Shell)            |
| COSMIC  | Wayland  | COSMIC Panel                 | cosmic-launcher                         | cosmic-notifications | upstream (COSMIC)                 |
| Plasma 6| Wayland  | Plasma Panel                 | KRunner                                 | KDE Notifications    | upstream (Plasma)                 |
| Niri    | Wayland  | eww                          | anyrun (`Mod+D`)                        | dunst                | gtklock + swayidle                |
| LeftWM  | X11      | eww (separate `eww-leftwm` config) | rlaunch (`Mod+D`), rofi (`Mod+Shift+D`) | dunst            | i3lock via xss-lock (`Ctrl+Alt+L`, idle, sleep) |

Notes:

- **Niri and LeftWM share a stack where it is cross-platform** — eww and dunst — and use Wayland-only tools (anyrun, gtklock, swayidle, swayosd, xwayland-satellite) where the X11 alternatives do not apply (`modules/desktops/niri.nix`). Niri starts the bar and notifier from `spawn-at-startup` in `users/mj/niri.nix` (`eww open bar`, `dunst`); LeftWM starts picom, dunst, the eww daemon and the bar (from `~/.config/eww-leftwm`) in its theme's `up` script (`modules/desktops/leftwm.nix`), which runs once LeftWM is managing the display. The session wrapper that launches LeftWM is `leftwm-session-inner` in `modules/login/default.nix`.
- **Two eww configs, kept in step:** Niri's lives in `users/mj/eww.nix` (`~/.config/eww`), LeftWM's under `~/.config/eww-leftwm` in `modules/desktops/leftwm.nix` so the two never collide. Both draw their hardware indicators from `steelbore-beacon` (CONSTRAINTS.md #25) and obey the `eww.scss` comment rule (CONSTRAINTS.md #26).
- **Alacritty is the default terminal** (`Mod+Return`) under both Niri and LeftWM; LeftWM requires it because rio renders blank under startx-spawned Xorg (rationale in `modules/desktops/leftwm.nix`).
- COSMIC, Plasma and GNOME keep their upstream shell components (panel, launcher, notifications, lock). Bravais adds explicit per-DE portal routing plus a package set per module: GNOME's extension set (incl. forge tiling) in `modules/desktops/gnome.nix`, and Plasma's krohnkite tiling, KWallet tools and ksshaskpass in `modules/desktops/plasma.nix`.

---

## 16. Operations & Tooling

This section names the day-to-day operational surfaces and points at their long
form. It deliberately does not copy them: `AGENTS.md`, `docs/*.md` and
`CONSTRAINTS.md` are the sources of truth, and a second copy here would drift.

### 16.1 Rebuild

**`preflight` (Rust, `pkgs/preflight/`) is the supported entry point**, run as the
user, never as root. In order: bump the five tracked inputs (authenticated with
the `gh` token, never stored), garbage-collect keeping a week of generations,
vacuum the journal, `nixos-rebuild switch --flake .#bravais-thinkpad`, and — only
after a successful switch — mirror the tree into `/etc/nixos` and start the
Flatpak update **detached**, because a full Flatpak refresh can take hours and
must never block the switch. `preflight` wraps none of the tools it drives onto
PATH, so they are never frozen in its closure (same reasoning as
CONSTRAINTS.md #23).

The older `users/mj/rebuild.nu` and `scripts/rebuild.sh` sit behind a deprecation
prompt; **change one and change all three.** Flags: `preflight --help`; the rest:
**`docs/rebuild.md`**.

### 16.2 Skills Delivery

Agent skills come from the `construct` flake input (`spacecraft.construct` in
`users/mj/home.nix`). `~/.agents/skills` is a real directory of per-skill links
through a `current` pointer aimed at `pinned` (tracks `flake.lock`) or `built`
(ahead of it) — never a bare store path, which has no GC root — and every
activation re-points it at `pinned`, so the lock stays authoritative. An agent's
skills directory is never a directory symlink into the hub (CONSTRAINTS.md #41).
`skills-sync` moves `flake.lock`: follow it with `nu pkgs/sync-skills.nu` and
commit both, or the **Skills Drift** workflow fails. Commands, link layout and
invariants: **`docs/skill-pointer.md`**.

### 16.3 Theme and Application Registries

**Theme.** The active theme is one word in `theme.nix`; local themes live in
`themes/<slug>.nix`. `lib/palette.nix` resolves the slug to Standard §11.1 role
tokens read from `steelbore.toml` in `construct` (see §2.2, §3.2). The Nushell
`theme` command (`list`, `show`, `set`, `try`, `now`) reads the `theme-registry`
flake output; `theme try` switches live without editing `theme.nix`, and
`theme now` writes the Standard §11.6.4 per-user declaration with no rebuild.

`themeSystems` is deliberately **not** part of `nixosConfigurations`: `nix flake
check` force-evaluates every entry there, and holding a full system per theme in
one evaluator was OOM-killed; as a non-standard output they stay lazy. Rendering
has two paths on purpose — role tokens for terminals, bars, WMs, the TTY and
greetd (which also serves local themes), and `lib/theme-assets.nix` for the Theme
repository's generated editor, GTK, KDE, Starship and Nushell files, falling back
to tokens or the toolkit default for a local theme.

**Default applications.** One word per role in `default-apps.nix`; roles and
catalog in `lib/default-apps.nix`; drop-ins in `apps/<slug>.nix`;
`users/mj/default-apps.nix` is the only `xdg.mimeApps` consumer. The role owns the
MIME list, never the app (CONSTRAINTS.md #22). See §2.6 and the `default-apps`
skill.

### 16.4 Vendored Upstream Binaries

Ten packages pin an upstream `version` + `hash` that `nix flake update` cannot
move. They are bumped only by `pkgs/update-vendored.nu` (or
`preflight --update-vendored`), **never by hand**, and a pinned version is **never
restated in prose** — point at the package file. The `codex-desktop`, `grok-bot`
and `skyroads` exceptions are in **`docs/vendored-binaries.md`**; failure
isolation and the `obscura` bumper are in the `vendored-binaries` skill.

### 16.5 Agent Tooling

| Component | Source | Installed via |
|-----------|--------|---------------|
| `bravais-mcp` (library, MCP server, `bravais-cli`) | In-tree `bravais-mcp/`, `pkgs/bravais-mcp/` | `modules/packages/ai.nix` |
| `crates-mcp` — crates.io / docs.rs MCP server | `pkgs/crates-mcp/` | `home.packages` |
| `mcpctl` — deploys MCP host configs from `mcp.toml` | `mcp-servers` input | `home.packages` (writes into `$HOME`) |
| `vacuum` — disk-space recovery | `vacuum` input | `home.packages` |
| `engram` — shared chat memory | `engram` input | `home.packages`; `ENGRAM_DB` in `users/mj/shell.nix` |
| `pathfinder` — `jq` for mj (shim over jaq) | `pathfinder` input | `home.packages` (`pathfinder-jq`) |

MCP hosts resolve servers **by bare name on PATH**, so they stay Nix-provided, and
Engram needs an explicit `--db` (CONSTRAINTS.md #23). First-party inputs are
`github:` URLs: commit **and push** before `nix flake update <input>` sees a
change. `preflight` deploys MCP config only with `--mcp-deploy`.

### 16.6 Documentation Map

`AGENTS.md` is the agent single source of truth (Standard §5.7; `CLAUDE.md`
imports it); `CONSTRAINTS.md` and `docs/*.md` are its long form; `TODO.md`,
`CHANGELOG.md`, `Packages.md` and this PRD track change; `.claude/skills/` holds
the project procedures; `README.md`, `CONTRIBUTING.md` and `NOTICE.md` face users.

### 16.7 Contribution & Security Policy

- **Contributions** (long form: `AGENTS.md`, `CONTRIBUTING.md`): hobby project,
  PRs at the maintainer's discretion; issue first for non-trivial changes; pre-PR
  gate per §17.1; Conventional Commits, **signed and Verified** with an Ed25519
  SSH key (Standard §6.3) — DCO sign-off does not satisfy this.
- **Security reports:** never a public issue — email
  `Mohamed.Hammad@SpacecraftSoftware.org`; 90-day coordinated-disclosure window.

---

## 17. Verification Plan

### 17.1 Build Verification

```bash
# Validate: real stable build + unstable eval + the cheap checks
# (bare `nix flake check` builds both channels' closures, >10 min — CONSTRAINTS.md #17)
nix build --no-link '.#nixosConfigurations.bravais-thinkpad.config.system.build.toplevel'
nix eval --raw '.#nixosConfigurations.bravais-thinkpad-unstable.config.system.build.toplevel.drvPath'
nix build --no-link '.#checks.x86_64-linux.reuse-lint' '.#checks.x86_64-linux.niri-config'  # SPDX + niri KDL; seconds

nix build .#<name>                                              # one in-tree package (after `git add -A`)
nix flake show                                                  # list outputs
nixos-rebuild dry-build --flake .#bravais-thinkpad
nixos-rebuild dry-build --flake .#bravais-thinkpad-unstable --show-trace   # the pre-PR check

# Switch — manual path
sudo nixos-rebuild switch --flake .#bravais-thinkpad            # stable ThinkPad (v3)
sudo nixos-rebuild switch --flake .#bravais-thinkpad-unstable   # nixos-unstable channel
sudo nixos-rebuild switch --flake .#bravais                     # alias → stable ThinkPad
```

**Supported switch path:** `preflight` (Rust, `pkgs/preflight/`), run as the user and never as root, bumps the tracked inputs, collects garbage, vacuums the journal and switches, mirroring the tree into `/etc/nixos` and starting the detached Flatpak update only after a successful switch (`preflight --dry` exercises it without switching). The sequence and its two deprecated ports are in §16.1; every flag is in `preflight --help` and `docs/rebuild.md`.

After any switch, check `systemctl status home-manager-mj.service` — a failed Home Manager activation strands every HM change while `nixos-rebuild` still reports success (CONSTRAINTS.md #30).

### 17.2 Desktop Session Verification

A `--version` call proves only that a binary is on PATH, not that a session starts, so verification is split three ways.

**(a) Automated — evaluation and build time** (no seat needed; §17.1 runs them):

- `.#checks.x86_64-linux.niri-config` runs `niri validate` over the rendered `config.kdl`. The file is a generated string Nix cannot type-check, so a KDL or action-name error fails here instead of at session start.
- `modules/desktops/assertions.nix` fails evaluation on a broken composition: LeftWM without `services.xserver`; Niri or COSMIC without greetd; GNOME or Plasma with neither greetd nor its native display manager (gdm / sddm). Enabling several desktops at once is intended and is not asserted against.
- The `cosmicUnmax` / `niriUnmax` modules assert that their desktop is enabled.
- `.#checks.x86_64-linux.reuse-lint` is the SPDX gate (§17.3). `checks` also holds both machine toplevels, which is why a bare `nix flake check` is too slow to gate on.

**(b) Post-login — run inside the session** (a text check, but it needs a real login):

| Desktop | Check | Expected |
|---------|-------|----------|
| All | `loginctl show-session "$XDG_SESSION_ID" -p Type` | `Type=wayland`; `Type=x11` under LeftWM |
| All | `systemctl --user is-active steelbore-audio-led` | `active` (wanted by `default.target`, so it runs in every session) |
| All | `systemctl is-active home-manager-mj.service` | `active` — a system unit, not `--user` (CONSTRAINTS.md #30) |
| Niri | `systemctl --user is-active graphical-session.target steelbore-niri-unmax` | `active` twice |
| Niri | `pgrep -x eww`; `pgrep -x dunst` | a PID each (both `spawn-at-startup`) |
| Niri | `systemctl --user is-active steelbore-mouse-workspace-nav` | `inactive` — niri binds the side buttons natively (CONSTRAINTS.md #29) |
| COSMIC | `systemctl --user is-active cosmic-session.target steelbore-cosmic-unmax` | `active` twice |
| GNOME | `systemctl --user is-active gnome-session-initialized.target` | `active` |
| Plasma | `systemctl --user is-active plasma-core.target` | `active` |
| COSMIC / GNOME / Plasma | `systemctl --user is-active steelbore-mouse-workspace-nav` | `active` |
| LeftWM | `pgrep -x eww`; `pgrep -x dunst`; `pgrep -x picom` | a PID each (started by the theme's `up` script) |
| LeftWM | `systemctl --user is-active graphical-session.target` | `inactive` — startx has no systemd graphical session, so no session-bound unit starts |
| LeftWM | `pgrep -x xremap` | a PID — side-button nav is started by `up` by hand, since its unit cannot fire |

**(c) Manual — seat required.** Not scriptable; check by eye at the machine:

- **Manual:** Panel or bar visible: the eww bar under Niri and LeftWM (clock in ISO 8601 with a UTC offset), the native panel under COSMIC, GNOME and Plasma.
- **Manual:** A test notification (`dunstify test`) renders through dunst under Niri and LeftWM.
- **Manual:** Lock screen: `Mod+Shift+L` (Niri) engages gtklock and `Ctrl+Alt+L` (LeftWM) engages i3lock; unlocking with the password works. LeftWM also locks after 300 s idle unless Caffeine is on.
- **Manual:** Fingerprint unlocks gtklock and falls through to the password prompt on a failed scan; it is never offered at the greetd login (policy: `modules/hardware/fingerprint.nix`, §6.1).
- **Manual:** Niri: `Mod+Shift+Slash` opens the hotkey overlay with every primary bind titled.
- **Manual:** Mouse side buttons switch workspace in every desktop, and the TrackPoint is unaffected.

### 17.3 Spacecraft Software Standard Compliance

- [✓] **Metallurgical naming:** Bravais (crystal structure)
- [✓] **Memory safety:** Rust-first packages, sudo-rs, Sequoia PGP, Nushell/Brush shells; bash excluded from login shells (NixOS module kept enabled for PAM/activation script compatibility — CONSTRAINTS.md #1, #2)
- [✓] **Performance:** XanMod kernel (`linuxPackages_xanmod_latest`); x86-64 march level pinned per machine (ThinkPad = v3), with the per-level flags CachyOS/ALHP-derived in `modules/platform/x86-64.nix` (the module accepts v1–v4; there is no build matrix)
- [✓] **Security:** Sequoia PGP, polkit, sudo-rs `execWheelOnly`, Secure Boot ready (`sbctl` installed, not yet enrolled)
- [✓] **License:** GPL-3.0-or-later; SPDX tags via REUSE, gated by `nix build --no-link '.#checks.x86_64-linux.reuse-lint'` (Standard §4.3)
- [✓] **Privacy — Bravais-owned components only:** the in-tree tools (`pkgs/preflight`, `pkgs/steelbore-*`, `bravais-mcp`) send no telemetry and link no HTTP-client crate (none of their `Cargo.lock` files carries `reqwest`, `hyper`, `ureq` or `curl`); their network use is the rebuild itself (`preflight`'s flake-input and Flatpak updates), and their state stays on the machine. **Out of scope:** third-party applications keep their vendors' telemetry defaults — browsers, Electron apps, the vendored desktop agents (§16.4) and the out-of-band AI CLIs (CONSTRAINTS.md #4). Bravais does not disable those system-wide; where a telemetry-free build exists it is installed alongside (VSCodium next to VS Code, §11.2)
- [✓] **Key bindings:** CUA + Vim keys — full hjkl focus in Niri (moves use H/J/K; `Mod+Shift+L` is gtklock); j/k only in LeftWM, because lefthk-core has no Left/Right focus/move commands (§9.5)
- [✓] **Color palette:** Standard §11.1 role tokens from the Standard §11 palette family, resolved by `lib/palette.nix` from `steelbore.toml` (the `construct` input); the `background` role on TTY, terminals, bars and notifications; no consumer names a brand colour
- [✓] **Typography:** Hack Nerd Font (UI), JetBrainsMono Nerd Font (terminal) — pinned in `modules/theme/fonts.nix` and `lib/terminal-theme.nix`
- [✓] **Date/Time:** ISO 8601 (`%Y-%m-%d %H:%M:%S`), 24h format in the eww bars and tuigreet, each followed by a labelled UTC offset (bars `UTC%-:::z`, tuigreet `UTC%:z`)
- [✓] **Containers:** Podman (not Docker; `dockerCompat` alias) with runc and Youki (Rust) as available OCI runtimes

---

*--- Forged in Spacecraft Software ---*
