---
name: spacecraft-missing-pkg
license: GPL-3.0-or-later
maintainer: Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
website: https://Construct.SpacecraftSoftware.org/
description: >
  Provides missing software on the user's own machine — ephemeral first, never
  mutating the host behind their back. ALWAYS use when a tool, binary, CLI
  utility, linter, formatter, language runtime, or any other software is
  missing or needs to be run; when a command fails with "command not found",
  "not installed", or "missing dependency"; or when you are about to reach for
  apt, dnf, pacman, yum, or zypper.
  Route by how long the tool is needed. One command → run it ephemerally
  (guix shell, nix run / nix-shell, npx, uvx). Needed repeatedly in a repo →
  write a project env (flake.nix devShell, shell.nix, guix.scm, .envrc).
  Wanted permanently → propose a declarative config edit (home.packages,
  environment.systemPackages, a Guix manifest) for the user to apply.
  Imperative installs (cargo, brew, flatpak, AppImage, snap) are a
  consent-gated last resort.
  Never run sudo, never use system-distro managers, never leave durable state
  on the host without asking first.
---

# Spacecraft Software Missing-Package Provisioner

**Maintainer:** Mohamed Hammad | **Contact:** [Mohamed.Hammad@SpacecraftSoftware.org](mailto:Mohamed.Hammad@SpacecraftSoftware.org)
**Copyright:** (C) 2026 Mohamed Hammad & Spacecraft Software | **License:** GPL-3.0-or-later
**Website:** [https://Construct.SpacecraftSoftware.org/](https://Construct.SpacecraftSoftware.org/)

You are running on **the user's own machine**, not in a disposable sandbox.
Every durable byte you write — an installed binary, a downloaded bundle, a new
entry on `PATH` — outlives the session and is the user's to live with and
remove. Treat the host as *borrowed*: satisfy the immediate need without
leaving a trace, and when something genuinely must persist, put it where the
host's own configuration management can see it.

Two rules carry the whole skill:

1. **Ephemeral by default.** If the tool is needed for one command, run it from
   a throwaway environment and leave nothing behind. No consent needed.
2. **Consent for anything durable.** Any install, download, config edit, or
   `PATH` change is *proposed* — with what it does and how to undo it — and
   waits for the user's go-ahead. No exceptions, no "I'll just quickly".

Never use system-distro managers (`apt`, `dnf`, `pacman`, `zypper`, `yum`) —
they need root, write to `/usr`, and are effectively irreversible.

---

## The router — how long is the tool needed?

Answer that first; it picks the band. Manager rank only decides *which* entry
within a band.

| The tool is needed… | Band | What you do |
|---|---|---|
| **For one command, right now** | **A — ephemeral** | Run it from `guix shell` / `nix run` / `nix-shell` / `npx` / `uvx`. Run freely — nothing durable, no consent needed. |
| **Repeatedly, but only inside one repo** | **Project env** | Write a `flake.nix` devShell, `shell.nix`, `guix.scm`, or `.envrc` into the repo. A committed change → propose it. See [references/project-env.md](references/project-env.md). |
| **Permanently, on this machine** | **C — declarative** | Propose the edit to the host's own config (`home.packages`, `environment.systemPackages`, a Guix manifest). The user applies it. See [references/declarative.md](references/declarative.md). |
| **Permanently, on a host with no declarative manager** | **B — imperative** | Propose a `cargo` / `brew` / `flatpak` / AppImage / `snap` install, with its removal command, and wait. |

When unsure, assume **Band A** — an ephemeral run is never the wrong answer for
a single command, and it unblocks the task while a durable decision is pending.

---

## Consent & disclosure

**Band A runs freely.** `guix shell`, `nix run`, `nix-shell`, `npx`, `uvx`
leave nothing on `PATH` and need no permission.

**Everything else stops and asks.** Before any durable change, tell the user:

- **What** — the exact command or file edit
- **Where** — the path it lands in (`~/.cargo/bin/rg`, `~/.local/share/flatpak/`, …)
- **Undo** — the exact removal command
- **Drift** — whether it diverges from the host's declarative config

…then wait. Do not run it and report afterward.

Hard prohibitions on the local host:

- **Never run `sudo`.** Hand the command to the user instead (see *Hand-off*).
- **Never run a system rebuild** — `nixos-rebuild`, `home-manager switch`,
  `guix home reconfigure`, `darwin-rebuild`. Proposing the diff is where you
  stop; applying it is the user's action.
- **Never edit shell rc files** (`.bashrc`, `.profile`, `config.nu`, …) to add
  a `PATH` entry or an alias.
- **Never install imperatively into a declaratively managed host** — that means
  no `nix-env -i`, no `nix profile install`, no `guix install`. They create
  profile drift that survives the next rebuild and confuses the config's
  authors. Band C exists precisely so this is never necessary.
- **Never use system-distro managers** — `apt`, `dnf`, `yum`, `pacman`,
  `zypper`, `emerge`, `xbps`.
- **Never install globally into a language ecosystem** — `npm install -g`,
  `pip install` outside a venv, `gem install` without a user prefix.
- **Never pipe a vendor installer into a shell** — `curl … | sh`.

---

## Step 0 — Confirm the tool is actually missing

`command -v` inside the agent's non-interactive shell is **not** the user's
environment. Check these before provisioning anything:

- **Shell-level definitions are invisible to `command -v`.** Nushell `def`/
  `alias` and Bash functions/aliases do not appear on `PATH`.
- **Non-default binary directories** may be absent from the agent's `PATH`:
  `~/.nix-profile/bin`, `/etc/profiles/per-user/$USER/bin`,
  `/run/current-system/sw/bin`, `~/.local/bin`, `~/.cargo/bin`,
  `/opt/homebrew/bin`, `/home/linuxbrew/.linuxbrew/bin`.
- **A project env may already supply it.** If the repo has a `flake.nix`,
  `shell.nix`, or `.envrc`, the tool may exist inside `nix develop` /
  `direnv`-activated shell even though it is missing outside.
- **A preferred alternative may already be installed.** `spacecraft-cli-preference`
  maps legacy tools to modern ones (`rg` for `grep`, `fd` for `find`, `bat` for
  `cat`) — the mapped tool is often present when the one you reached for isn't.

If it is still ambiguous, ask the user to resolve it in their own shell rather
than guessing — in Claude Code they can prefix a command with `!`:

```
! which <tool>
```

Full checklist: **[references/local-host.md](references/local-host.md)**.

---

## Step 1 — Detect the host

Two things matter: which provisioners exist, and which declarative manager (if
any) governs the machine.

```sh
have() { command -v "$1" >/dev/null 2>&1; }

AVAILABLE=""
have guix       && AVAILABLE="$AVAILABLE guix"
have nix        && AVAILABLE="$AVAILABLE nix"
have nix-shell  && AVAILABLE="$AVAILABLE nix-shell"
have npx        && AVAILABLE="$AVAILABLE npx"
have uvx        && AVAILABLE="$AVAILABLE uvx"
have cargo      && AVAILABLE="$AVAILABLE cargo"
have brew       && AVAILABLE="$AVAILABLE brew"
have flatpak    && AVAILABLE="$AVAILABLE flatpak"
have snap       && AVAILABLE="$AVAILABLE snap"
echo "Provisioners:${AVAILABLE:- none}"

DECLARATIVE=""
have nixos-rebuild  && DECLARATIVE="$DECLARATIVE nixos"
have home-manager   && DECLARATIVE="$DECLARATIVE home-manager"
have darwin-rebuild && DECLARATIVE="$DECLARATIVE nix-darwin"
have guix           && DECLARATIVE="$DECLARATIVE guix"
have direnv         && DECLARATIVE="$DECLARATIVE direnv"
echo "Declarative:${DECLARATIVE:- none}"
```

This snippet is POSIX sh. In **Nushell** external commands take a `^` prefix
and `VAR=x cmd` is not valid — run it as `^bash -c '…'` or use the Nu-native
variant in [references/local-host.md](references/local-host.md). Consult
`spacecraft-cli-shell` before writing any shell for this host (Standard §7:
Nushell, Ion, Brush, and Bash are all first-class).

`home-manager` is often *not* on `PATH` even when Home Manager manages the
host — it is commonly imported as a NixOS/nix-darwin module. Confirm by looking
for a config tree (`/etc/nixos`, `~/.config/home-manager`, a flake with
`homeConfigurations`) rather than trusting `command -v` alone.

If nothing is available, say so. Do not fall back to `apt`/`dnf`/`pacman`.

---

## Step 2 — Band A: run it ephemerally

Walk top-down; take the first entry that is available **and** has the tool.
Verify every package name against its authoritative source before invoking —
never guess, never fabricate: **[references/lookup.md](references/lookup.md)**.

| # | Manager | One-shot form | Scope | Details |
|---|---------|---------------|-------|---------|
| 1 | **Guix** | `guix shell <pkg> -- <cmd> <args>` | Any tool | [references/guix.md](references/guix.md) |
| 2 | **Nix** | `nix run nixpkgs#<pkg> -- <args>` (flakes) · `nix-shell -p <pkg> --run "<cmd>"` | Any tool | [references/nix.md](references/nix.md) |
| 3 | **One-shot runners** | `npx` · `uvx` · `pnpm dlx` · `bunx` | Node / Python packages | [references/oneshot.md](references/oneshot.md) |

```sh
# 1. Guix — no -p flag; `--` separates packages from the command;
#    args after `--` are exec'd directly, so pipelines need sh -c '...'
guix shell ripgrep -- rg 'TODO' src/
guix shell ripgrep coreutils -- sh -c 'ls *.rs | xargs rg pattern'

# 2. Nix — `nix run` is the preferred one-shot where flakes are enabled;
#    `nix-shell --run` works everywhere and runs through a shell, so pipes work
nix run nixpkgs#ripgrep -- 'TODO' src/
nix-shell -p ripgrep --run "rg 'TODO' src/"

# 3. One-shot runners — ecosystem-scoped, nothing lands on PATH
npx --yes prettier --check .
uvx ruff check .
```

Skip rules:

- **One-shot runners** apply only when the tool ships as an npm package (`npx`)
  or a Python package with a console script (`uvx` / `pipx run`). They are
  ephemeral, so prefer them over **any** durable install. If the runtime itself
  is missing, borrow it — `guix shell node -- npx <pkg>`,
  `nix-shell -p uv --run "uvx <pkg>"` — rather than installing it.
- A manager that doesn't have the package skips to the next one.

**Ephemeral environments do not persist between tool calls.** Each Bash
invocation is a fresh process, so a `guix shell` / `nix-shell` environment dies
with the command that created it. Wrap *every* invocation — or, if you are
wrapping the same one repeatedly, that is the signal to graduate to a project
env.

---

## Step 3 — Persisting the tool

### Repo-scoped: write a project env

**A tool needed more than once for a given repo belongs in a committed project
env**, not in a hand-repeated ad-hoc shell. Write a `flake.nix` devShell (`nix
develop`), a `shell.nix`, a `guix.scm` / `manifest.scm`, or a `.envrc` for
direnv. It is a repo change, so propose it and follow that repo's own commit
rules. See **[references/project-env.md](references/project-env.md)**.

### Machine-scoped: propose a declarative edit (Band C)

On a declaratively managed host, the correct way to make a tool permanent is
the host's own config — never an imperative install:

| Host | Attribute | User applies with |
|---|---|---|
| NixOS | `environment.systemPackages` | `sudo nixos-rebuild switch` |
| Home Manager | `home.packages` | `home-manager switch` |
| nix-darwin | `environment.systemPackages` | `darwin-rebuild switch` |
| Guix System / Guix Home | manifest / home config | `guix home reconfigure` |
| macOS + Homebrew | `Brewfile` | `brew bundle` |

Locate the file the host actually uses, propose a minimal diff, name the exact
attribute path, and state the rebuild command — **but never run it**. Until the
user rebuilds, the tool is still absent, so pair the proposal with a Band A
invocation that unblocks the immediate task. See
**[references/declarative.md](references/declarative.md)**.

---

## Step 4 — Band B: imperative installs (consent-gated last resort)

Reach here only when the tool must persist and the host has no declarative
manager that carries it. Every entry below is durable: **propose it with its
removal command and wait.**

| # | Manager | Install | Sudo? | Scope | Declarative equivalent | Details |
|---|---------|---------|-------|-------|------------------------|---------|
| 4 | **Cargo** | `cargo install <crate>` | No | **Rust crates only** | `home.packages` via nixpkgs / `rustPlatform` | [references/cargo.md](references/cargo.md) |
| 5 | **Homebrew** | `brew install <formula>` | No | Any tool | `Brewfile` + `brew bundle` | [references/brew.md](references/brew.md) |
| 6 | **Flatpak** | `flatpak install --user -y flathub <app-id>` | No | Mostly GUI apps | `services.flatpak` / HM module | [references/flatpak.md](references/flatpak.md) |
| 7 | **AppImage** | download, `chmod +x`, run | No | Self-contained apps | `appimageTools` in nixpkgs | [references/appimage.md](references/appimage.md) |
| 8 | **Snap** | hand off `! sudo snap install <pkg>` | **Yes** | Any tool | — | [references/snap.md](references/snap.md) |

Notes:

- **Cargo** applies only to crates on crates.io. Skip it for non-Rust tools even
  when `cargo` is installed. The binary name often differs from the crate name
  (`fd-find` → `fd`, `ripgrep` → `rg`).
- **Flatpak** is GUI-biased; skip it for a CLI unless you have confirmed a
  Flathub app-id.
- **AppImage** has no manager to detect — it is available whenever upstream
  publishes an `*.AppImage` and the host can run it (FUSE, or the
  `--appimage-extract` fallback). Download into
  `${XDG_CACHE_HOME:-$HOME/.cache}/`, not blindly into `/tmp`, and tell the
  user the path.
- **Snap needs root — hand it off.** Never run `sudo` yourself.

---

## Hand-off — commands the user must run

The agent's shell is non-interactive and unprivileged. These will hang or fail
rather than work: `sudo`, `npx`'s install confirmation, `flatpak install`
without `-y`, GPG/keychain prompts, anything wanting a TTY.

Pass the non-interactive flag where one exists (`npx --yes`, `flatpak -y`,
`apt`-style `--non-interactive` equivalents). Where none exists, hand the exact
command to the user — in Claude Code they run it in-session by prefixing `!`:

```
! sudo snap install --classic <pkg>
```

Then continue from the result. Do not attempt the privileged command yourself
and do not spin on a hung prompt.

---

## When nothing in the chain has it

Fall through to **[references/fallback.md](references/fallback.md)**: re-check
the one-shot runners (a tool on npm or PyPI should have been caught in Band A),
try a Git source for an unreleased Rust crate, check for an upstream release
binary or `*.AppImage`, and — if the host is simply offline or a substituter is
unreachable — report that plainly rather than cascading down to a lower tier
that needs the same network.

If every lookup comes up empty, report the gap with the searches you ran and
the URLs you consulted, so the user can double-check or file it upstream.

---

## Worked examples

```sh
# One-off lint — Band A, no consent needed
nix run nixpkgs#shellcheck -- script.sh
guix shell shellcheck -- shellcheck script.sh

# One-off formatter from npm — Band A tier 3
npx --yes prettier --check .

# Node absent? borrow it, don't install it
guix shell node -- npx --yes prettier --check .

# Needed on every build of this repo — project env, proposed as a repo change
#   devShells.default = pkgs.mkShell { packages = [ pkgs.shellcheck ]; };
nix develop -c shellcheck script.sh

# Wanted permanently — Band C proposal, user applies
#   home.packages = [ pkgs.hyperfine ];   then: home-manager switch
# …and unblock now with Band A:
nix run nixpkgs#hyperfine -- 'cmd_a' 'cmd_b'
```

*— Built by Spacecraft Software —*
