---
name: spacecraft-missing-pkg
license: GPL-3.0-or-later
maintainer: Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
website: https://Construct.SpacecraftSoftware.org/
compatibility: "Classify first (references/execution-context.md). Local host (Nix/Guix): rules below. Disposable sandbox such as Claude Code on the web: its own apt/pip/npm/cargo, no consent. No shell tool: hand the user the command."
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
  On the user's host, never run sudo, never use system-distro managers, never
  leave durable state without asking first.
---

# Spacecraft Software Missing-Package Provisioner

**Maintainer:** Mohamed Hammad | **Contact:** [Mohamed.Hammad@SpacecraftSoftware.org](mailto:Mohamed.Hammad@SpacecraftSoftware.org)
**Copyright:** (C) 2026 Mohamed Hammad & Spacecraft Software | **License:** GPL-3.0-or-later
**Website:** [https://Construct.SpacecraftSoftware.org/](https://Construct.SpacecraftSoftware.org/)

## Step −1 — Whose machine is this?

Before any other probe, classify the session once and cache the answer, per
**[references/execution-context.md](references/execution-context.md)**:

| Mode | What it is | This skill |
|---|---|---|
| **local-host** | The user's own long-lived machine, including a container that persists on it. **Default.** | Every section except *Disposable sandbox* and *No execution*, unchanged |
| **disposable-sandbox** | A VM or container discarded after the session — Claude Code on the web, hosted chat/agent sandboxes. Requires **all** of: a **positive hosted marker** (`CLAUDE_CODE_REMOTE=true`, or the harness or the user stating the session runs in a hosted sandbox); no Nix/Guix; no local-container marker; no personal login shell | *Disposable sandbox* below; local-host rules apply only to what leaves it, or touches the repo checkout's files and history |
| **no-execution** | No shell or code tool at all | *No execution* below |

A container signal (`/.dockerenv`, a container cgroup, a non-init PID 1) says
*containerised*, not *disposable* — it **never qualifies on its own**, even
running as root. A
container that persists on the user's own machine — distrobox, toolbox, a
local devcontainer, GitHub Codespaces, anything whose `$HOME` is under
`/home/<user>` for a personal account (not a generic cloud account such as
`user`, `ubuntu`, `runner`) or bind-mounted from the host — is **local-host**, not a
sandbox: no consent-free `apt`, no `sudo`, however freely the container grants
them.

**Partial or conflicting evidence → local-host**, the mode with the strictest
rules. Guessing "sandbox" wrongly mutates a real machine; guessing "local"
wrongly only costs a consent prompt.

---

## Local host — the default

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

Never use system-distro managers (`apt`, `dnf`, `pacman`, `zypper`, `yum`) on
the user's host — they need root, write to `/usr`, and are effectively
irreversible.

---

## The router — how long is the tool needed?

Answer that first; it picks the band. Manager rank only decides *which* entry
within a band.

| The tool is needed… | Band | What you do (local-host) | Disposable sandbox |
|---|---|---|---|
| **For one command, right now** | **A — ephemeral** | Run it from `guix shell` / `nix run` / `nix-shell` / `npx` / `uvx`. Run freely — nothing durable, no consent needed. | Nix/Guix **skipped** (absent). `npx` / `uvx` / `pipx run` still first; otherwise install with the sandbox's own manager — no consent |
| **Repeatedly, but only inside one repo** | **Project env** | Write a `flake.nix` devShell, `shell.nix`, `guix.scm`, `.envrc`, or — in a local devcontainer — `.devcontainer/devcontainer.json` `features` into the repo. A committed change → propose it. See [references/project-env.md](references/project-env.md). | **Unchanged** — a repo change, proposed as one |
| **Permanently, on this machine** | **C — declarative** | Propose the edit to the host's own config (`home.packages`, `environment.systemPackages`, a Guix manifest). The user applies it. See [references/declarative.md](references/declarative.md). | **Skipped for the sandbox** — nothing outlives the session; install for the session instead. If the user wants the tool permanently **on their own machine**, propose the Band C edit as text, as in no-execution |
| **Permanently, on a host with no declarative manager** | **B — imperative** | Propose a `cargo` / `brew` / `flatpak` / AppImage / `snap` install, with its removal command, and wait. | The sandbox's own `apt` / `pip` / `npm` / `cargo` / `gem` / `go` — **no consent, no removal command** |

In **no-execution** mode every row becomes text: hand the user the local-host
command for their own machine (see *No execution*).

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

Hard prohibitions on the local host (in a disposable sandbox they give way to
*Disposable sandbox* below — except `curl … | sh`, banned in every mode;
anything that leaves the sandbox; and deleting or overwriting files in the repo
checkout or rewriting git history, which stay consent-gated):

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
environment. Check these before provisioning anything. In a disposable sandbox,
run the same checklist against **the sandbox** — it tells you what the sandbox
has, never what the user has — and skip only the final ask-the-user step. In
no-execution, skip every probe:

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

If it is still ambiguous on local-host, ask the user to resolve it in their own
shell rather than guessing (in a disposable sandbox the user's shell cannot
answer a question about the sandbox — provision instead; the same holds on
any host the user cannot reach, such as a hosted chat container, per
[references/execution-context.md](references/execution-context.md)) — in the Claude Code CLI they can prefix a command with `!`;
elsewhere, give them a fenced block to run:

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

Two local-host containers need one more look before giving up. Inside
**distrobox**, the host's Nix/Guix is off `PATH` but reachable: probe
`distrobox-host-exec sh -c 'command -v nix guix'` and, if present, run Band A
through it (`distrobox-host-exec nix run nixpkgs#<pkg> -- …`) — say that it
executes on the host. In a **local devcontainer**, the durable route is the
container's own config: propose a repo change to `.devcontainer/devcontainer.json`
`features` (or its Dockerfile `RUN apt-get install …`), applied when the user
rebuilds the container — the *Project env* band.

If nothing is available, say so. On local-host, do not fall back to
`apt`/`dnf`/`pacman`. In a disposable sandbox, Nix and Guix are absent by
definition — the sandbox's own `apt`, `pip`, `npm`, `cargo`, `gem`, and `go`
are the route (see *Disposable sandbox*).

---

## Step 2 — Band A: run it ephemerally

Walk top-down; take the first entry that is available **and** has the tool.
In a disposable sandbox rows 1–2 are skipped (no Nix/Guix) and row 3 stays
first.
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
  is missing on **local-host**, borrow it — `guix shell node -- npx <pkg>`,
  `nix-shell -p uv --run "uvx <pkg>"` — rather than installing it. In a
  **disposable sandbox** (no Nix/Guix) install the runtime with the sandbox's
  own manager instead — `apt-get update -qq && DEBIAN_FRONTEND=noninteractive
  apt-get install -y nodejs npm` (root/`sudo -n` guard as in *Disposable
  sandbox*), `uvx`/`pipx run` if already present, else `pip install uv` (in a venv
  outside the working tree if the system Python is externally managed; install
  `python3-venv` first under the same guard if `venv` is missing) — no consent; see
  [references/execution-context.md](references/execution-context.md).
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

On a declaratively managed host (local-host), the correct way to make a tool
permanent is the host's own config — never an imperative install. Skipped in a
disposable sandbox: nothing there persists.

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
removal command and wait.** In a disposable sandbox none of that applies — see
*Disposable sandbox*.

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
command to the user — in the Claude Code CLI they run it in-session by
prefixing `!`; everywhere else (Claude Code on the web included), give a fenced
block for the user's login shell:

```
! sudo snap install --classic <pkg>
```

Then continue from the result. Do not attempt the privileged command yourself
and do not spin on a hung prompt.

---

## Disposable sandbox

A VM or container discarded after the session — Claude Code on the web, a
hosted chat/agent sandbox. The local-host rules exist to protect **durable**
state; here there is none worth protecting, so they relax for everything that
stays inside the sandbox — and only for that.

| Concern | In a disposable sandbox |
|---|---|
| **Probes** | Run once, cache. They describe **the sandbox, never the user** — do not report its `PATH`, tools, or login shell as the user's environment. Run Step 0's checklist against the sandbox (shell definitions, extra bin dirs, an active project env, a mapped alternative); skip only its ask-the-user step |
| **Band A** | Nix/Guix **skipped** (absent). `npx --yes` / `uvx` / `pipx run` still first for one-shots |
| **Installs** | The sandbox's own `apt`, `pip`, `npm`, `cargo`, `gem`, `go` — **no consent, no removal command, no disclosure ledger**. `npm install -g` and `pip install` are fine here; if the system Python refuses (`externally-managed-environment`), use a venv outside the working tree |
| **`sudo`** | Only after Step −1 has classified the session **disposable-sandbox** (positive hosted marker included) — never as a probe that decides the mode. Not needed when already root. Otherwise only when the sandbox grants it **non-interactively** — `sudo -n true` succeeds. Otherwise do not prompt, do not retry: install without it, or report the gap. **Never on local-host**, and a persistent container on the user's machine (distrobox, toolbox, a local devcontainer, Codespaces) is local-host — passwordless `sudo` or root inside one is not evidence of a sandbox |
| **Band C** | **Skipped for the sandbox** — no config worth editing, nothing outlives the session. If the user wants the tool permanently **on their own machine**, propose the Band C edit as text, as in *No execution* |
| **Repo writes** | **Unchanged.** A `flake.nix` devShell, `.envrc`, CI step, or script is a repo change governed by the repo's own environment — proposed through the *Project env* band. A tool installed in the sandbox is not something the repo can rely on |
| **Consent** | Not required for package and tool installs or scratch state **outside** the working tree. Still required for anything that **leaves** the sandbox — pushes, PRs, publishing, network writes, commits — and for deleting, overwriting, or reverting repo files beyond the requested change or rewriting git history (`rm -rf`, `git reset --hard`, `git clean -fdx`): the session's uncommitted work is the user's |
| **Still banned** | `curl … \| sh` — unreviewable in every mode |
| **Hand-off** | No `!` prefix here. Commands the **user** will run go in a fenced block for their login shell — not measurable from the sandbox, so inferred (Nushell in Spacecraft context) and announced |

```sh
# Classified disposable-sandbox (Step −1, positive hosted marker) — never in
# distrobox/toolbox/Codespaces/a local devcontainer.
# shellcheck missing — install for the session, no consent
if [ "$(id -u)" -eq 0 ]; then
  apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y shellcheck
elif sudo -n true 2>/dev/null; then
  sudo -n apt-get update -qq && sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y shellcheck
else echo "no root in this sandbox — cannot apt-get shellcheck" >&2
fi
```

---

## No execution

No shell or code tool exists — nothing can be probed or run. Advise instead:

- **Skip every probe.** State the assumption in one line ("assuming a Nix host
  with Nushell").
- **Give the user the command** for their login shell — Nushell by default,
  inferred and announced — following the local-host router: Band A first, a
  project env or Band C edit as the durable answer, Band B with its removal
  command. Never a system-distro manager.
- **Hand-off form:** `!`-prefixed in the Claude Code CLI (Bash tool denied);
  a fenced block everywhere else.
- **Preferred tools carry a fallback.** Where the command uses a
  `spacecraft-cli-preference` tool, add a one-line legacy fallback note — the
  user's host is unmeasured, so the preferred tool may be absent.
- **The hand-off is the consent point.** The user runs it or doesn't.

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

# Node absent on local-host? borrow it, don't install it
guix shell node -- npx --yes prettier --check .
# Node absent in a disposable sandbox (no Nix/Guix)? the sandbox's own manager, no consent
# (root/`sudo -n` guard — see Disposable sandbox)
if [ "$(id -u)" -eq 0 ]; then
  apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs npm
elif sudo -n true 2>/dev/null; then
  sudo -n apt-get update -qq && sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs npm
else echo "no root in this sandbox — cannot apt-get nodejs" >&2
fi && npx --yes prettier --check .

# Needed on every build of this repo — project env, proposed as a repo change
#   devShells.default = pkgs.mkShell { packages = [ pkgs.shellcheck ]; };
nix develop -c shellcheck script.sh

# Wanted permanently — Band C proposal, user applies
#   home.packages = [ pkgs.hyperfine ];   then: home-manager switch
# …and unblock now with Band A:
nix run nixpkgs#hyperfine -- 'cmd_a' 'cmd_b'
```

*— Built by Spacecraft Software —*
