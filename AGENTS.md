# AGENTS.md — Bravais (Steelbore OS)

Authoritative agent context (Standard §5.7). Every agent reads this file;
`CLAUDE.md` imports it and adds only Claude-Code-only notes.

## What this is

A flake-based NixOS configuration implementing **The Spacecraft Software Standard** (renamed from "Steelbore Standard" at Standard v1.7). The `mkBravais { host, channel }` function in `flake.nix` generates **per-machine nixosConfigurations**: `bravais-thinkpad` (stable 26.05) and `bravais-thinkpad-unstable` (nixos-unstable), plus a `bravais` alias → stable ThinkPad. The x86-64 march level is pinned inside each machine's host config (the ThinkPad's i7-8665U is x86-64-v3 — no AVX-512), not exploded into a v1–v4 matrix. Adding a machine = drop a `hosts/<machine>/` dir + two output lines in `flake.nix`.

## Build and test commands

```sh
# `nix flake check` builds BOTH channels' full closures and exceeds 10 min —
# not a usable gate. Use the toplevel build + unstable eval (constraint #17).
nix build --no-link '.#nixosConfigurations.bravais-thinkpad.config.system.build.toplevel'
nix eval --raw '.#nixosConfigurations.bravais-thinkpad-unstable.config.system.build.toplevel.drvPath'
nix build --no-link '.#checks.x86_64-linux.reuse-lint' '.#checks.x86_64-linux.niri-config'  # SPDX + niri KDL; seconds
nix build .#<name>                                      # One in-tree pkg (after `git add -A`)
nix flake show                                          # List outputs
nixos-rebuild dry-build --flake .#bravais-thinkpad      # Dry run
sudo nixos-rebuild switch --flake .#bravais-thinkpad    # Apply (stable ThinkPad, v3)
sudo nixos-rebuild switch --flake .#bravais-thinkpad-unstable # Unstable channel
sudo nixos-rebuild switch --flake .#bravais             # Alias → stable ThinkPad
```

## Rebuild

Run as the user, never as root. **`preflight` (Rust, `pkgs/preflight/`) is the supported entry point.** Its sequence: bump the tracked five inputs (`antigravity-nix`, `construct`, `gitway`, `nixpkgs-unstable`, `home-manager-unstable`), GC keeping a week of generations, vacuum the journal, `nixos-rebuild switch --flake .#bravais-thinkpad`, then — only after a successful switch — `rsync --delete` the tree into `/etc/nixos` and start the Flatpak update **detached**, never inline (a full Flatpak refresh measured hours). `preflight --help` / `schema` / `describe` give the flag surface; `preflight disk report --json` is the free-space surface.

The sequence has **three** implementations: `pkgs/preflight/` (supported), `users/mj/rebuild.nu` (the Nushell `rebuild` — one text serving both the `config.nu` `def` and the `rebuild` binary, so it carries its own helpers) and `scripts/rebuild.sh` (POSIX subset for any other shell; `nix run nixpkgs#shellcheck -- -s sh scripts/rebuild.sh` must stay at zero findings). **Change one and change all three.** The two older ones open with a deprecation question that aborts unless answered `y`; `--yes` skips it.

Flags shared by all three: `--dry`, `--no-update`, `--update-all` (bare `nix flake update` over **every** input; conflicts with `--no-update` and `--skills-only`), `--no-gc`, `--trace`, `--skills-only` (bump only `construct`; skip GC, the mirror and the mcpctl probe), `--no-flatpak`. `preflight` only: `--full-update` (alias of `--update-all`, which there also implies `--update-vendored`), `--update-vendored`, `--reclaim`, `--gc-all`, `--journal-days <DAYS>`, `--mcp-deploy`, `--json` / `--format`.

`preflight` deliberately wraps **none** of the tools it drives onto PATH — pinning `vacuum` and `mcpctl` into its closure would freeze them (same reasoning as constraint #23). The raw command chain, each implementation's deliberate differences, the `flatpak-status` / `flatpak-update` / `flatpak-log` commands, the `antigravity-status` probe (constraint #27) and the measured costs behind every flag are in **`docs/rebuild.md`** — read it before changing any of the three.

## Architecture

- **Flake inputs**: declared in `flake.nix`, one comment each. Bump `theme` together with `construct` (both carry the same `steelbore.toml`). No third-party DE flakes.
- **Module namespace**: All opt-in modules use `steelbore.*` with `lib.mkEnableOption`. Toggled in `hosts/common.nix` (shared) and per-machine `hosts/<machine>/default.nix` (hardware toggles + march pin). `hosts/<machine>/default.nix` carries only what is genuinely per-machine (hostName, `steelbore.hardware.*`, CRD, the march pin); every other toggle goes in `hosts/common.nix`.
- **Color palette**: Standard §11 is a *family* of eleven adoptable palettes (Modern, Classic, and nine alternates — `theme list` names them), plus any local ones in `themes/`. `lib/palette.nix` selects one by slug (`active` in **`theme.nix`**, currently `steelbore` = Steelbore Modern; use `theme set <slug>`, and `theme try <slug>` to build a theme without editing anything) and resolves it to the §11.1 **role** tokens — `background`, `surface`, `surfaceAlt`, `foreground`, `accent`, `structure`, `success`, `error`, `warning`, `info`, `focus`, `border` — threaded as `steelborePalette` via `specialArgs`/`extraSpecialArgs`. **Never name a brand color** (`moltenAmber`, `voidNavy`, …); those identifiers are gone and naming one defeats the whole point — switching palettes is one word in `flake.nix` precisely because no consumer knows which palette is active. Values are read from `steelbore.toml` in the `construct` input, never retyped (§11.4). Roles a palette omits fall back (`info` → `structure` → `accent`, `surface` → `background`, `warning` → `error`, `focus` → `success`). **`surface`/`surfaceAlt` are fills only, never text** (§11.0.1 — Quantum Blue is 1.40:1 on the canvas); putting status-colored text on a surface also drops `structure` and `error` below the 4.5:1 AA floor on Modern, which is why the eww bar and dunst deliberately stay on the canvas.
- **Theme repository assets**: two rendering paths exist, on purpose. Bravais renders terminals, bars, WMs, the TTY and greetd from role tokens (`lib/terminal-theme.nix` and friends) — that path serves LOCAL themes too. For the formats Bravais never rendered — the VS Code / Antigravity extension, Zed and Lapce themes, libadwaita GTK 4 / GTK 3 named colours, KDE colour schemes, the Starship preset and Nushell's `color_config` — `lib/theme-assets.nix` maps the active slug to the Theme repository's generated file (`themeAssets.<x>`, threaded like `steelborePalette`). Each attribute is `null` for a local theme, and every consumer falls back to the token path (Starship, Nushell) or to the toolkit default (GTK, KDE). Editor themes are installed as the whole family (editors keep their own pickers); the active slug only selects the GTK/KDE/prompt rendering. Never copy a value out of a Theme file into Nix — read the file, or read the token.
- **Primary user**: `primaryUser = "mj"` is stated once in `flake.nix` and threaded via `specialArgs`/`extraSpecialArgs`; modules use `users.users.''${primaryUser}` / `home-manager.users.''${primaryUser}` — never a literal `mj`. (The `users/mj/` directory name is a stable path, not a restatement.)
- **Overlays**: Defined inline in `modules/core/nix.nix` — the sole location.
- **Home Manager**: Single user `mj`, config at `users/mj/home.nix`. Uses `useGlobalPkgs`, `useUserPackages`, `backupFileExtension = "backup"`. One concern per `users/mj/*.nix`; `home.nix` is identity + imports only.

## File layout

Only the entries that carry a rule; `eza -T --git-ignore` shows the rest, and `flake.nix` names every input.

```
modules/core/nix.nix       # Overlays live here (inline) — the sole location
modules/core/nix-tmp.nix   # Builder TMPDIR is a loop image at /mnt/nix-tmp, never /tmp (system-disk fallback; #28)
users/mj/rebuild.nu        # THE Nushell `rebuild` — one text, used as both the
                           #   config.nu `def` and the `rebuild` binary (shell.nix)
users/mj/default-apps.nix  # THE ONLY xdg.mimeApps block + the FileManager1 D-Bus shadow
pkgs/default.nix           # callPackage index — THE list of in-tree packages; also packages.*
pkgs/<name>/               # One in-tree package each; also a flake output: `nix build .#<name>`
pkgs/update-vendored.nu    # Bumps the 10 version+hash-pinned upstream packages (see below)
pkgs/sync-skills.nu        # Rewrites .github/skills/ from the locked construct rev — run after skills-sync (CI: Skills Drift)
pkgs/preflight/            # THE supported rebuild orchestrator (Rust) — supersedes
                           #   `rebuild` and scripts/rebuild.sh; both now gate on it
scripts/rebuild.sh         # POSIX/Bash port of `rebuild` (keep ALL THREE in step)
theme.nix                  # THE ACTIVE THEME — one word; `theme set <slug>` rewrites it
themes/<slug>.nix          # local themes (filename = slug); `base` to derive, or bind roles
default-apps.nix           # THE ACTIVE HANDLERS — one word per role; `app set <role> <slug>`
apps/<slug>.nix            # app drop-ins (filename = slug); may shadow a built-in entry
CONSTRAINTS.md             # Long form of "Known constraints" — read one `### N.` entry at a time
docs/                      # Long form of AGENTS.md sections: rebuild, skill-pointer, vendored-binaries
```

**Legacy v0 artifacts at repo root — not part of the flake, do not edit:**
`home.nix`, `system.nix`, `ARCHITECTURE.md`, `BRAVAIS.md`, `USER_MANUAL.md`,
`implementation_plan.md`, `PackagesMissing.md`, `v0.zip`. Nothing imports them;
the *active* equivalents are `users/mj/home.nix` and `modules/packages/system.nix`.
Root `README.md`, `PRD.md`, `TODO.md`, `Packages.md`, `CHANGELOG.md`,
`NOTICE.md`, `CONTRIBUTING.md`, `CONSTRAINTS.md` are current and tracked per "Documentation
maintenance" below — don't confuse the two sets.

## First-time bootstrap

Skills come from the `construct` flake input via `construct.homeManagerModules.default` (enabled as `spacecraft.construct` in `home.nix`). The `agentPaths` in `home.nix` (`~/.<agent>/skills`, plus `~/.gemini/config/skills` for Antigravity) are symlinks to `~/.agents/skills`; `~/.gemini/skills` is omitted because Gemini reads `~/.agents/` directly. No manual clone is needed — a local Construct checkout is only for skill authoring.

`~/.agents/skills` is **a real directory of per-skill symlinks, not a store path** (`perSkillLinks.enable`): each Construct entry points through `~/.local/state/construct/current/<skill>`, and `current` aims at either `pinned` (the Home Manager link, tracking `flake.lock`) or `built` (a `nix build --out-link`, run ahead of the lock). Names Construct does not carry stay free for other installers (Orca's three skills) and are never clobbered or pruned. `skills-sync` bumps `construct`, builds this flake's `.#skills` at the new lock and moves the pointer — no rebuild, no sudo; `skills-status` and `skills-reset` inspect and undo it; `rebuild --skills-only` does it through a full switch. `skills-sync` also moves `flake.lock`: follow it with `nu pkgs/sync-skills.nu` and commit both, or the Skills Drift workflow fails the next push (`.github/skills/` is the lock-derived copy the Copilot agent reads). Invariants that are easy to break:

- `current` only ever points at `pinned` or `built` — never at a bare `/nix/store/…` path, which has no GC root and is deleted by the next GC out from under every agent.
- Every activation re-points `current` at `pinned`; never make that seed conditional, or a later rebuild leaves agents on stale skills silently.
- `flake.nix` binds `constructSkills` once and hands the same derivation to `packages.skills` and `spacecraft.construct.package`; two separate builds give different store paths for identical trees and report drift forever.
- Moving `current` changes what every existing link resolves to, but a skill the moved-ahead tree **adds** is not linked, and one it **drops** dangles, until the next activation — `skills-sync` swaps the pointer only.

Agents cache skills at session start, so a mid-session sync is invisible until the harness restarts. The link layout, the reasoning behind each rule and the Grok exception are in **`docs/skill-pointer.md`**.

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

- **SPDX / REUSE**: every hand-written source (`.nix`, `.rs`, `Cargo.toml`, `build.rs`, `.sh`, `.nu`) carries the `GPL-3.0-or-later` license tag inline as its first comment; the copyright tag comes from the copyright-only `aggregate` stanza at the bottom of `REUSE.toml` (globbed over `pkgs/*/`, `pkgs/*.nu`, `scripts/` and `users/mj/`). Header-less files (lockfiles, `.claude/**`, `.github/**`) go in the FIRST stanza, which carries both tags; third-party files keep their own stanza (the vendored protocol XML is HPND-sell-variant). Gate: `nix build --no-link '.#checks.x86_64-linux.reuse-lint'` — the same `reuse` CI builds — must pass (Standard §4.3).
- **Rust-first**: Prefer memory-safe alternatives (sudo-rs over sudo, Sequoia over GnuPG, Nushell over bash, etc.)
- **Shells**: User shell = Nushell, root shell = Brush. Bash module stays enabled (PAM requirement) but is not assigned as any user's login shell.
- **Default terminal**: Alacritty (`Mod+Return`) under Niri and LeftWM. LeftWM *requires* it: rio's wgpu backend renders blank under startx-spawned Xorg (rationale in `modules/desktops/leftwm.nix`). Rio stays installed and themed.
- **Default editor**: msedit (`EDITOR`/`VISUAL` in home.nix)
- **Terminal configs**: All 15 terminals get Steelbore-themed system-level configs in `/etc/` with Nushell as shell
- **ISO 8601**: All date/time displays use `%Y-%m-%d %H:%M:%S` 24h format
- **Niri binds**: primary binds get `hotkey-overlay-title="..."` so they appear in `show-hotkey-overlay`; silent aliases (vim moves, mouse wheel, individual workspace 2-5 numbers) omit the title to keep the overlay readable.
- **`unstablePkgs` for always-latest / unstable-only packages**: `flake.nix` re-instantiates `nixpkgs-unstable` with `config.allowUnfree = true` and threads it into modules and HM via `specialArgs`/`extraSpecialArgs`. Active uses: `uv` (development.nix), `steam-run` (system.nix), `code-cursor-fhs` and `kiro-fhs` (editors.nix). Reach for `unstablePkgs.<name>` whenever a package is unstable-only on 26.05 or whenever stable's version lags meaningfully behind upstream.
- **`home.packages` for user-level packages**: Declared at the top of `users/mj/home.nix` (after `home.stateVersion`), always using `with unstablePkgs;`. Currently hosts the Rust toolchain (`rustup` + cargo subcommands). Use this instead of `environment.systemPackages` for packages that are user-specific rather than system-wide.
- **PATH in shell.nix**: Do **not** use `home.sessionPath` — it always prepends, causing user-local bins to shadow Nix-store ones. The out-of-band bin dirs are single-sourced in the `outOfBandDirs` list in `users/mj/shell.nix` (let block) and rendered into all three managed shells (bash via `posixPathAppend`, Nushell via `nuPathAppend`, Ion via `posixPathAppend`). **Adding a new out-of-band CLI bin dir = one edit to `outOfBandDirs`.** Current dirs: `~/.local/bin`, `~/.cargo/bin`, `~/.kimi-code/bin`, `~/.npm-packages/bin`, `~/.opencode/bin`, `~/.kilo/bin`, `~/.mimocode/bin`, `~/.local/lib/qwen-code/bin`.

## Security

| Layer | Implementation |
|-------|---------------|
| Privilege escalation | `sudo-rs` (Rust), `execWheelOnly = true`. Standard `sudo` (C) is disabled. |
| SSH agent | `gitway-agent` owns `$SSH_AUTH_SOCK` at `${XDG_RUNTIME_DIR}/gitway-agent.sock`. `programs.ssh.startAgent` must stay `false` to avoid racing. `openssh_hpn` remains installed for general SSH workflows. |
| Screen lock PAM | `security.pam.services.gtklock = {}` is required — packages shipping `etc/pam.d/<service>` are invisible to PAM without explicit declaration. |
| Secure Boot | `sbctl` (Rust) installed; not yet enrolled. |
| Fingerprint | `fprintd` + TOD (`libfprint-2-tod1-vfs0090`, locally patched). **Explicit** allow/deny policy in `modules/hardware/fingerprint.nix` — never for session entry (`greetd`, TTY `login`) or anything needing `PAM_OLDAUTHTOK` (`passwd`). `cosmic-greeter` is allowed only while it is merely the lock screen (the module derives this). Fingerprint authenticates; it cannot decrypt. |
| Keyring | gnome-keyring. Auto-unlocked by the greetd password via `pam_gnome_keyring`; `steelbore-keyring-check` (read-only, runs at session start) and `steelbore-keyring-unlock` (`Mod+Shift+U`, rescue) in `modules/desktops/shared.nix`. The gcr **3** prompter is load-bearing — see constraint #32. |

**Security bug reporting:** do not open public issues. Email
`Mohamed.Hammad@SpacecraftSoftware.org`. Default coordinated-disclosure window is
90 days from acknowledgment.

## Known constraints

One rule per trap. The full entry — the evidence, how it fails, how it was diagnosed — is under the same number in **`CONSTRAINTS.md`**: read that entry (`### N.`) before changing anything a rule touches, rather than loading the whole file. Numbers are permanent IDs cited from code comments; never renumber, and add a new constraint to **both** files.

1. **bash cannot be replaced via overlay** — stdenv builds every derivation with it (infinite recursion); assign Nushell/Brush as login shells instead.
2. **`programs.bash.enable` must stay true** — PAM builds and NixOS activation depend on it.
3. **task-master-ai is unbuildable in nixpkgs** — `ai.nix` ships an `npx` wrapper; keep the nixpkgs line commented out.
4. **claude-code, grok-cli, mimocode and qwen-code are out-of-band and self-updating** — don't move them into Nix without a concrete reason.
5. **Stable/unstable package-name splits use the `or` fallback** (`pkgs.xinit or pkgs.xorg.xinit`) — keep it; for `gcr_3 or gcr` the order is load-bearing (#32).
6. **`useFetchCargoVendor` warnings** come from upstream COSMIC — harmless and not suppressible.
7. **Flake-input packages are threaded via `specialArgs` AND `extraSpecialArgs`** (as `gitway` is), never via overlays.
8. **`programs.ssh.startAgent` must stay `false`** — `gitway-agent` owns `$SSH_AUTH_SOCK`.
9. **A package's `etc/pam.d/<service>` is invisible to PAM** until declared as `security.pam.services.<service> = {}` in `modules/core/security.nix`.
10. **`rapg` NAR hash mismatch** after its source changes — fix with `nix flake update rapg`.
11. **Rio hangs at 100% CPU when closed by the X or a WM keybind on Wayland** — type `exit`; its font must stay the Mono variant (enforced in `lib/terminal-theme.nix`).
12. **Never add `rustc`/`cargo`/`rustfmt`/`clippy`/`rust-analyzer` beside `rustup`** — buildEnv collision; use `rustup component add`.
13. **`nil` is built with `doCheck = false`** in `flake.nix` — its upstream builtins-doc test is broken.
14. **chrome-remote-desktop 404s** when Google drops an old deb — bump it with `nu pkgs/update-vendored.nu chrome-remote-desktop`.
15. **opencode-desktop must delete its `.musl.node` files and `*-musl` dirs** in `installPhase`, or autoPatchelf fails.
16. **Vendored `.deb`/tarball layouts drift between releases** — prefer globs over hardcoded filenames in `installPhase`, after grepping that nothing references the name.
17. **`nix flake check` is not a gate** (over 10 minutes) — use the stable toplevel build plus the unstable `drvPath` eval.
18. **Point Alpaca at the existing Ollama service** on `127.0.0.1:11434`, never its bundled one.
19. **`adguardvpn-cli` in TUN mode can displace the DoT+DNSSEC resolver** — prefer SOCKS, or TUN with `script` routing (#37); bump it via `update-vendored.nu`, never its own `update`.
20. **Zellij's in-app configuration is reverted on every activation** — copy changes into `zellijConfigFile`; re-dump the keybind preset from the plugin, never hand-patch it.
21. **`services.displayManager.defaultSession` stays pinned by a plain definition** — two upstream `mkDefault`s collide on unstable; never `mkForce`.
22. **Handler roles own the MIME list, never the app** — an empty file is `application/x-zerosize`, which `text/plain` does not cover; diagnose with `gio info`, not `xdg-mime`.
23. **Engram needs an explicit `--db`** (its default is a relative path) and MCP binaries resolve by bare name on PATH — keep them Nix-provided; never symlink an old SQLite path.
24. **Obscura is built from source, not `unstablePkgs.obscura`** — keep the simdutf `librusty_v8` pin, `-p obscura-cli --bins` and `git` at build time; never set `BORING_BSSL_ASSUME_PATCHED`.
25. **The bar's hardware indicators come from `steelbore-beacon`** (PulseAudio, `EV_LED`, backlight `POLLPRI`) — never add a FnLock indicator.
26. **Only `//` comments in `eww.scss`** — a non-ASCII byte in `/* */` silently unstyles the bar; write `{beacon.caps}`; icon and value in separate labels; keep both bars in step.
27. **`nix flake update antigravity-nix` cannot make Antigravity newer** — the pin lives in `UnbreakableMJ/antigravity-nix`; trust antigravity.google/download, not its `/releases` endpoint.
28. **`/` is a 16 GiB tmpfs** — aim every disk check at a real path (`/nix`, `/var/lib/flatpak`), never `/`.
29. **The xremap side-button unit must never be wanted by `graphical-session.target`** (it would eat niri's mouse binds) and must `--ignore` the TrackPoint.
30. **A failed `home-manager-mj.service` strands every HM change while `nixos-rebuild` reports success** — check it first; a dotfile an app rewrites at runtime needs `force = true`.
31. **Qt reads CLDR, not glibc locales** — stay on `en_US`; any new locale must keep a colon time separator under CLDR; verify with `LC_ALL=<locale> date`.
32. **gcr-prompter exists only in gcr 3** — keep `pkgs.gcr_3 or pkgs.gcr` in that order; a Secret Service `Prompt` dies with its D-Bus connection, so unlocking needs one long-lived client.
33. **`programs.adb` is removed and fails evaluation** — install `pkgs.android-tools` only, no `adbusers` group; set `android_sdk.accept_license` in every nixpkgs instance that needs it.
34. **`/run/wrappers/bin` is first in PATH** — intercept `su` per shell (`suGuard`), never with a package, and exec `/run/wrappers/bin/su`.
35. **The cosmic-comp patch needs `doCheck = false`** — `checkPhase` exhausts memory; don't cap build cores; `--replace-fail` is deliberate.
36. **Never SIGKILL the sudo shim behind a hung `adguardvpn-cli disconnect`** — it strands a root tunnel; use `sudo steelbore-vpn tunnel stop --yes`.
37. **AdGuard TUN routing mode `none` carries no traffic** — use `script` mode with the root-owned `0700` `setup_routes.sh`; keep the split `/1` routes.
38. **Headless Xorg needs the `dummy` and `void` drivers**, which `xorg-server` lacks — the CRD package unions them; `switch-to-configuration` exit 4 means check `systemctl --failed`.
39. **The fingerprint reader survives S3 only with `power/persist=1`** (udev rule) — never stop fprintd from sleep hooks.
40. **Keep `dontStrip = true` on github-copilot-app** — strip plus autoPatchelf corrupts the first RELA entry and ld.so aborts, with no build-time signal.

## Vendored upstream binaries (`pkgs/update-vendored.nu`)

Ten packages pin an upstream `version` + `hash` that `nix flake update` cannot touch: `claude-desktop`, `chrome-remote-desktop`, `ollama`, `goose-desktop`, `opencode-desktop`, `codex-desktop`, `github-copilot-app`, `adguardvpn-cli`, `obscura` (all in `pkgs/`), and `browseros` (inline in `modules/packages/browsers.nix`).

They are **declarative, not self-updating — never bump one by hand**; run `nu pkgs/update-vendored.nu` (`--check` to report only), or `preflight --update-vendored` to bump them as part of a rebuild. **Never restate a pinned version in prose** — point at the package file instead; the ollama 0.31.1 → 0.32.5 bump orphaned five hardcoded copies across modules and docs.

Three exceptions, each explained in **`docs/vendored-binaries.md`**: `codex-desktop` pins an unversioned `…/deb/latest/` URL, so it breaks whenever OpenAI ships and the old artifact cannot be refetched; `grok-bot` is bumped by hand from a copied download URL with its `?_gl=` analytics parameter stripped; `skyroads` has been frozen since the 1990s. Do not add `grok-bot` or `skyroads` to the updater. Per-package failure isolation, the `up-github` tag options and the two-hash `obscura` bumper are in the `vendored-binaries` skill (`.claude/skills/vendored-binaries/`).

## Documentation maintenance

When making changes, keep these in sync:

- **PRD.md** — product requirements, architecture details, package inventories
- **TODO.md** — implementation checklist with `[✓]` markers, known issues, phase progress table
- **CONSTRAINTS.md** — a new constraint gets its entry there **and** a rule line under Known constraints here
- **`docs/*.md`** — the long form of a section here; change the two together
- **CHANGELOG.md** — a bullet under `[Unreleased]` for every user-visible change, under a Keep-a-Changelog type heading; never two adjacent identical headings

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
