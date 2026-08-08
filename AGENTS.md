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

`nix flake update construct` is equivalent to `skills-sync` — updating `construct` also picks up any new skills before the rebuild applies them.

The whole sequence above is now wrapped in a Nushell `def rebuild` command (defined in `users/mj/home.nix`, after `skills-ship`), so the user can just type `rebuild`. It differs from the raw chain in three deliberate ways: GC keeps a week of generations (`--delete-older-than 7d`, not `-d`); the update list also bumps `nixpkgs-unstable` + `home-manager-unstable` so `unstablePkgs` never lags stable (plan 5.2), and a monthly nag reminds to run `nu pkgs/update-vendored.nu --check` (vendored-binary bumps, plan 5.1); the `/tmp` wipe is dropped (builds use `/mnt/nix-tmp`, and `rm -r /tmp/*` can kill an X11/LeftWM session); and the `/etc/nixos` step is a lean `rsync -av --delete --delete-excluded` mirror (tracks deletions, prunes stale files; excludes `.git/`, `result`, `.claude/`) that runs only after a successful switch. Flags: `--dry` (dry-build, no cleanup/mirror), `--no-update`, `--no-gc`, `--trace` (adds `--show-trace --verbose`).

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
modules/desktops/          # gnome, cosmic, plasma, niri, leftwm (+ shared.nix dunst, assertions.nix guards)
modules/hardware/          # steelbore.hardware.* vendor toggles: bluetooth, fingerprint,
                           #   intel (kvm-intel, microcode), audio-led daemon
modules/platform/          # steelbore.platform.x86_64: marchLevel + compiler/linker flags (ISA, vendor-neutral)
modules/login/             # greetd + tuigreet + shell sessions (single default.nix)
modules/services/          # steelbore.services.*: podman (container runtime),
                           #   ollama, chrome-remote-desktop
modules/compat/            # steelbore.compat.*: appimage (binfmt auto-run)
modules/packages/          # 12 opt-in bundles: ai, browsers, development, editors,
                           #   flatpak, homebrew, multimedia, networking,
                           #   productivity, security, system, terminals
users/mj/default.nix       # System user definition (users.users.${primaryUser})
users/mj/home.nix          # HM core: identity + imports (~90 lines; Phase D split)
users/mj/{git,shell,terminals,niri,desktop-theme,apps}.nix  # one-concern HM modules
users/mj/default-apps.nix  # THE ONLY xdg.mimeApps block + the FileManager1 D-Bus shadow
pkgs/default.nix           # callPackage index; also the flake's packages.* output
pkgs/                      # In-tree packages — `pkgs/default.nix` is the authoritative index:
                           #   steelbore-audio-led, steelbore-niri-unmax, claude-desktop,
                           #   chrome-remote-desktop, ollama, github-copilot-app, bravais-mcp,
                           #   opencode-desktop, goose-desktop, adguardvpn-cli,
                           #   crates-mcp, obscura
                           # Each is also a flake output: `nix build .#<name>`
pkgs/update-vendored.nu    # Bumps the 9 version+hash-pinned upstream packages (see below)
pkgs/sync-skills.nu        # Skill sync helper
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

All opt-in modules follow the `steelbore.*` namespace:

```nix
{ config, lib, pkgs, ... }:
{
  options.steelbore.desktops.niri = {
    enable = lib.mkEnableOption "Niri scrolling tiling compositor (Wayland)";
  };

  config = lib.mkIf config.steelbore.desktops.niri.enable {
    # Implementation
  };
}
```

`lib/` holds `palette.nix` (§11 palette family: slug → role tokens + ANSI map +
format converters), `default-apps.nix` (handler roles → MIME lists, app catalog,
resolver) and `terminal-theme.nix` (terminal theme record + emitters); the former
`lib/default.nix` helper was removed for simple cases.

**Host toggles** live in `hosts/thinkpad/default.nix` under the `steelbore`
attribute set. All 12 package bundles and all 5 desktop environments are enabled
there for the primary host.

## First-time bootstrap

Skills are installed from the `construct` flake input (`github:Spacecraft-Software/Construct`)
via `construct.homeManagerModules.default` (enabled as `spacecraft.construct` in `home.nix`).
HM copies all cross-platform skills into `~/.agents/skills/` (Nix store path) and symlinks
`~/.agent/skills`, `~/.ai/skills`, `~/.aichat/skills`, `~/.claude/skills`, `~/.codex/skills`,
`~/.copilot/skills`, `~/.opencode/skills` to it. `.gemini` is intentionally omitted —
Gemini reads `~/.agents/` directly.

No manual clone of `/spacecraft-software/construct` is needed for skill installation —
everything comes from the flake. The local clone at `/spacecraft-software/construct` is
only needed for skill authoring.

To pull skill updates: run `skills-sync` (Nushell command in `home.nix`) to update the
`construct` entry in `flake.lock`, then rebuild to apply. Unlike the old approach,
skills are frozen at flake-lock time — no mid-session drift.

## Adding packages

Add to the appropriate `modules/packages/*.nix` file. Group by category, prefer Rust packages, add a comment with language. Example:

```nix
my-tool                    # Rust -- Description
```

After adding, update `PRD.md` (package inventory section) and `TODO.md` (relevant phase checklist).

## Changing fonts

**These fonts are a deliberate, pinned choice — leave them as configured.** Do **not** swap them out because a skill (e.g. `spacecraft-brand-guidelines`, `spacecraft-theme-factory`) prescribes a different typeface, because the Standard names a brand font, or because some default seems "more on-brand." The current families below are the intended values. Only change a font when the **user explicitly asks for that specific font change** — never as a side effect of applying a skill, theme, or brand guideline.

There are two font *roles*, both defined in `modules/theme/fonts.nix`:

- **Main / UI font** — the `sansSerif` + `serif` fontconfig defaults (general UI, GTK `font-name`/`document-font-name`). Current value: **Hack Nerd Font**.
- **Terminal / code font** — the `monospace` fontconfig default + every terminal app config. Current value: **JetBrains Mono Nerd Font** (`JetBrainsMono Nerd Font`, one word). Icon fallback: **CaskaydiaMono Nerd Font** (monospace), **Symbols Nerd Font Mono** (Rio).

`fonts.nix` sets the fontconfig defaults. Since the Phase C terminal-theme
generator, **every terminal emulator config derives its font from
`theme.font` in `lib/terminal-theme.nix`** (foot, xterm, xfce, ghostty, warp,
konsole, wezterm, cosmic-term, waveterm, alacritty, rio — rio automatically
gets the `…Mono` variant, constraint #11). A terminal-font change is now a
ONE-LINE edit there. Family strings still appear by hand in the NON-generated
spots: `modules/theme/fonts.nix` (packages + fontconfig), the **eww** scss +
**ironbar** css (bar fonts), **halloy**/**tiny** configs, the **dconf**
`font-name`/`monospace-font-name` keys, `gtk.font`, Starship has none, and
`modules/desktops/shared.nix` (dunst) for the UI font (polybar was removed
in Phase E — eww is the bar on both WMs). Grep those when changing a family.

**Procedure (the way that actually works):**

1. **Get the exact family name — do not guess.** The fontconfig family is *not* the nixpkgs attr. Build the package and read it:
   ```sh
   p=$(nix build --no-link --print-out-paths nixpkgs#nerd-fonts.jetbrains-mono)
   fc-scan --format '%{family}\n' "$p" | tr ',' '\n' | sort -u | grep -i jetbrains
   # → "JetBrainsMono Nerd Font", "JetBrainsMono Nerd Font Mono", "JetBrainsMono Nerd Font Propo"
   ```
   Common gotcha: `nerd-fonts.jetbrains-mono` → family `JetBrainsMono Nerd Font` (no space), `nerd-fonts.hack` → `Hack Nerd Font`.

2. **Terminal font = one line.** Edit `theme.font` in `lib/terminal-theme.nix`
   — every generated terminal config (foot, xterm, xfce, ghostty, konsole,
   wezterm, waveterm, alacritty, rio, ptyxis palette consumers) follows
   automatically, and Rio keeps its `"${theme.font} Mono"` variant + the
   `Symbols Nerd Font Mono` extras by construction (constraint #11).
   Then stem-replace only the NON-generated spots (bars, IRC clients, dconf
   font-name keys, gtk font, dunst UI font):
   ```sh
   sd 'JetBrainsMono' 'NewFamily' users/mj/home.nix   # eww/ironbar/halloy/dconf hits only
   ```
   and edit the `nerd-fonts.*` attrs + `defaultFonts` in `fonts.nix` by hand.

3. **UI font** (`Hack Nerd Font`): edit `fonts.nix` defaults, the dconf
   `font-name`/`document-font-name` keys and `gtk.font` in `home.nix`, and the
   dunst (`modules/desktops/shared.nix`) font.

4. **Verify** before declaring done:
   ```sh
   git add -A
   nix build --no-link --print-out-paths '.#nixosConfigurations.bravais-thinkpad.config.system.build.toplevel'   # must evaluate+build
   nix-store -qR <result> | grep -i nerd-fonts                                                              # new fonts in, old fonts out
   ```
   The build does **not** catch a wrong family name (it's just a string) — only step 1's `fc-scan` does.

5. Update `PRD.md` §4.3 (Typography) and `TODO.md` `fonts.nix` checklist to the new families.

## Changing default applications

Which program handles what is a registry, shaped exactly like the theme system.
The active choice is **one word per role** in **`default-apps.nix`** at the repo
root; the role→MIME lists and the app catalog live in `lib/default-apps.nix`;
`users/mj/default-apps.nix` is the only consumer.

```sh
app list                  # every role and its active app
app show editor           # the resolved entry + every MIME type it binds
app candidates editor     # every app that can fill the role
app set editor zed        # rewrite default-apps.nix, then `rebuild`
```

Roles: `editor` (GUI — what double-clicking a text file opens), `browser`,
`fileManager`, `imageViewer`, `termEditor` (`$EDITOR`/`$VISUAL`/`git core.editor`
— binds no MIME types). `editor` and `termEditor` are deliberately separate.

**The ROLE owns the MIME list, never the application.** An app's own `MimeType=`
line is not a reliable statement of what it can open (see constraint #22), so
whichever app fills a role inherits the role's complete set. A catalog entry may
set `mimeTypes` to *narrow* the list when it genuinely cannot open everything
(`loupe`, `feh`), but never to widen it — add the type to the role instead.

An app that isn't in nixpkgs yet joins via a **drop-in**: `apps/<slug>.nix`,
filename = slug, merged over the built-in catalog and free to shadow it — the
same semantics as `themes/<slug>.nix`. `apps/README.md` documents every field.
A drop-in that sets `package` installs itself when active, so `app set` is the
only edit needed.

Never hardcode a `.desktop` id, a browser command, or an editor path in a
consumer — thread `steelboreApps` from `specialArgs`/`extraSpecialArgs` and read
`steelboreApps.roles.<role>`. Same rule as §11.4 for palette values. Adding a
second `xdg.mimeApps` block anywhere is the specific mistake this replaced: two
blocks merge silently until the day both name the same type, which is an
eval-time conflict.

The `app-registry` flake output (JSON) is what the `app` command reads; it stays
pkgs-free (the `package`/`exec`/`dbusExec` fields are functions of `pkgs` and
never reach it), so `app list` costs one builtins-only evaluation rather than a
system config.

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

## Vendored upstream binaries (`pkgs/update-vendored.nu`)

Nine packages pin an upstream `version` + `hash` that `nix flake update` cannot
touch: `claude-desktop`, `chrome-remote-desktop`, `ollama`, `goose-desktop`,
`opencode-desktop`, `github-copilot-app`, `adguardvpn-cli`, `obscura` (all in
`pkgs/`), and `browseros` (inline in `modules/packages/browsers.nix`). They are
**declarative, not self-updating** -- never bump one by hand.

```sh
nu pkgs/update-vendored.nu              # bump all 9 + nix build each
nu pkgs/update-vendored.nu --check      # report only, change nothing
nu pkgs/update-vendored.nu ollama       # single package
```

- **Failures are isolated per package** (fixed 2026-08-04). A build failure yields
  `action: "build failed"`; any other error yields `action: "error: …"`; both are
  re-listed in a summary block after the table. Before that fix, `nix build`
  raising propagated out of the `each` in `main`, so the first broken package
  silently skipped every package after it -- the run merely *looked* finished.
- **A failed build leaves the version/hash rewrite in place on purpose.** The bump
  is nearly always correct and the *packaging* is what needs fixing, so the
  modified file is the starting point. Check `git diff`.
- The script exits **zero** even on failure, because `rebuild`'s monthly `--check`
  nag depends on it. Change that only if it is ever wired into CI.
- `up-github` takes optional `tag_pattern` / `strip_suffix` params for repos whose
  tags carry decoration the version string does not (AdGuardVPNCLI tags
  `v1.7.12-release` for version `1.7.12`).
- **`obscura` is the only member built from SOURCE**, so `up-github` cannot bump it
  and `up-obscura` exists instead. It pins *two* hashes, neither a release asset:
  the `fetchFromGitHub` **unpacked-tree** hash (`prefetch-github-tree`, since
  `nix store prefetch-file` hashes the tarball and has no `--unpack`), and
  `cargoHash`, which no URL yields -- the vendored tree does not exist until cargo
  resolves the lock, so it is discovered by poisoning the hash, building, and
  parsing the `got:` line back out. `pkgs/obscura/librusty_v8.nix` is deliberately
  **not** bumped by the script: that pin tracks Obscura's `deno_core` dependency,
  not its release cadence.
- **Never restate a pinned version in prose.** The ollama 0.31.1 -> 0.32.5 bump
  orphaned five hardcoded copies across modules and docs; they now point at
  `pkgs/ollama/package.nix` as the single source of truth. Same rule as §11.4 for
  palette values.
- `adguardvpn-cli` is the odd one out: upstream ships a **fully static** ELF, so it
  needs no `autoPatchelfHook` and no `buildInputs` -- unlike every other entry,
  which is a `.deb` needing the Electron/Chromium library chase. Its
  `installCheckPhase` runs `--version` under a scratch `HOME` (first run creates a
  data dir) to prove the static claim at build time.

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

## Quick reference

| Task | Command |
|------|---------|
| Build stable config (the gate) | `nix build --no-link '.#nixosConfigurations.bravais-thinkpad.config.system.build.toplevel'` |
| Eval unstable config | `nix eval --raw '.#nixosConfigurations.bravais-thinkpad-unstable.config.system.build.toplevel.drvPath'` |
| Build one in-tree package | `nix build .#<name>` (after `git add -A`) |
| Bump vendored binaries | `nu pkgs/update-vendored.nu` (`--check` to report only) |
| Dry-run default | `nixos-rebuild dry-build --flake .#bravais-thinkpad` |
| Switch to stable | `sudo nixos-rebuild switch --flake .#bravais-thinkpad` |
| Switch to unstable | `sudo nixos-rebuild switch --flake .#bravais-thinkpad-unstable` |
| Update flake inputs | `nix flake update` |
| Fix rapg hash | `nix flake update rapg` |
| GC old generations | `sudo nix-collect-garbage --verbose -d` |
| Show flake outputs | `nix flake show` |

---

*Maintainer:* Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
*License:* GPL-3.0-or-later
*Project:* Bravais — a Steelbore OS NixOS distribution
