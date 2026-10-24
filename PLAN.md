# Bravais — Plan: Steelbore OS identity

MVP: M0–M2 — Steelbore OS Bravais on every surface

**Scope.** Make the operating system call itself **Steelbore OS**, with
**Bravais** as its NixOS edition, everywhere a running machine states its
own name: `/etc/os-release`, the boot menu, the TTY greeting, the login
greeter, the bars, the shell banner, and the desktop "About" panels. The
project, the repository, the flake and the hostnames keep the name
**Bravais** — this plan renames the OS, not the project.

**Authority.** Standard §2.1 records the v1.7 umbrella rename
(Steelbore → Spacecraft Software) and states that *the OS line
(`Steelbore OS`, `Steelbore OS Bravais`, `Steelbore OS Lattice`) retains the
Steelbore name*. `Bravais` is a registered legacy-registry name. No new §2
codename is needed, and §11.6.5 already names Bravais as the NixOS flavor of
Steelbore OS — the vocabulary below (OS = Steelbore OS, variant = Bravais,
vendor = Spacecraft Software) is the Standard's own.

**Status (2026-10-11).** The identity is live after the switch and reboot:
os-release, lsb-release, `hostnamectl`, the boot entries, the TTY greeting,
KDE Info Center and fastfetch's text all say Steelbore OS Bravais 26.05
(Altair). M4 (`steelbore-version`) and M5 (`steelbore-help` and the manual)
are added below; M4 is in progress.

**Status (2026-10-09).** M0 and the M1/M2 code are in the working tree
and evaluate on both channels; M3's documentation is written. What remains
needs the live host: the `/etc/NIXOS` check right before the switch (P-004),
the standing gates (P-008), the first switch (P-009), the rollback drill
(P-010) and the visual check (P-020), plus the optional P-017, P-018, P-026.

**Status at drafting.** Nothing in the flake sets `system.nixos.distroName` or any
sibling, so `/etc/os-release` still says `NAME=NixOS`, the boot menu titles
read "NixOS", and `hostnamectl` reports NixOS. The only branded surfaces today
are hand-typed strings: the tuigreet greeting, both bar titles, the Plymouth
theme description, the MCP server and the docs. The Nushell `steelbore` banner
still prints the pre-v1.7 "STEELBORE" (commit 8bf8220 fixed the greeter and
the PRD but not the banner).

**Category.** Bravais declares no §19 assurance category; figures in this plan
are maintainer estimates (§17.1), one tick per verified item.

---

## Identity values

Stated once, in `lib/identity.nix`, and read by everything below. These are
the values as built (os-release evaluated on `steelbore-thinkpad`, 2026-10-09);
the **Decisions** section records the maintainer's four answers.

| Field (os-release)   | Value                                              | Source            |
|----------------------|----------------------------------------------------|-------------------|
| `NAME`               | `Steelbore OS`                                     | §2.1              |
| `ID`                 | `steelbore` *(decision D1)*                        | —                 |
| `ID_LIKE`            | `nixos` — emitted by nixpkgs when `ID ≠ nixos`     | `version.nix`     |
| `VARIANT`            | `Bravais`                                          | §11.6.5           |
| `VARIANT_ID`         | `bravais`                                          | §11.6.5           |
| `VENDOR_NAME`        | `Spacecraft Software`                              | §1                |
| `CPE_NAME` vendor    | `spacecraft-software` *(decision D2)*              | —                 |
| `VERSION`            | `26.05 (Altair)` — unstable `26.11 (Aldebaran)` *(decision D3)* | overrides upstream |
| `VERSION_ID`         | `26.05` — NixOS's release number                   | read-only upstream |
| `VERSION_CODENAME`   | `altair` — unstable `aldebaran` *(decision D3)*    | overrides upstream |
| `PRETTY_NAME`        | `Steelbore OS Bravais 26.05 (Altair)`              | overrides upstream |
| `HOME_URL`           | `https://Bravais.SpacecraftSoftware.org/`          | §15.1             |
| `VENDOR_URL`         | `https://SpacecraftSoftware.org/`                  | §15.1             |
| `DOCUMENTATION_URL`  | `https://Bravais.SpacecraftSoftware.org/`          | §15.1             |
| `SUPPORT_URL`        | `https://github.com/Spacecraft-Software/Bravais`   | §5                |
| `BUG_REPORT_URL`     | `https://github.com/Spacecraft-Software/Bravais/issues` | §5           |
| `ANSI_COLOR`         | `0;38;2;R;G;B` rendered from the palette's `accent` role | §11.4       |
| `LOGO`               | `steelbore-os` — the emblem icon *(decision D4)*   | `pkgs/steelbore-branding` |
| `DEFAULT_HOSTNAME`   | follows `ID`                                       | `version.nix`     |

Display strings derived from the same file: `Steelbore OS Bravais` (prose),
`STEELBORE OS :: BRAVAIS` (greeter and bar title register). `/etc/lsb-release`
carries the same codename (`DISTRIB_CODENAME`, `LSB_VERSION`,
`DISTRIB_DESCRIPTION`).

---

## M0 — One identity source

Bind the identity once and thread it like `primaryUser` and
`steelborePalette`, so no consumer retypes a name.

- [x] P-001 `lib/identity.nix`: a pure attrset carrying every value in the
      table above (names, ids, variant, vendor, URLs, the two display strings),
      with one comment per field citing its source
- [x] P-002 `flake.nix` imports it once as `steelboreIdentity` and passes it
      through **both** `specialArgs` and `extraSpecialArgs` (constraint #7
      shape; Home Manager consumers cannot read NixOS `config`)
- [x] P-003 AGENTS.md "Architecture" bullet: *Identity* — one line stating
      the file, the threading, and the rule "never retype the OS name;
      read `steelboreIdentity`"
- [x] P-004 Pre-check on the live host, before any switch in M1:
      `ls -la /etc/NIXOS`. `setup-etc.pl` recreates this marker on every
      activation and the repo enables no `system.etc.overlay`, so it should
      exist — but the sandboxed shell used to draft this plan could not see
      the host's `/etc` (both reads landed in a uid-1000 tmpfs). The marker
      is what lets `switch-to-configuration` accept the first switch after
      `ID` changes (see M1 and the Risks section). If it is missing, fix
      that first and record the finding as the next free constraint number
      (#47) in both files. *Seen present 2026-10-09 (`/etc/NIXOS`, 0 bytes,
      `system.etc.overlay` and `userborn` off on both channels); re-check
      right before P-009*

## M1 — os-release and boot identity

Set the nixpkgs identity options from `steelboreIdentity`. Every consumer in
this milestone flips for free once the options are set: `/etc/os-release`,
`/etc/lsb-release`, systemd-boot entry titles, the getty greeting line, the
stage-1/stage-2 banners, the bootspec label and the initrd's os-release.
Plymouth is unaffected (Bravais ships its own `script` theme; the `osName`
override only feeds the Breeze theme it does not use).

- [x] P-005 `modules/core/identity.nix` (always on, imported from
      `modules/core/default.nix`): sets `system.nixos.distroName`, `distroId`,
      `vendorName`, `vendorId`, `variantName`, `variant_id` from
      `steelboreIdentity`. Comment that the first four are `internal = true`
      upstream — settable (nixpkgs' own Limine test sets `distroName`) but
      undocumented, so both channels' evals are the regression check
- [x] P-006 Fill the fields nixpkgs blanks once `ID ≠ nixos`: in
      `version.nix`, `isNixos = distroId == "nixos"` gates `HOME_URL`,
      `VENDOR_URL`, `DOCUMENTATION_URL`, `SUPPORT_URL`, `BUG_REPORT_URL` and
      `ANSI_COLOR` to the empty string. Supply all six through
      `system.nixos.extraOSReleaseArgs`, which merges **after** the generated
      set and therefore also overrides `PRETTY_NAME` (upstream omits the
      variant) — the override is the line that makes `hostnamectl` and the
      "About" panels read "Steelbore OS Bravais"
- [x] P-007 `ANSI_COLOR` rendered from `steelborePalette.accent` with the
      hex-to-channel decoder in `lib/palette.nix` — the 0–255 integers that
      feed `floatChannel` (Plymouth and COSMIC consume the 0.0–1.0 float form;
      `ANSI_COLOR` wants the integers) — never a retyped triple (§11.4);
      `extraLSBReleaseArgs` left untouched — `lsb-release` follows
      `distroName`/`distroId` on its own. *Superseded by D3:*
      `extraLSBReleaseArgs` now carries the codename too
- [x] P-008 Eval gate before any switch:
      `nix eval --raw '.#nixosConfigurations.steelbore-thinkpad.config.environment.etc."os-release".text'`
      shows every row of the Identity table; repeat for `steelbore-thinkpad-unstable`.
      Then the two standing gates (stable toplevel build, unstable `drvPath`
      eval) and the REUSE check
- [x] P-009 First switch, in order: P-004 marker confirmed → `preflight`
      switch → verify `hostnamectl` ("Operating System: Steelbore OS Bravais
      26.05 (Altair)"), `bootctl list` entry titles, a TTY greeting
      (`<<< Welcome to Steelbore OS … >>>`), `cat /etc/os-release`.
      *Done 2026-10-11; the boot titles were read from the entry builder
      because `/boot` is root-only*
- [ ] P-010 Rollback drill: boot the previous generation once and switch
      forward again — `switch-to-configuration` of the *old* generation
      carries `DISTRO_ID=nixos` and must still accept a system whose
      `/etc/os-release` says `ID=steelbore`; the `/etc/NIXOS` marker is what
      makes both directions pass
- [x] P-011 Boot menu version column: systemd-boot's builder puts only
      `distroName` (plus profile and specialisation) in the entry **title**;
      `system.nixos.label` lands in the entry's **version** field. Decide
      whether `system.nixos.tags` gains `bravais` so that column reads
      `bravais-26.05…`; default no — VARIANT already carries it, and the
      title reads `Steelbore OS` either way (optional). *Decided: no tag*
      (comment in `modules/core/identity.nix`)

## M2 — Desktop and shell surfaces

Replace every hand-typed name with a read of `steelboreIdentity`, and give the
desktop "About" panels what they need beyond os-release.

- [x] P-012 tuigreet `--greeting` in `modules/login/default.nix` reads the
      display string instead of the literal
- [x] P-013 Both bar titles — `users/mj/eww.nix` (Niri) and the eww block in
      `modules/desktops/leftwm.nix` — read the same display string; one
      change, both bars (constraint #26: keep them in step; `//` comments
      only, no non-ASCII in `/* */`)
- [x] P-014 The Nushell `steelbore` banner in `users/mj/shell.nix` prints
      the identity (`STEELBORE OS :: BRAVAIS`, the variant line, the §15.2
      attribution block: maintainer, contact, project URL) instead of the
      pre-v1.7 "STEELBORE :: Industrial Sci-Fi Desktop Environment"
- [x] P-015 Plymouth theme `Description=` in `pkgs/steelbore-plymouth` takes
      the name from the identity via a package argument (today a literal);
      splash artwork unchanged
- [x] P-016 KDE Info Center "About this System": ship
      `/etc/xdg/kcm-about-distrorc` (`Name`, `Variant`, `Website`, and
      `LogoPath` once D4 exists) from `modules/desktops/plasma.nix`; GNOME
      Settings reads os-release `LOGO`; COSMIC Settings shows `PRETTY_NAME`
      only, with no logo.
      *Landed in `modules/theme/branding.nix` instead, always on (not tied to
      Plasma), with `LogoPath` = the wordmark's store path and
      `UseOSReleaseVersion=true` so the codename shows*
- [ ] P-017 `/etc/machine-info` (`PRETTY_HOSTNAME`, `CHASSIS=laptop`,
      `ICON_NAME`) via `environment.etc` so GNOME's "Device Name" and
      `hostnamectl` present a titled host, not a bare `steelbore-thinkpad`
      (optional)
- [ ] P-018 Fetch tools: `fastfetch` picks its logo by `ID` and will fall
      back to a generic mark once `ID=steelbore`; `macchina` (`telemetry`)
      reads `PRETTY_NAME` and is fine. Point `fastfetch`'s `logo.source` at a
      Steelbore ASCII mark in `assets/brand/` (optional)
- [x] P-019 Rust binaries that state the OS name — `pkgs/preflight`
      (`about`, the `describe` JSON) and `bravais-mcp` (`"os": …`, the
      `env` tool text) — take it from a build-time env var set in their
      `package.nix` from `steelboreIdentity`, read with `env!` in a
      `build.rs`, so the string has one source in Nix and a
      `cargo build` outside Nix still works via a default (optional)
- [ ] P-020 Post-switch visual check on every enabled desktop: GNOME
      Settings → About, KDE Info Center, COSMIC Settings → About, the Niri
      and LeftWM bars, the greeter, one TTY; record the result in the PR

## M3 — Documentation and release

- [x] P-021 `README.md`: an "Identity" paragraph under the title stating
      OS / variant / vendor and that `nixos-*` commands keep their names
      because Bravais is a NixOS distribution (as `apt` stays `apt` on a
      Debian derivative)
- [x] P-022 `PRD.md` §4 "Steelbore Visual Identity": a subsection for the OS
      identity — the table above, the single source, and the consumer list
- [x] P-023 `TODO.md`: a dated "Steelbore OS identity" phase mirroring M0–M3
      with `[✓]` markers as items land
- [x] P-024 `CHANGELOG.md` `[Unreleased]` → `### Changed`: one bullet, "The
      OS identifies itself as Steelbore OS Bravais" naming the surfaces, no
      version numbers
- [ ] P-025 `CONSTRAINTS.md` + AGENTS.md "Known constraints": a marker
      constraint **only if** P-004 or P-010 finds that the `ID` change needs
      the `/etc/NIXOS` marker to be provided explicitly; otherwise no new
      constraint. *#45 has since gone to gtklock. P-004 is satisfied (the
      marker exists and `setup-etc.pl` recreates it on every activation), but
      the rollback drill (P-010) has not run, so this stays open until it has*
- [x] P-027 Constraint #46 in both `CONSTRAINTS.md` and AGENTS.md: D3 made
      every NixOS release need a codename entry in `lib/identity.nix`, or
      evaluation fails — a channel bump trap worth recording
- [ ] P-026 Memory note for future sessions: identity lives in
      `lib/identity.nix`; never retype the OS name — P-003's AGENTS.md rule
      already carries this for every agent (optional)

---

## M4 — `steelbore-version`, and `nixos-version` as its alias

**Goal.** A Rust `steelbore-version` that reports the running system the way
`nixos-version` does, under the Steelbore OS name and codename, and that
answers as `nixos-version` too. Today `nixos-version` is NixOS's generated
shell script (`nixos/modules/installer/tools/nixos-version.sh`): it prints
`<version> (<codeName>)`, `--hash`/`--revision`, `--configuration-revision`
and `--json`, with every value substituted in at evaluation time. It is the
last surface still saying "Yarara".

**Where the data comes from.** The values are module-evaluation results
(`system.nixos.version`, `.release`, `.revision`, `.codeName`,
`system.configurationRevision`, the identity), which an in-tree package cannot
see. Baking them into the Rust build would rebuild the crate on every nixpkgs
bump, so the binary stays generic and reads a **version record** at run time.
`modules/core/identity.nix` writes it as a package in `systemPackages`, so it
lands at `/run/current-system/sw/share/steelbore/version.json`: the same
"what is the current system" answer the upstream script gives. Not `/etc`:
bubblewrap FHS environments (AppImages, this agent's own shell) replace `/etc`
with a tmpfs and would not see it, but they bind `/run`. `STEELBORE_VERSION_FILE`
overrides the path, for tests and for checking a record before switching.

**The alias.** The package ships `bin/nixos-version` as a symlink to
`bin/steelbore-version`, and the binary branches on the name it was invoked
by:

| Invoked as | Behaviour |
|---|---|
| `steelbore-version` | CLI Standard: `metadata` + `data` envelope, `--json`/`--format`, `--fields`, `schema`, `describe`, exit codes 0/1/2/3, presence-based agent detection, `--version` with the maintainer line |
| `nixos-version` | Upstream's exact contract, so existing scripts keep working: the bare line `<version> (<codename>)`, `--hash`/`--revision` and `--configuration-revision` exiting 1 with upstream's message when unknown, `--json` with upstream's camelCase keys and key order, only `$1` consulted |

Both print the **Steelbore** codename (`26.05 … (Altair)`); that is the point
of the alias. Upstream's own script must be switched off with
`system.tools.nixos-version.enable = false`, or two packages provide
`bin/nixos-version` and the system `buildEnv` collides; that trap becomes
constraint #47.

- [x] P-028 `pkgs/steelbore-version/`: Rust crate (`clap`, `serde`,
      `serde_json`, `jiff`), `build.rs` injecting the OS name and URL from
      `lib/identity.nix` as `pkgs/preflight` does; `package.nix` adds the
      `nixos-version` symlink; indexed in `pkgs/default.nix`
- [x] P-029 Version record: `modules/core/identity.nix` writes
      `share/steelbore/version.json` (name, variant, ids, vendor, release,
      version, Steelbore codename, NixOS codename, nixpkgs revision,
      configuration revision, pretty name, home URL), installs the package,
      and sets `system.tools.nixos-version.enable = false`
- [x] P-030 `steelbore-version` surface: bare line; `--revision` (alias
      `--hash`); `--configuration-revision`; `--codename`; `--pretty`
      ("Steelbore OS Bravais 26.05 (Altair)"); `--json` / `--format`;
      `--fields`; `schema` and `describe` subcommands; an unknown revision is
      exit 3 with a hint, a missing record is exit 3 naming the path
- [x] P-031 `nixos-version` compatibility, checked byte for byte against
      upstream's output on this host (bare, `--hash`, `--json`, unknown
      configuration revision)
- [x] P-032 Constraint #47 in `CONSTRAINTS.md` and AGENTS.md: upstream's
      `nixos-version` stays disabled while `steelbore-version` provides the
      name
- [x] P-033 Docs: README's identity paragraph and `lib/identity.nix`'s
      codename comment (`nixos-version` no longer says "Yarara"), PRD
      package inventory, TODO, CHANGELOG `### Added`
- [ ] P-034 Verify after the switch: `steelbore-version`, `nixos-version`,
      `nixos-version --json`, and `steelbore-version` inside a bubblewrap
      sandbox (a Claude Code shell)
- [ ] P-035 Set `system.configurationRevision = self.rev or self.dirtyRev or null`
      in `flake.nix`, so `--configuration-revision` answers. Cost: the
      toplevel store path changes with every commit, which ends the
      "unchanged toplevel proves a no-op refactor" check used in the past
      (optional)
- [ ] P-036 Man pages `steelbore-version(1)` and `nixos-version(8)`:
      upstream's `-h` runs `man nixos-version`, which goes away with
      upstream's package; until then `--help` serves both names (optional)

## M5 — `steelbore-help` and the Steelbore OS manual

**Goal.** A Steelbore OS manual covering the OS and the Spacecraft Software
tools that ship on it, opened by a Rust `steelbore-help`, with `nixos-help`
as its alias. Today `nixos-help` is a shell script that opens the NixOS HTML
manual in `$BROWSER`, `xdg-open` or `w3m`. It comes from
`documentation.nixos.enable`, bundled with the manual and its "NixOS Manual"
desktop entry, with no separate switch.

**The manual.** Texinfo is the house canonical prose format: one source
builds HTML and Info. Proposed outline:

1. **Steelbore OS:** identity, installing, rebuilding (`preflight`), desktops
   and sessions, theming (`theme`), default applications (`app`), security
   (keyring, fingerprint, `sudo-rs`), troubleshooting (the constraints, in
   prose)
2. **Spacecraft Software tools:** gitway, vacuum, mj, mjsh (Operator),
   pathfinder, preflight, steelbore-version, steelbore-help, steelbore-vpn,
   steelbore-quantize, mcpctl, engram. Each chapter is sourced from that
   project's own documentation where it exists, never retyped
3. **NixOS:** the upstream NixOS manual and options reference, reached from
   the Steelbore manual rather than forked (see D5)

**D5 — open, for the maintainer: how far to "update the NixOS manual".**
Forking the NixOS manual's text means carrying a rebrand across thousands of
upstream pages that change every release. The proposal is to leave its text
alone and wrap it: the Steelbore manual is the front page, and the NixOS
manual stays one part of it. Its title and desktop entry can carry the
Steelbore name without editing its prose.

- [ ] P-037 Decide D5
- [ ] P-038 `docs/manual/steelbore.texi` and a `steelbore-manual` package
      building HTML and Info
- [ ] P-039 Chapters for the Spacecraft Software tools, sourced from each
      project's docs; needs a source for every tool not in this tree (mjsh,
      gitway, vacuum, pathfinder, mj)
- [ ] P-040 `pkgs/steelbore-help/`: Rust; opens the HTML manual the way
      `nixos-help` picks a browser; `--info` opens the Info manual in the
      terminal; `--nixos` opens the upstream NixOS manual; `--json` reports
      the manual locations; `schema` and `describe`
- [ ] P-041 The `nixos-help` alias: since `documentation.nixos.enable` cannot
      drop only the script, ship `bin/nixos-help` and a `nixos-manual.desktop`
      ("Steelbore OS Manual") from `steelbore-help` at `lib.hiPrio`, so the
      system `buildEnv` takes ours. Record the mechanism as a constraint
- [ ] P-042 Docs, and verify `steelbore-help`, `nixos-help` and the menu
      entry after the switch

---

## Decisions for the maintainer — resolved

All four answered by the maintainer. Resolved:

- **D1 = `steelbore`** (the default).
- **D2 = `spacecraft-software`** (the default).
- **D3 = Steelbore OS's own codenames**: Arabic-origin star names, one per
  NixOS release, in `lib/identity.nix` `codenames` / `codenameFor`
  (**26.05 = Altair**, **26.11 = Aldebaran**). `VERSION`,
  `VERSION_CODENAME`, `PRETTY_NAME` and lsb-release's `LSB_VERSION`,
  `DISTRIB_CODENAME`, `DISTRIB_DESCRIPTION` are overridden together.
  `codeName` is read-only upstream, so `nixos-version` and the bootspec keep
  NixOS's name — accepted. A release with no entry fails evaluation
  (CONSTRAINTS.md #46).
- **D4 = the maintainer's marks**: the emblem
  (`assets/brand/steelbore-os.svg`) is the OS logo — os-release
  `LOGO=steelbore-os`, GNOME About (COSMIC About shows no logo); the wordmark
  (`assets/brand/steelbore-os-wordmark.svg`, icon `steelbore-os-wordmark`) is KDE Info Center's `LogoPath`.
  Their single fill is replaced at build time with the active palette's
  `foreground` role (`pkgs/steelbore-branding`, `modules/theme/branding.nix`).

The original options and defaults, as drafted:

- **D1 — `ID` slug.** **`steelbore`**. It coincides with the default
  *palette* slug (`theme.nix`), which is a different namespace — an
  os-release id and a theme slug never meet — but the coincidence is worth
  a sentence in the comment. Alternatives: `steelbore-os`, `steelboreos`.
  `ID` must match `^[a-z0-9._-]+$`.
- **D2 — CPE vendor token.** **`spacecraft-software`** (CPE components
  allow `-`), giving `CPE_NAME=cpe:/o:spacecraft-software:steelbore:26.05`.
  Alternative: `spacecraftsoftware`.
- **D3 — Release codename.** **Keep NixOS's** (`26.05 (Yarara)`): `release`
  and `codeName` are read-only upstream, Bravais tracks NixOS releases, and a
  §2 stellar release name would have to be carried by overriding `VERSION`,
  `VERSION_CODENAME`, `PRETTY_NAME` **and** `extraLSBReleaseArgs` together,
  then kept in step with every nixpkgs bump. Revisit when Bravais cuts its own
  release tags.
- **D4 — Logo.** **None yet.** No Steelbore mark exists in the repository, the
  Theme input or the brand skill; the splash is artwork, not a logo. Until the
  maintainer supplies an SVG mark (`assets/brand/steelbore-os.svg`, installed
  into `hicolor/scalable/apps`, colors read from the palette), `LOGO` stays
  `nix-snowflake` and P-016's `LogoPath` is omitted. The GNOME About page will
  show the snowflake under "Steelbore OS" in the meantime.

---

## Risks and how they are bounded

- **The first switch and every rollback.** `switch-to-configuration` (the
  `-ng` Rust port in use) accepts a system if `/etc/NIXOS` exists **or** the
  running `/etc/os-release` `ID` matches its baked-in `DISTRO_ID`. Across the
  `ID` change those ids differ in both directions, so the marker is the only
  pass condition — hence P-004 before P-009, and P-010 after.
- **`internal = true` options.** `distroName`, `distroId`, `vendorName`,
  `vendorId` are hidden from the option manual and carry no stability
  promise. Both channels are evaluated on every rebuild (constraint #17's
  gate), which is the early warning if they move.
- **Tools that key on `ID=nixos`.** Nothing in this repository reads
  `/etc/os-release` (`preflight`, `rebuild-classic.nu`, `rebuild-classic.sh`, `bravais-mcp`
  all grep clean); Home Manager has no such check; `nixos-rebuild-ng`'s
  "nixos" match is a channel directory name. The out-of-band self-updating
  tools (constraint #4) may inspect `ID`; well-behaved detectors also read
  `ID_LIKE=nixos`, which nixpkgs emits automatically. State it in the PR,
  test each of those tools once after P-009, do not chase further.
- **Name drift.** Three bars and greeters already retyped the string before
  this plan; M0's single source and the AGENTS.md rule are the fix, and
  P-020 is the check.

## Verification surfaces (checklist for the PR)

| Surface | Command / place | Expect |
|---------|-----------------|--------|
| os-release | `cat /etc/os-release` | every row of the Identity table |
| lsb-release | `cat /etc/lsb-release` | `DISTRIB_ID=steelbore`, description "Steelbore OS Bravais 26.05 (Altair)" |
| systemd | `hostnamectl` | `Operating System: Steelbore OS Bravais 26.05 (Altair)` |
| Boot menu | `bootctl list` | titles begin `Steelbore OS` |
| TTY | Ctrl+Alt+F2 | `<<< Welcome to Steelbore OS … >>>` |
| Greeter | tuigreet | `STEELBORE OS :: BRAVAIS` |
| Bars | Niri, LeftWM | same title, both bars |
| Shell | `steelbore` | identity + §15.2 attribution |
| GNOME | Settings → About | OS name Steelbore OS Bravais |
| KDE | Info Center | name, variant, website |
| COSMIC | Settings → About | OS name |
| Fetch | `telemetry`, `fastfetch` | name correct; logo per D4 / P-018 |
| Logo | GNOME About, KDE Info Center | emblem; wordmark in KDE; both in the palette's `foreground` |
