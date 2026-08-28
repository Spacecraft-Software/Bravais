# AGENTS.md — Bravais (Steelbore OS)

Authoritative agent context (Standard §5.7). Every agent reads this file;
`CLAUDE.md` imports it and adds only Claude-Code-only notes.

## What this is

A flake-based NixOS configuration implementing **The Spacecraft Software Standard** (renamed from "Steelbore Standard" at Standard v1.7). The `mkBravais { host, channel }` function in `flake.nix` generates **per-machine nixosConfigurations**: `bravais-thinkpad` (stable 26.05) and `bravais-thinkpad-unstable` (nixos-unstable), plus a `bravais` alias → stable ThinkPad. The x86-64 march level is pinned inside each machine's host config (the ThinkPad's i7-8665U is x86-64-v3 — no AVX-512), not exploded into a v1–v4 matrix. Adding a machine = drop a `hosts/<machine>/` dir + two output lines in `flake.nix`.

## Technology stack

| Layer | Technology |
|-------|-----------|
| OS / package manager | NixOS (nixpkgs stable `nixos-26.05` + unstable `nixos-unstable`) |
| Configuration format | Nix expressions (`.nix`) |
| Flake entry point | `flake.nix` |
| User environment | Home Manager (stable `release-26.05` + unstable) |
| Declarative Flatpak | `nix-flatpak` |
| Git SSH transport | `gitway` (Spacecraft Software flake input, tracks `main`) |
| Agent skill hub | `construct` (Spacecraft Software flake input) |
| Primary user shell | Nushell (Rust) |
| Root shell | Brush (Rust, Bash-compatible) |
| Kernel | XanMod latest (performance-optimized) |
| Audio | PipeWire (PulseAudio disabled) |
| DNS | systemd-resolved with DNS-over-TLS + DNSSEC enforced |
| Containers | Podman (`dockerCompat`), runc default runtime, Youki (Rust) available |
| Login manager | greetd + tuigreet |

**No traditional language build tools** (Cargo, npm, etc.) build the project
itself. The project is pure Nix.

## Build and test commands

```sh
# `nix flake check` builds BOTH channels' full closures and exceeds 10 min —
# not a usable gate. Use the toplevel build + unstable eval (constraint #17).
nix build --no-link '.#nixosConfigurations.bravais-thinkpad.config.system.build.toplevel'
nix eval --raw '.#nixosConfigurations.bravais-thinkpad-unstable.config.system.build.toplevel.drvPath'
nix build .#<name>                                      # One in-tree pkg (after `git add -A`)
nix flake show                                          # List outputs
nixos-rebuild dry-build --flake .#bravais-thinkpad      # Dry run
sudo nixos-rebuild switch --flake .#bravais-thinkpad    # Apply (stable ThinkPad, v3)
sudo nixos-rebuild switch --flake .#bravais-thinkpad-unstable # Unstable channel
sudo nixos-rebuild switch --flake .#bravais             # Alias → stable ThinkPad
```

## Rebuild commands (user's actual workflow)

Targets `bravais-thinkpad` (stable; march pinned to v3 in `hosts/thinkpad/`). Stages `/etc/nixos/` from the working tree, garbage-collects, wipes `/tmp`, vacuums journal, checks disk, then rebuilds. Run as the user, not as root.

```nu
# Nushell
cd /spacecraft-software/bravais/ ; gitway-add ~/.ssh/<signing-key> ; nix flake update antigravity-nix construct gitway ; sudo nix-collect-garbage --verbose -d ; sudo rm -r /tmp/* ; sudo journalctl --vacuum-time=7d ; df -h / ; sudo cp --verbose -r ...(glob /spacecraft-software/bravais/*) /etc/nixos/ ; print "cd /etc/nixos/" ; cd /etc/nixos/ ; sudo rm --verbose -r ...( [v0 "*.md" "flake.*" LICENSE "*.docx" hosts lib modules overlays users "*.txt"] | each { |p| glob $p } | flatten ) ; cd /spacecraft-software/bravais/ ; sudo nixos-rebuild switch --flake .#bravais-thinkpad --show-trace --verbose
```

`nix flake update construct` is the *first half* of `skills-sync`, which also builds the new tree and moves the skill pointer, so no rebuild is needed to apply it — see "The skill pointer" below.

The whole sequence above is now wrapped in a Nushell `def rebuild` command (defined in `users/mj/home.nix`, after `skills-ship`), so the user can just type `rebuild`. It differs from the raw chain in three deliberate ways: GC keeps a week of generations (`--delete-older-than 7d`, not `-d`); the update list also bumps `nixpkgs-unstable` + `home-manager-unstable` so `unstablePkgs` never lags stable (plan 5.2), and a monthly nag reminds to run `nu pkgs/update-vendored.nu --check` (vendored-binary bumps, plan 5.1); the `/tmp` wipe is dropped (builds use `/mnt/nix-tmp`, and `rm -r /tmp/*` can kill an X11/LeftWM session); and the `/etc/nixos` step is a lean `rsync -av --delete --delete-excluded` mirror (tracks deletions, prunes stale files; excludes `.git/`, `result`, `.claude/`) that runs only after a successful switch. It also updates the declared Flatpaks, **last**, after the switch, and **detached** — it starts `flatpak-update` and returns rather than waiting. `services.flatpak.update.onActivation` is the more obviously declarative spelling and is deliberately NOT used: it blocks activation on an unbounded download (a browser is ~150 MB, a runtime bump ~250 MB, and the full set measured 4.4 GB at ~0.4 MB/s ≈ three hours), and a switch held open for hours — or interrupted part-way — is a worse failure than a Flatpak being a few days old. Running it inline after the switch was the first shape and carried the same cost minus the half-applied-system risk; detaching is what removes the wait. These entries pin no version anyway, so "current" is a property of the remote, not of this flake. The weekly timer in `modules/packages/flatpak.nix` remains the safety net for stretches without a rebuild.

Three Nushell commands back it, defined beside the `skills-*` ones: `flatpak-status` (a record — refs still outdated, whether an update is running, free space, log tail), `flatpak-update` (starts a detached update via `setsid --fork`, writing to `~/.local/state/flatpak-update.log`), and `flatpak-log` (that path, fixed so both share one log). Two non-obvious details are encoded there: the log must be split on `\r` before reading, because Flatpak redraws its progress bar in place and the file is otherwise one enormous line that reads as frozen; and the running check filters `flatpak-wrappe`, not `flatpak`, because `flatpak-session-helper`, `-portal` and `-system-helper` are always-on daemons that would report `running = true` forever.

After the flake update (full path only) it runs an `antigravity-status` probe -- see constraint #27 -- which warns if `antigravity-nix`'s pinned Antigravity IDE is behind what Google advertises, because bumping that input cannot move the pins inside it.

`scripts/rebuild.sh` is the same sequence for a shell that is not Nushell -- an agent's tool shell, a rescue TTY, or a session where Home Manager has not been activated and the `rebuild` function therefore does not exist. It takes the identical flags and performs the identical steps; **change one and change the other**. Written to the POSIX subset under a Bash shebang (§7.1), so it also runs under `dash`, `ash` and `brush` -- verify with `nix run nixpkgs#shellcheck -- -s sh scripts/rebuild.sh`, which must stay at zero findings. Two behaviours differ by necessity: the Nushell `antigravity-status` and `flatpak-status` return records that other commands consume as data, whereas the script only prints; and the mcpctl drift probe needs `jaq` or `jq` for its filter expressions, so it is **skipped with a note** when neither is present rather than allowed to fail into a silently-wrong zero (the bundled `python3` fallback understands dotted paths only, which is all the antigravity probe needs).

Flags: `--dry` (dry-build, no cleanup/mirror), `--no-update`, `--no-gc`, `--trace` (adds `--show-trace --verbose`), `--skills-only` (bump only `construct`; skip GC, the mirror and the mcpctl probe), `--no-flatpak` (skip the Flatpak update).

Measured cost of a prose-only skill change, so the flags can be chosen on evidence rather than feel: the skill derivation itself is **~0.6 s** (2.9 MB, 44 skills), a warm system eval is **~20 s** (the tree is usually dirty, so there is no eval cache at all), and the `/etc/nixos` no-op rsync is **~0.05 s** — not a cost worth gating on a diff. The expensive parts are the five-input `flake update` and the GC, which is exactly what `--skills-only` drops. `skills-sync` avoids the switch altogether.

## Architecture

- **Flake inputs**: nixpkgs (26.05), nixpkgs-unstable, home-manager (release-26.05), home-manager-unstable, nix-flatpak, gitway (`github:Spacecraft-Software/Gitway`, SSH-for-Git), construct (`github:Spacecraft-Software/Construct`), antigravity-nix (`github:UnbreakableMJ/antigravity-nix`, IDE only), rapg (path-flake wrapper at `flakes/rapg/`, since upstream `github:kanywst/rapg` ships no flake), mcp-servers (`github:Spacecraft-Software/mcp-servers`, provides `mcpctl`), vacuum (`github:Spacecraft-Software/Vacuum`, disk-space CLI/TUI), and engram (`github:Spacecraft-Software/Engram`, chat memory + the `engram` MCP server). No third-party DE flakes. (The five local Rust-app path inputs — loran, doas-rs, reel, rget, whatshell — were removed; they drifted their NAR hashes and weren't worth the maintenance.)
- **Module namespace**: All opt-in modules use `steelbore.*` with `lib.mkEnableOption`. Toggled in `hosts/common.nix` (shared) and per-machine `hosts/<machine>/default.nix` (hardware toggles + march pin).
- **Color palette**: Standard §11 is a *family* of seven adoptable palettes, plus any local ones in `themes/`. `lib/palette.nix` selects one by slug (`active` in **`theme.nix`**, currently `steelbore` = Steelbore Modern; use `theme set <slug>`, and `theme try <slug>` to build a theme without editing anything) and resolves it to the §11.1 **role** tokens — `background`, `surface`, `surfaceAlt`, `foreground`, `accent`, `structure`, `success`, `error`, `warning`, `info`, `focus`, `border` — threaded as `steelborePalette` via `specialArgs`/`extraSpecialArgs`. **Never name a brand color** (`moltenAmber`, `voidNavy`, …); those identifiers are gone and naming one defeats the whole point — switching palettes is one word in `flake.nix` precisely because no consumer knows which palette is active. Values are read from `steelbore.toml` in the `construct` input, never retyped (§11.4). Roles a palette omits fall back (`info` → `structure` → `accent`, `surface` → `background`, `warning` → `error`, `focus` → `success`). **`surface`/`surfaceAlt` are fills only, never text** (§11.0.1 — Quantum Blue is 1.40:1 on the canvas); putting status-colored text on a surface also drops `structure` and `error` below the 4.5:1 AA floor on Modern, which is why the eww bar and dunst deliberately stay on the canvas.
- **Primary user**: `primaryUser = "mj"` is stated once in `flake.nix` and threaded via `specialArgs`/`extraSpecialArgs`; modules use `users.users.''${primaryUser}` / `home-manager.users.''${primaryUser}` — never a literal `mj`. (The `users/mj/` directory name is a stable path, not a restatement.)
- **Overlays**: Defined inline in `modules/core/nix.nix` — the sole location. (The dead `overlays/` reference copy and the `modules/core/brush-wrapper.nix` tombstone were deleted in Phase A of the engineering-elegance plan, 2026-07-04.)
- **Home Manager**: Single user `mj`, config at `users/mj/home.nix`. Uses `useGlobalPkgs`, `useUserPackages`, `backupFileExtension = "backup"`.

## File layout

```
flake.nix                  # mkBravais, inputs, palette, per-machine configs
hosts/common.nix           # Shared host: user, shell, steelbore.* toggles
hosts/thinkpad/default.nix # ThinkPad: hostName, hardware toggles, march pin (v3)
hosts/thinkpad/hardware.nix # Generated hardware config
modules/core/              # Always-on: boot, nix, nix-tmp, locale, audio, security,
                           #   dns, keyring, memory
modules/core/nix.nix       # Overlays live here (inline)
modules/core/nix-tmp.nix   # Loop-mounted /mnt/nix-tmp as builder TMPDIR (off system disk)
modules/core/dns.nix       # systemd-resolved DoT + DNSSEC (Cloudflare malware-block)
modules/theme/             # Palette env vars, TTY colors, fonts, dark-mode portal/dconf
modules/desktops/          # gnome, cosmic, plasma, niri, leftwm (+ shared.nix dunst, assertions.nix guards,
                           #   niri-unmax.nix, mouse-workspace-nav.nix side-button workspace nav)
modules/hardware/          # steelbore.hardware.* vendor toggles: bluetooth, fingerprint,
                           #   intel (kvm-intel, microcode), audio-led daemon
modules/platform/          # steelbore.platform.x86_64: marchLevel + compiler/linker flags (ISA, vendor-neutral)
modules/login/             # greetd + tuigreet + shell sessions (single default.nix)
modules/services/          # steelbore.services.*: podman (container runtime),
                           #   ollama, chrome-remote-desktop
modules/compat/            # steelbore.compat.*: appimage (binfmt auto-run)
modules/packages/          # 14 opt-in bundles: ai, browsers, development, editors,
                           #   flatpak, games, homebrew, multimedia, networking,
                           #   orca, productivity, security, system, terminals
users/mj/default.nix       # System user definition (users.users.${primaryUser})
users/mj/home.nix          # HM core: identity + imports (~90 lines; Phase D split)
users/mj/{git,shell,terminals,niri,desktop-theme,apps}.nix  # one-concern HM modules
users/mj/default-apps.nix  # THE ONLY xdg.mimeApps block + the FileManager1 D-Bus shadow
pkgs/default.nix           # callPackage index; also the flake's packages.* output
pkgs/                      # In-tree packages — `pkgs/default.nix` is the authoritative index:
                           #   steelbore-audio-led, steelbore-beacon,
                           #   steelbore-niri-unmax, claude-desktop,
                           #   chrome-remote-desktop, ollama, github-copilot-app, bravais-mcp,
                           #   opencode-desktop, goose-desktop, codex-desktop,
                           #   adguardvpn-cli, crates-mcp, obscura, skyroads
                           # Each is also a flake output: `nix build .#<name>`
pkgs/update-vendored.nu    # Bumps the 10 version+hash-pinned upstream packages (see below)
pkgs/sync-skills.nu        # Skill sync helper
scripts/rebuild.sh         # POSIX/Bash port of the Nushell `rebuild` (keep the two in step)
theme.nix                  # THE ACTIVE THEME — one word; `theme set <slug>` rewrites it
themes/<slug>.nix          # local themes (filename = slug); `base` to derive, or bind roles
lib/palette.nix            # §11 palette family: slug -> role tokens + ANSI map + converters
default-apps.nix           # THE ACTIVE HANDLERS — one word per role; `app set <role> <slug>`
apps/<slug>.nix            # app drop-ins (filename = slug); may shadow a built-in entry
lib/default-apps.nix       # handler roles: role -> MIME list, app catalog, resolver
```

**Legacy v0 artifacts at repo root — not part of the flake, do not edit:**
`home.nix`, `system.nix`, `ARCHITECTURE.md`, `BRAVAIS.md`, `USER_MANUAL.md`,
`implementation_plan.md`, `PackagesMissing.md`, `v0.zip`. These predate the
`modules/` + `users/mj/home.nix` layout and are unreferenced by `flake.nix`
(confirmed via `rg` — nothing imports root `home.nix`/`system.nix`). The
*active* equivalents are `users/mj/home.nix` and `modules/packages/system.nix`.
Root `README.md`, `PRD.md`, `TODO.md`, `Packages.md`, `CHANGELOG.md`,
`NOTICE.md`, `CONTRIBUTING.md` are current and tracked per "Documentation
maintenance" below — don't confuse the two sets.

## Module design pattern

All opt-in modules follow the `steelbore.*` namespace — `options.steelbore.<area>.<name>`
declared with `lib.mkEnableOption`, implementation behind `lib.mkIf cfg.enable`.
Read any file under `modules/` for the shape.

`lib/` holds `palette.nix` (§11 palette family: slug → role tokens + ANSI map +
format converters), `default-apps.nix` (handler roles → MIME lists, app catalog,
resolver) and `terminal-theme.nix` (terminal theme record + emitters); the former
`lib/default.nix` helper was removed for simple cases.

**Host toggles** live in `hosts/common.nix` under the `steelbore` attribute set —
all 14 package bundles and all 5 desktop environments are enabled there.
`hosts/thinkpad/default.nix` carries only what is genuinely per-machine:
`networking.hostName`, the `steelbore.hardware.*` toggles, the CRD service and
the march pin.

## First-time bootstrap

Skills are installed from the `construct` flake input (`github:Spacecraft-Software/Construct`)
via `construct.homeManagerModules.default` (enabled as `spacecraft.construct` in `home.nix`).
HM copies all cross-platform skills into a store tree and symlinks
`~/.agent/skills`, `~/.ai/skills`, `~/.aichat/skills`, `~/.claude/skills`, `~/.codex/skills`,
`~/.copilot/skills`, `~/.opencode/skills` to `~/.agents/skills`. `.gemini` is intentionally
omitted — Gemini reads `~/.agents/` directly. `~/.agents/skills` itself is a pointer, not a
store path — see "The skill pointer" below.

No manual clone of `/spacecraft-software/construct` is needed for skill installation —
everything comes from the flake. The local clone at `/spacecraft-software/construct` is
only needed for skill authoring.

### The skill pointer (no rebuild, no sudo)

`~/.agents/skills` is **not** a store path. It is a symlink to
`~/.local/state/construct/current`, and the layout is:

```
~/.local/state/construct/pinned   -> /nix/store/…-construct-skills   # home.file; GC-rooted by the HM generation
~/.local/state/construct/built    -> /nix/store/…-construct-skills   # `nix build --out-link`; GC-rooted by its own auto root
~/.local/state/construct/current  -> …/pinned  (tracking the lock)  or  …/built  (moved ahead)
~/.agents/skills                  -> ~/.local/state/construct/current
~/.<agent>/skills  (×9)           -> ~/.agents/skills
```

| Command | Effect |
|---------|--------|
| `skills-sync` | `nix flake update construct`, build `.#skills` at the **new lock**, move `current` — skills live in seconds |
| `skills-status` | Is the live tree the flake-pinned one? |
| `skills-reset` | Discard a moved pointer, back to the lock |
| `rebuild --skills-only` | Full switch, but only bumps `construct`; skips GC, the `/etc/nixos` mirror and the mcpctl probe |

Two rules that are not obvious and are easy to break:

1. **`current` only ever points at `pinned` or at `built`.** Never `ln -s` it at
   a bare `/nix/store/…` path: that shape has no GC root, and the next
   `nix-collect-garbage` deletes the skill tree out from under every agent on
   the machine. Both legal targets are rooted — `pinned` via the HM generation,
   `built` via the indirect root `--out-link` registers under
   `/nix/var/nix/gcroots/auto/`.

   `built` is why the pointer is a three-link layout rather than two: `nix build
   --out-link` **refuses** to replace a link whose current target is outside the
   store, and `current -> pinned` is exactly that after every rebuild. Building
   onto a dedicated link sidesteps the refusal, and lets `current` be swapped by
   an atomic rename so it is never momentarily dangling.
2. **Every activation re-points `current` at `pinned`,** so `flake.lock` stays
   authoritative and the pointer only runs ahead *between* rebuilds. Making the
   seed conditional (`if [ ! -L current ]`) looks kinder but is a trap: a later
   rebuild bumps `pinned` while `current` stays behind, and the machine silently
   runs stale skills.

`skill sync --build` builds **this flake's** `skills` output at the **locked**
rev — not `github:…/Construct#skills` at HEAD. Standalone would resolve
Construct's own locked nixpkgs (unrealised here: a tarball fetch plus a full
nixpkgs instantiation ahead of a ~3 MB copy), and building HEAD would let the
live tree diverge from the lock-derived vendored copy in `.github/skills/`
without any signal.

`flake.nix` binds `constructSkills` once and hands the **same derivation** to
both `packages.skills` and `spacecraft.construct.package`. That is load-bearing,
not tidiness — `construct` pins its own nixpkgs, this flake overrides it with
`follows`, and HM runs under `useGlobalPkgs` with overlays, so letting each side
build its own yields different store paths for a byte-identical tree and any
pinned-vs-live comparison reports drift forever.

Grok is the exception: `~/.grok/skills` is still a plain store link and still
needs a rebuild. It holds one skill, so the asymmetry is cosmetic.

Agents cache skills at session start — a sync mid-session is invisible until the
harness restarts.

## Adding packages

Add to the appropriate `modules/packages/*.nix` file. Group by category, prefer Rust packages, add a comment with language. Example:

```nix
my-tool                    # Rust -- Description
```

After adding, update `PRD.md` (package inventory section) and `TODO.md` (relevant phase checklist).

## Changing fonts

**These fonts are a deliberate, pinned choice — leave them as configured.** Do **not** swap them out because a skill (e.g. `spacecraft-brand-guidelines`, `spacecraft-theme-factory`) prescribes a different typeface, because the Standard names a brand font, or because some default seems "more on-brand." Only change a font when the **user explicitly asks for that specific font change** — never as a side effect of applying a skill, theme, or brand guideline.

Current values: **UI = Hack Nerd Font**, **terminal = JetBrainsMono Nerd Font**. Both are defined in `modules/theme/fonts.nix`; the terminal font is a one-line edit to `theme.font` in `lib/terminal-theme.nix`.

The full procedure — getting the real fontconfig family with `fc-scan` (the build does NOT catch a wrong family name), the non-generated spots that still need editing by hand, and the verification steps — is in the `changing-fonts` skill (`.claude/skills/changing-fonts/`).

## Changing default applications

Which program handles what is a registry: **one word per role** in `default-apps.nix` at the repo root, with roles and the app catalog in `lib/default-apps.nix` and `users/mj/default-apps.nix` as the only consumer.

**The ROLE owns the MIME list, never the application** — an app's own `MimeType=` line is not a reliable statement of what it can open (constraint #22). **Never hardcode a `.desktop` id, a browser command, or an editor path in a consumer** — thread `steelboreApps` from `specialArgs`/`extraSpecialArgs` instead. Adding a second `xdg.mimeApps` block anywhere is the specific mistake this design replaced: two blocks merge silently until the day both name the same type, which is an eval-time conflict.

The `app` commands, the role list, and how to add an app via `apps/<slug>.nix` are in the `default-apps` skill (`.claude/skills/default-apps/`).

## Key conventions

- **SPDX headers**: Every `.nix` file starts with `# SPDX-License-Identifier: GPL-3.0-or-later`
- **Rust-first**: Prefer memory-safe alternatives (sudo-rs over sudo, Sequoia over GnuPG, Nushell over bash, etc.)
- **Shells**: User shell = Nushell, root shell = Brush. Bash module stays enabled (PAM requirement) but is not assigned as any user's login shell.
- **Default terminal**: Alacritty under both Niri (`Mod+Return`, set in `users/mj/home.nix`) and LeftWM (`Mod+Return` + scratchpad, in `modules/desktops/leftwm.nix`). LeftWM additionally *requires* alacritty over rio because rio's wgpu backend renders blank under startx-spawned Xorg (rationale in `modules/desktops/leftwm.nix`). Rio is still installed/themed but no longer the default spawn.
- **Default editor**: msedit (`EDITOR`/`VISUAL` in home.nix)
- **Terminal configs**: All 15 terminals get Steelbore-themed system-level configs in `/etc/` with Nushell as shell
- **ISO 8601**: All date/time displays use `%Y-%m-%d %H:%M:%S` 24h format
- **Niri binds**: primary binds get `hotkey-overlay-title="..."` so they appear in `show-hotkey-overlay`; silent aliases (vim moves, mouse wheel, individual workspace 2-5 numbers) omit the title to keep the overlay readable.
- **`unstablePkgs` for always-latest / unstable-only packages**: `flake.nix` re-instantiates `nixpkgs-unstable` with `config.allowUnfree = true` and threads it into modules and HM via `specialArgs`/`extraSpecialArgs`. Active uses: `uv` (development.nix), `steam-run` (system.nix), `code-cursor-fhs` and `kiro-fhs` (editors.nix). Reach for `unstablePkgs.<name>` whenever a package is unstable-only on 26.05 or whenever stable's version lags meaningfully behind upstream.
- **`home.packages` for user-level packages**: Declared at the top of `users/mj/home.nix` (after `home.stateVersion`), always using `with unstablePkgs;`. Currently hosts the Rust toolchain: `rustup` + cargo subcommands (`cargo-update`, `cargo-watch`, `cargo-nextest`, `cargo-audit`, `sccache`, `cargo-expand`). Use this instead of `environment.systemPackages` for packages that are user-specific rather than system-wide.
- **PATH in home.nix**: Do **not** use `home.sessionPath` — it always prepends, causing user-local bins to shadow Nix-store ones. The out-of-band bin dirs are single-sourced in the `outOfBandDirs` list in `users/mj/home.nix` (let block) and rendered into all three managed shells (bash via `posixPathAppend`, Nushell via `nuPathAppend`, Ion via `posixPathAppend`). **Adding a new out-of-band CLI bin dir = one edit to `outOfBandDirs`.** Current dirs: `~/.local/bin`, `~/.cargo/bin`, `~/.kimi-code/bin`, `~/.npm-packages/bin`, `~/.opencode/bin`, `~/.kilo/bin`, `~/.mimocode/bin`, `~/.local/lib/qwen-code/bin`.

## Security

| Layer | Implementation |
|-------|---------------|
| Privilege escalation | `sudo-rs` (Rust), `execWheelOnly = true`. Standard `sudo` (C) is disabled. |
| GUI auth | `polkit` |
| PGP / signing | Sequoia PGP stack (Rust) — `sequoia-sq`, `sequoia-chameleon-gnupg`, etc. |
| SSH agent | `gitway-agent` owns `$SSH_AUTH_SOCK` at `${XDG_RUNTIME_DIR}/gitway-agent.sock`. `programs.ssh.startAgent` must stay `false` to avoid racing. `openssh_hpn` remains installed for general SSH workflows. |
| DNS | `systemd-resolved` with DoT + DNSSEC enforced. Cloudflare malware-blocking primary (`1.1.1.2`), plain Cloudflare fallback (`1.1.1.1`). |
| Screen lock PAM | `security.pam.services.gtklock = {}` is required — packages shipping `etc/pam.d/<service>` are invisible to PAM without explicit declaration. |
| Secure Boot | `sbctl` (Rust) installed; not yet enrolled. |
| Encryption | `age`, `rage` (Rust), `sops` |
| Secrets manager | `rapg` (local path-flake) for local-first secrets |

**Security bug reporting:** do not open public issues. Email
`Mohamed.Hammad@SpacecraftSoftware.org`. Default coordinated-disclosure window is
90 days from acknowledgment.

## Known constraints

1. **bash cannot be replaced via overlay** -- `pkgs.bash` is used by stdenv for building every derivation. Overriding it creates an infinite recursion. Workaround: exclude from login shells, assign Nushell/Brush instead.
2. **`programs.bash.enable` must stay true** -- Disabling it breaks PAM builds (`userdel.pam`). NixOS activation scripts depend on the bash module.
3. **task-master-ai** -- npm build is broken in nixpkgs and unfixable via overlay. Upstream's `package-lock.json` omits the platform-specific optionalDependencies of `@biomejs/biome` (devDep) and `esbuild` (workspace devDep). `npm ci` validates the lockfile against package.json before any `--omit=optional` or fetcher-v2 logic kicks in, so it always fails. Workaround: `modules/packages/ai.nix` ships a `task-master` shell wrapper that runs `npx -y --package=task-master-ai task-master "$@"` against `pkgs.nodejs`. First invocation populates `~/.npm/_npx`; later ones are near-instant. The nixpkgs `task-master-ai` line stays commented out.
4. **Out-of-band CLIs: claude-code, grok-cli, mimocode, qwen-code** -- All installed outside Nix and self-updating. `claude-code` and `grok-cli` live in `~/.local/bin/`; `mimocode` in `~/.mimocode/bin/`; `qwen-code` binary in `~/.local/lib/qwen-code/bin/` (with a thin wrapper at `~/.local/bin/qwen`). The `claude-code` entry in `modules/packages/ai.nix` stays commented out; `unstablePkgs.claude-code` is the re-enable path. Don't move these into Nix without a concrete reason — their release cadence outpaces nixpkgs-unstable pickup.
5. **Stable/unstable package-name splits** -- Some packages were promoted from a sub-attr to top-level on unstable while still living under the old path on the previous stable. Now that stable is 26.05, several of these splits no longer apply — but the `or`-fallback idiom remains in the tree as defence in depth. Examples: `(pkgs.xfce4-terminal or pkgs.xfce.xfce4-terminal)`, `(pkgs.xinit or pkgs.xorg.xinit)`. The `swww` → `awww` rename also changed binary names, so `wallpaperPkg = pkgs.awww or pkgs.swww;` is paired with `wallpaperBin = if pkgs ? awww then "awww" else "swww";` and spawn-at-startup uses `${wallpaperPkg}/bin/${wallpaperBin}-daemon`. Audit and simplify as channels converge; otherwise leave the fallback in place. New deprecations from a stable→unstable promotion should follow the same pattern.
6. **`useFetchCargoVendor` warnings** -- Come from upstream COSMIC packages. Harmless, cannot be suppressed from user config.
7. **External flakes are threaded via `specialArgs` / `extraSpecialArgs`** -- `gitway` (`github:Spacecraft-Software/Gitway`, tracks `main`) is the canonical example. Add the input in `flake.nix`, append it to the `outputs = { ... }` arg list, and inject it into both `specialArgs = { inherit steelborePalette gitway ...; }` and `home-manager.extraSpecialArgs = { inherit steelborePalette gitway ...; }` in `mkBravais`. Modules that consume it accept it in their function signature (e.g., `{ config, lib, pkgs, gitway, ... }:`) and reference its package as `gitway.packages.${pkgs.stdenv.hostPlatform.system}.default`. Do this for any future flake-input-derived package -- do NOT use overlays for it.
8. **`programs.ssh.startAgent` must stay `false`** -- `gitway-agent` (Home Manager service) owns `$SSH_AUTH_SOCK` at `${XDG_RUNTIME_DIR}/gitway-agent.sock` and conflicts with the system `ssh-agent.service`. Re-enabling `programs.ssh.startAgent` would race gitway-agent for the socket. `openssh_hpn` is still installed for general-purpose `ssh`/`scp`/`sftp`/`rsync -e ssh` against non-GitHub hosts -- those tools talk to `gitway-agent` over the OpenSSH agent wire protocol transparently.
9. **Package PAM files don't auto-install** -- Packages that ship `etc/pam.d/<service>` in their Nix store path (gtklock, swaylock, etc.) aren't visible to PAM until declared via `security.pam.services.<service> = {};`. Without the declaration the service is unknown to PAM and authentication fails silently (any password rejected). Declare in `modules/core/security.nix`.
10. **Path-input NAR hash mismatch (`rapg`)** -- `rapg` is the only remaining path-flake input (wrapper at `flakes/rapg/`), content-addressed in `flake.lock`. If its source tree changes, `nixos-rebuild` fails with `error: NAR hash mismatch in input 'path:...'`. Fix: `sudo nix flake update rapg` (or `nix flake update rapg` if your daemon allows). The five local Rust-app path inputs that used to live here (`loran`, `doas-rs`, `reel`, `rget`, `whatshell`) were removed — `pkgs.doas` (upstream C doas) covers the doas case.
11. **Rio close-button hangs at 100% CPU on Wayland** -- Upstream bug [raphamorim/rio#1589](https://github.com/raphamorim/rio/issues/1589), present since v0.4, still open in v0.4.5 (both stable and unstable). Switching channels won't help. Workaround: type `exit` to close Rio — that exits via the shell and works cleanly. Clicking the X or using a WM close keybind triggers the broken winit path. **Rio's font must use the Mono variant** (proportional renders icons wider than one cell) with `"Symbols Nerd Font Mono"` extras — enforced automatically by the `rioToml` emitter in `lib/terminal-theme.nix` (`"${theme.font} Mono"`).
12. **`rustup` conflicts with standalone nixpkgs Rust components in buildEnv** -- `rustup` from nixpkgs ships proxy shim binaries for `rustc`, `cargo`, `rustfmt`, `clippy`, `rust-analyzer`, and more. Installing any of these as separate Nix packages alongside `rustup` in the same HM profile causes a `pkgs.buildEnv` collision (exit code 25). Do not add `rustc`, `cargo`, `rustfmt`, `clippy`, or `rust-analyzer` to `home.packages` or `environment.systemPackages` while `rustup` is present. Get the toolchain via `rustup install stable && rustup default stable && rustup component add rust-analyzer` after rebuild instead.
13. **nil LSP tests failing** -- Upstream Nix builtins documentation updates changed docstrings and broke `nil`'s builtins documentation test. Resolved by overriding the `nil` flake input package with `doCheck = false` in `flake.nix`.
14. **chrome-remote-desktop 404** -- Google regularly removes old deb releases from their mirror. Rebuilds fail with 404 unless the version is bumped to the latest using `nu pkgs/update-vendored.nu chrome-remote-desktop`.
15. **opencode-desktop auto-patchelf musl error** -- The deb package contains unused Alpine Linux/Musl native addons (under `node_modules`). Since `autoPatchelfHook` runs on all libraries recursively, builds fail on glibc systems unless the `.musl.node` files and `*-musl` folders are explicitly removed in `installPhase`.
16. **Vendored `.deb`/tarball layouts drift silently between upstream releases** -- A version bump can move files the `installPhase` hardcodes, and the failure only appears at build time. claude-desktop 1.24012.11 renamed its desktop entry `claude-desktop.desktop` -> `com.anthropic.Claude.desktop` (reverse-DNS app ID matching `StartupWMClass`, so docks group windows); binary, icons and `Exec=` were unchanged. Prefer globs over hardcoded filenames when the exact name doesn't matter (`install -Dm644 -t $out/share/applications usr/share/applications/*.desktop`) -- but only after grepping that nothing references the file by name.
17. **`nix flake check` is not a usable gate here** -- It builds the full closure of BOTH channels and exceeds 10 minutes. Use the pair that actually covers the ground instead: `nix build .#nixosConfigurations.bravais-thinkpad.config.system.build.toplevel` (stable, real build) plus `nix eval --raw .#nixosConfigurations.bravais-thinkpad-unstable.config.system.build.toplevel.drvPath` (unstable, eval only).
18. **Alpaca must be pointed at the existing Ollama service** -- The `com.jeffser.Alpaca` Flatpak can manage its own bundled Ollama, but `steelbore.services.ollama` already runs one on `127.0.0.1:11434`. Configure Alpaca to use that instance (Preferences -> Instances); two servers compete for the same models and RAM.
19. **AdGuard VPN CLI in TUN mode displaces the encrypted resolver** -- `adguardvpn-cli` opens `/dev/net/tun` and rewrites `/etc/resolv.conf`, which systemd-resolved owns here while running DoT + DNSSEC (`modules/core/dns.nix`). SOCKS mode (`adguardvpn-cli config set-mode SOCKS`) is unprivileged and leaves resolved alone -- prefer it. TUN mode needs `sudo`, or a `security.wrappers` entry granting `cap_net_admin`, because a Nix store path cannot carry file capabilities. Its built-in `update` / `check-update` cannot write to the read-only store; bump via `update-vendored.nu`. Note `adguardhome` (installed, DNS blocker) is a **different product**.
20. **Zellij's in-app Configuration screen does not survive a rebuild** -- `home.activation.zellijConfig` (`users/mj/apps.nix`) re-installs the Nix-rendered `config.kdl` on every activation, so anything zellij persists at runtime is reverted (the displaced file lands in `~/.config/zellij/config.kdl.bak.N`). To keep an in-app change, copy it into `zellijConfigFile`. The keybinds block there is the **Unlock First (non-colliding)** preset -- `Ctrl g` unlocks, single keys then enter modes, `default_mode "locked"` -- held as the *verbatim* `clear-defaults=true` dump zellij's Configuration plugin emits: zellij has no `keybinds preset "..."` directive and `zellij setup --dump-config` only emits the *Default* preset, so re-copy from the plugin's output rather than hand-patching individual binds. `clear-defaults=true` also means new upstream default binds never appear until the block is re-dumped. Validate a rendered config with `ZELLIJ_CONFIG_FILE=<store path> zellij setup --check` (expect "[CONFIG FILE]: Well defined.").

21. **`services.displayManager.defaultSession` must stay pinned** -- the five desktops are enabled at once, and upstream modules claim this option at equal priority: `plasma6.nix` sets `mkDefault "plasma"`, and `niri.nix` on nixos-unstable added `mkDefault "niri"`. Two `mkDefault`s with different values collide ("conflicting definition values") and fail evaluation on the unstable channel. `modules/login/default.nix` settles it with a *plain* definition (`= "niri"`, priority 100 > mkDefault's 1000 -- no `mkForce` needed). The option is inert here (greetd/tuigreet reads `--sessions`, and `--remember-session` wins for a returning user): pinning it left the stable `toplevel` store path byte-identical. Expect more of these as desktop modules gain opinions; the fix is always a plain definition, not `mkForce`.

22. **An empty file is `application/x-zerosize`, and a `text/plain` default does not cascade to it** -- `x-zerosize` is not a subclass of `text/plain` (check `share/mime/subclasses`; it has no entry), so binding `text/plain` leaves it unhandled. This is exactly what a file manager's "New file" creates, which is how COSMIC Files opened *gedit* while `text/plain` pointed at cosmic-edit: `com.system76.CosmicEdit.desktop` declares `MimeType=text/plain;` alone, `org.gnome.gedit.desktop` declares `text/plain;application/x-zerosize;`, and the unbound type fell through to desktop-entry cache ordering. The general lesson is that **an app's own `MimeType=` line is not a reliable statement of what it can open** -- so `lib/default-apps.nix` gives every handler *role* the full MIME list and binds it wholesale to whichever app fills the role. Diagnose with `gio info -a standard::content-type <file>` (`xdg-mime query filetype` reports `text/plain` for an empty file and will mislead you) and `gio mime <type>`. Adding a text format = one line in the role's list, never in a consumer.

23. **Engram's `--db` default is a bare RELATIVE path, and every MCP binary is resolved by bare name** -- `engram --db` defaults to the string `engram.db` (no XDG fallback), so any invocation without `--db` silently creates a NEW, empty SQLite store in the current directory. Two such strays accumulated, and one mattered: the `skill-description-1000` rule that `/spacecraft-software/AGENTS.md` documents as readable via `engram rule list --scope spacecraft-software` lived only in `/spacecraft-software/engram/engram.db`, so the documented command returned nothing from every other directory. Fixed by `ENGRAM_DB` in `users/mj/shell.nix` (pointing at `${config.xdg.dataHome}/engram/engram.db`), *and* an explicit `--db` in `mcp-servers/mcp.toml` -- both, because the env var only reaches login-session descendants while a harness started from a desktop entry or Flatpak may have a pruned environment. Separately: **`mcp.toml` resolves `engram`, `crates-mcp` and `bravais-cli` by bare name on PATH**, so whatever is in the user profile *is* what every MCP host spawns -- which is why all three are Nix-provided (constraint: never let one drift back to `cargo install`). Note `~/.cargo/bin` is APPENDED to PATH (`outOfBandDirs`), so a Nix copy always wins; a leftover cargo build is confusing but not shadowing. Finally, **do not add a compatibility symlink at an old SQLite path** -- SQLite derives the `-wal` name from the path as opened, not the resolved target, so two writers reach the same inode through different WAL files.

24. **Obscura cannot come from nixpkgs, and four things about building it are counter-intuitive** -- `obscura` *is* in nixpkgs-unstable and *is* prebuilt in `cache.nixos.org`, so `unstablePkgs.obscura` looks like the obvious one-line answer. It is not: nixpkgs pins **0.1.10**, which predates the `obscura-render` crate *entirely* -- the crate does not exist in that tree, so there is no `render` feature to enable at any price. Render first ships in **v0.2.0**. Hence the source build in `pkgs/obscura/`, and hence the lost binary cache. The rest, in the order you will hit them: (a) **`pkgs.deno.librusty_v8` is the wrong V8** -- deno tracks 147.4.0 while Obscura's lock pins `deno_core` 0.350 -> v8 **137.3.0**, so `pkgs/obscura/librusty_v8.nix` pins its own; check the lock before "simplifying" it away. (b) The tree is a **virtual workspace**, so `cargo` rejects `--features` unless a package is selected -- `cargoBuildFlags = [ "-p" "obscura-cli" "--bins" ]` is load-bearing, not an optimisation, and `--bins` is what keeps `obscura-worker` (required by the parallel `scrape`) alongside `obscura`. (c) **`stealth` needs `git` at build time**: `btls-sys` runs `git init` + `git apply` over the BoringSSL copy vendored in its own crate (nothing is cloned; BoringSSL is fully vendored, and Go is *not* needed because `deps/boringssl/gen` ships pre-generated sources). `BORING_BSSL_ASSUME_PATCHED=1` silences the failure but **skips `boring-pq.patch`**, so the ClientHello loses the post-quantum key exchange modern Chrome offers -- which is precisely the fingerprint `stealth` exists to reproduce. Supply `git`; do not take the shortcut. (d) **`obscura --version` reports `0.1.0` at every tag** -- upstream never bumped `workspace.package.version`, so the crate string and the release tag disagree. Do not "fix" the derivation's `version` to match the binary, and do not add a `testers.testVersion` check expecting them to agree.

25. **The bar's hardware indicators come from one daemon, and FnLock is not among them** -- `pkgs/steelbore-beacon` blocks on three kernel event sources and writes one JSON line per change, which both bars read with a single `deflisten`. The three sources, and why each is the one it is: (a) **PulseAudio** via `libpulse-binding`, resolving the default sink/source by name on every event rather than caching an index, because plugging in a headset changes which device is default; (b) **`EV_LED` from `/dev/input/event*`** for Caps/Num Lock -- the kernel emits it whichever process toggled the lock, so it is correct under X11 and Wayland alike, unlike `xset q`, which reports *Xwayland's* keyboard under Niri and will quietly lie. LED-class sysfs (`/sys/class/leds/input0::capslock/brightness`) is fine to *read* for the initial value but does **not** support `poll()` -- the LED core never calls `sysfs_notify` -- so it cannot be an event source; (c) **`POLLPRI` on `/sys/class/backlight/intel_backlight/actual_brightness`**, which the backlight core *does* `sysfs_notify`. Watch `actual_brightness`, not `brightness` (requested vs. achieved), and re-`read()` the attribute to completion each wakeup or `poll` spins forever. **FnLock is deliberately absent and must not be added**: this T490s exposes no `fn_lock` attribute anywhere under `/sys`, and no input device advertises `KEY_FN_ESC` -- the EC swallows Fn+Esc entirely. Any indicator would be inference that desynchronizes after the first resume, which is worse than no indicator. Reading `mj`'s membership in the `input` group is what makes (b) work rootless; `video` covers the backlight.

26. **A `/* */` comment in the Eww SCSS breaks the bar if it contains any non-ASCII byte** -- SCSS strips `//` line comments but *preserves* `/* */` block comments into the CSS it hands GTK, and GTK's CSS parser rejects any non-ASCII byte inside one with the thoroughly misleading `error: unknown @ rule`. A single `§` or em dash in a block comment is enough, and nothing in `nixos-rebuild` catches it -- the config evaluates and builds fine, the bar just renders unstyled. **Use `//` for every comment in `eww.scss`**, which is what the surrounding blocks already do. Two related traps in the same file: `:visible beacon.caps` looks for a variable *literally named* `beacon.caps` and errors, so field access must be wrapped as `:visible {beacon.caps}`; and `max-width` (already in the LeftWM `.window-title` rule) is not a GTK CSS property and logs an error at every start -- pre-existing, harmless, and not something a new change introduced. Validate a rendered pair before shipping: `nix eval --raw '.#nixosConfigurations.bravais-thinkpad.config.home-manager.users.mj.xdg.configFile."eww/eww.yuck".text'` into a scratch dir, then `eww --config <dir> --no-daemonize daemon` and read the log. Remember there are **two** bars to keep in step -- `users/mj/eww.nix` (Niri) and `modules/desktops/leftwm.nix` (LeftWM) -- with no shared fragment between them. Finally, **do not put an icon and its value in one interpolated string and reason about the gap from the `nf-md-*` prefix** -- these glyphs do not share metrics. Measured in JetBrainsMono Nerd Font (advance 600 for all): `md-battery` RSB **+50** (ink inside its advance, hence no literal space), but `md-volume_high` **-150**, `md-brightness_5` **-342** and `md-numeric` **-318** all overflow, while `md-volume_medium` **+19** and `md-volume_low` **+112** do not. Volume therefore *switches* between overflowing and not as the level crosses 66% and 33%, so no fixed choice of space/no-space is right in every state -- with a space the gap visibly jumps, without one the ink runs into the first digit. The fix is to stop letting glyph metrics set the gap at all: put the icon and the value in **separate labels** inside a `(box :spacing N)`, which is measured in pixels. Measure before assuming, with `fontTools`: `TTFont(f)['hmtx'][glyphname]` for the advance and `glyf[glyphname].xMax` for the ink, RSB = advance - xMax.

27. **`nix flake update antigravity-nix` cannot make Antigravity newer** -- the Antigravity version is a `version` + `hash` pair inside *that input's* `artifacts/versions.json`, which is the `update-vendored.nu` problem one repo upstream: a flake update moves the input, never the pins inside it. Between 2026-07-21 and 2026-08-19 the input was already at `master` HEAD on every rebuild, so the update was a genuine no-op while the IDE sat four releases behind (2.1.1 vs 2.5.5). Nothing in a rebuild said so. The upstream cause was `update.yml`'s **`Build Antigravity SDK` step being a hard gate**: `google-antigravity` 0.1.12 ships protobuf gencode 7.35.0 against a nixpkgs runtime of 6.33.0, protobuf refuses a runtime older than its gencode, and the workflow died before `Create Pull Request` -- an optional pre-1.0 Python package gating three stable products. Upstream now builds IDE/Desktop/CLI as the hard gate and reports the SDK as a soft check. `rebuild` additionally runs an `antigravity-status` probe after the flake update, comparing the lock's pinned IDE version against Google's releases endpoint and warning (never failing -- a brief Cloud Run outage must not abort a rebuild) when they diverge. **Do not "fix" a stale Antigravity by editing anything in this repo**; the pin lives in `github:UnbreakableMJ/antigravity-nix`, and the fix is `./scripts/update-version.sh` there plus a PR to `master`. **`https://antigravity.google/download` is the source of truth -- check it every time antigravity-nix is touched.** Its Cloud Run `/releases` endpoint is not trustworthy: it served a 2026-05-19 Desktop build for months while the page linked 2.3.1 (2026-07-16) then 2.8.1 (2026-08-13), and trusting it once downgraded the pin by two releases. Read the page carefully -- an artifact URL (`storage.googleapis.com/...`, `edgedl...`) is evidence, a `v1.2.3` link to `/changelog` is marketing copy that lags; the CLI shows `v1.1.14` as a changelog link while linking no CLI artifact at all, and its endpoint's 1.1.15 is genuinely a day newer. **`Last-Modified` on the artifact is the only signal that orders builds**, and the execution id is emphatically not one -- Desktop `2.0.0-6324554176528384` carries a higher id than `2.3.1-5358163105546240` and was built two months earlier. Fetch the page with `curl --compressed` or the body is binary and every grep silently finds nothing. Two traps in that script: its `#!/usr/bin/env nix-shell` shebang is what supplies `jq`, so running it as `bash scripts/check-version.sh` reports `Current version: unknown` and four API errors that look like dead endpoints and are not; and its `is_downgrade` guard deliberately refuses the Desktop app's releases endpoint when that reports older than the pin, which is normal and not a failure.

28. **`/` is a 16 GiB tmpfs here, so `df -h /` never shows the disk that fills** -- `/nix`, `/var`, `/home`, `/spacecraft-software` and `/mnt` are all bind-mounted subtrees of `/dev/nvme0n1p5` (203 GiB), while `/` is memory. Any free-space check aimed at `/` reports ~16 GiB free forever, no matter how full the real partition is. This silently defeated two checks at once: `rebuild`'s "disk before/after" banners and `flatpak-status`'s `free` field, whose whole purpose is answering "is there room for a 4.4 GB Flatpak update". Both now target `/nix` and `/var/lib/flatpak`. **Aim any new disk check at a real path, never `/`** -- and when accounting for a full partition, measure every subtree (`du -xsh /nix /var /home ...`) rather than subtracting one from `df`: the bind-mount layout makes "everything I did not measure must be X" a very easy and very wrong inference. Measured 2026-08-19: `/home` 84 GiB, `/nix` 38 GiB, `/var` 28 GiB -- ordinary usage, not a leak. Separately and genuinely: `/mnt/nix-tmp` is meant to be a loop image on the removable Expansion drive, and with that drive unplugged `modules/core/nix-tmp.nix` falls back to the system disk "transparently" -- but a build killed part-way leaves its scratch tree behind and **`nix-collect-garbage` does not touch the builder TMPDIR**, so the rebuild's own GC reports success without clearing it. Thirteen such orphans dating to 2026-06-01 were found and removed; they were small, so this is a slow leak to bound rather than a disk-filling emergency. The tmpfiles rule now carries a `10d` age instead of `-` for exactly that reason.

29. **Only niri can bind a mouse button, so side-button workspace nav is an evdev remap everywhere else -- and it MUST NOT be scoped to `graphical-session.target`** -- Mutter's keybinding schemas, KWin's shortcuts and cosmic's RON bindings all take keyboard accelerators only; no nixpkgs GNOME extension binds side buttons (`gnomeExtensions.panel-scroll` is scroll-on-the-panel only), and under Wayland an extension cannot reliably grab pointer buttons over an application window. `modules/desktops/mouse-workspace-nav.nix` therefore remaps `BTN_SIDE`/`BTN_EXTRA` **below the compositor** with `xremap` (Rust) into **Super+Ctrl+Left/Right**. That combo is not arbitrary: it is already the shipped default for this exact action in **Plasma** (`Switch One Desktop to the Left = Meta+Ctrl+Left`) and **COSMIC** (`(modifiers: [Super, Ctrl], key: "Left"): PreviousWorkspace`, in cosmic-comp's own `Shortcuts/v1/defaults`), so only GNOME needed a binding added (`users/mj/desktop-theme.nix`, appended to the stock list rather than replacing it). Emitting GNOME's `Ctrl+Alt+Left/Right` instead would have meant editing Plasma *and* COSMIC -- do not "simplify" it back without re-checking those two defaults. **Niri is deliberately excluded**: it binds `MouseBack`/`MouseForward` natively, and since xremap `EVIOCGRAB`s the device and re-emits, a unit on `graphical-session.target` would consume the buttons before niri saw them and silently kill those binds. The unit is therefore `wantedBy` exactly `gnome-session-initialized.target`, `cosmic-session.target` and `plasma-core.target` -- **never `graphical-session.target`**. **LeftWM is the other exception**: it is startx-based with no systemd graphical session at all, so no unit can fire there; its theme `up` hook starts the same command (exposed as the read-only `steelbore.desktops.mouseWorkspaceNav.command` option so the two cannot drift) and `down` kills it by pidfile, without which a finished leftwm session leaves xremap holding a grab on the mouse. Three further non-obvious points: while the remapper runs, **all** keyboard and mouse input is proxied through it (the kernel releases grabs on process death, `Restart=on-failure` covers a crash); `--watch=device` is required or a Bluetooth mouse that reconnects after suspend is never picked up; and plain `pkgs.xremap` is the *wlroots* variant, which is correct for all four desktops because the variant selects only the lazily-constructed window-detection client, which a keymap without `application:` conditions never consults. The `uinput` group in `users/mj/default.nix` is what lets it create its virtual device -- `input` covers only *reading* the real ones -- and a group change needs a re-login, not just a rebuild.

## Vendored upstream binaries (`pkgs/update-vendored.nu`)

Ten packages pin an upstream `version` + `hash` that `nix flake update` cannot touch: `claude-desktop`, `chrome-remote-desktop`, `ollama`, `goose-desktop`, `opencode-desktop`, `codex-desktop`, `github-copilot-app`, `adguardvpn-cli`, `obscura` (all in `pkgs/`), and `browseros` (inline in `modules/packages/browsers.nix`).

`codex-desktop` is the odd one out: OpenAI publishes **no versioned URL**, only `…/deb/latest/`. The pin therefore breaks whenever they ship a build, and the pinned artifact cannot be refetched once replaced — unlike every other entry, whose exact version stays fetchable. Its updater keys off the blob **ETag** from a HEAD request rather than a release API, so `--check` stays free instead of downloading 378 MB, and reads the version out of the `.deb` control file only once something has actually changed.

They are **declarative, not self-updating — never bump one by hand**; run `nu pkgs/update-vendored.nu` (`--check` to report only). **Never restate a pinned version in prose** — point at the package file instead; the ollama 0.31.1 → 0.32.5 bump orphaned five hardcoded copies across modules and docs.

`skyroads` (`pkgs/skyroads/`) also pins a `version` + `hash` but is deliberately **outside** this set and outside `update-vendored.nu`: the artifact has been frozen since the 1990s and Bluemoon publishes no release feed, so there is nothing for a bumper to poll. Do not "fix" the omission by adding it.

Per-package failure isolation, the `up-github` tag options, and why `obscura` needs its own bumper with two hashes are in the `vendored-binaries` skill (`.claude/skills/vendored-binaries/`).

## Documentation maintenance

When making changes, keep these in sync:

- **PRD.md** — product requirements, architecture details, package inventories
- **TODO.md** — implementation checklist with `[✓]` markers, known issues, phase progress table

Use `[✓]` (not `[x]`) for completed items in TODO.md.

This file is the single agent-facing source of truth (Standard §5.7). There is no
second copy to keep in sync — `CLAUDE.md` imports this file rather than restating
it. Both are tracked; `PRD.md` and `TODO.md` are tracked as well.

## License and contribution policy

- **License:** GPL-3.0-or-later
- **Project posture:** personal hobby project. No warranty, no liability. PR acceptance is at the maintainer's sole discretion.
- **Before opening a PR:** open an issue first for non-trivial changes. Test with a real `toplevel` build (see Build and test commands) — not `nix flake check`, which times out — plus `nixos-rebuild dry-build --flake .#bravais-thinkpad-unstable --show-trace`.
- **Commits:** Conventional Commits prefix (`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`), subject ≤ 72 chars, imperative mood, body wrapped at 72 columns. **Signed & Verified — mandatory** (Standard §6.3): Ed25519 SSH commit signing (`commit.gpgsign=true`, `gpg.format=ssh`, signing key registered as a *Signing* key on GitHub). Do **not** use `git commit -s` (DCO sign-off) — that is a different mechanism and does not satisfy this requirement.
- **Forking:** encouraged under GPL-3.0-or-later when goals diverge.

---

*Maintainer:* Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
*License:* GPL-3.0-or-later
*Project:* Bravais — a Steelbore OS NixOS distribution
