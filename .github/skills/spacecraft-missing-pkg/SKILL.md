---
name: spacecraft-missing-pkg
license: GPL-3.0-or-later
maintainer: Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
website: https://Construct.SpacecraftSoftware.org/
description: >
  Provides any required software via the best available package manager,
  preferring ephemeral options over permanent installs. ALWAYS use this skill
  whenever a tool, binary, CLI utility, linter, formatter, language runtime,
  or any other software is missing or needs to be run — regardless of whether
  it's a system tool, Node package, Python package, Rust crate, or anything
  else.
  Trigger whenever a command fails with "command not found", "not installed",
  "missing dependency", or when you're about to reach for apt, dnf, pacman,
  yum, zypper, or any other system-distro package manager. Detect which
  managers are available and use the first applicable one in this priority
  order: Guix → Nix → Cargo (Rust crates only) → Homebrew → Flatpak (Flathub)
  → Snap. Do NOT use system-distro managers (apt, dnf, pacman, zypper, yum)
  under any circumstances.
---

# Spacecraft Software Missing-Package Provisioner

**Maintainer:** Mohamed Hammad | **Contact:** [Mohamed.Hammad@SpacecraftSoftware.org](mailto:Mohamed.Hammad@SpacecraftSoftware.org)
**Copyright:** (C) 2026 Mohamed Hammad | **License:** GPL-3.0-or-later
**Website:** [https://Construct.SpacecraftSoftware.org/](https://Construct.SpacecraftSoftware.org/)

Whenever a tool is missing from `PATH`, this skill walks a fixed priority
chain of package managers and uses the first one that is both **installed
on the system** and **has the requested tool packaged**.

Never fall back to system-distro managers (`apt`, `dnf`, `pacman`, `zypper`,
`yum`, etc.) — they require root, touch `/usr`, and leave durable, hard-to-
reverse changes.

---

## Priority chain

| # | Manager           | Syntax style                                                         | Persistence        | Sudo?   | Scope                | Details                                 |
|---|-------------------|----------------------------------------------------------------------|--------------------|---------|----------------------|-----------------------------------------|
| 1 | **Guix**          | `guix shell <pkg> -- <cmd> <args>`                                   | Ephemeral          | No      | Any tool             | [references/guix.md](references/guix.md) |
| 2 | **Nix**           | `nix-shell -p <pkg> --run "<cmd>"`                                   | Ephemeral          | No      | Any tool             | [references/nix.md](references/nix.md)   |
| 3 | **Cargo**         | `cargo install <crate>` then `<binary>`                              | Permanent (user)   | No      | **Rust crates only** | [references/cargo.md](references/cargo.md) |
| 4 | **Homebrew**      | `brew install <formula>` then `<binary>`                             | Permanent (user)   | No      | Any tool             | [references/brew.md](references/brew.md) |
| 5 | **Flatpak**       | `flatpak install --user -y flathub <app-id>` then `flatpak run <id>` | Permanent (user)   | No      | Mostly GUI apps      | [references/flatpak.md](references/flatpak.md) |
| 6 | **Snap**          | `sudo snap install <pkg>` then `snap run <pkg>`                      | Permanent (system) | **Yes** | Any tool             | [references/snap.md](references/snap.md) |

Guix and Nix leave no durable state (packages are garbage-collected later).
Cargo through Snap are real installs — prefer the highest-ranked applicable
option, and tell the user what was installed.

---

## Step 1 — Detect which managers are available

```bash
have() { command -v "$1" >/dev/null 2>&1; }

AVAILABLE=""
have guix       && AVAILABLE="$AVAILABLE guix"
have nix-shell  && AVAILABLE="$AVAILABLE nix"
have cargo      && AVAILABLE="$AVAILABLE cargo"
have brew       && AVAILABLE="$AVAILABLE brew"
have flatpak    && AVAILABLE="$AVAILABLE flatpak"
have snap       && AVAILABLE="$AVAILABLE snap"

echo "Available provisioners:${AVAILABLE:- none}"
```

If `AVAILABLE` is empty, tell the user no supported provisioner is
installed. Do not fall back to `apt`/`dnf`/`pacman`/etc.

---

## Step 2 — Pick the highest-ranked applicable manager

Walk the priority chain top-down and pick the first manager that is both
available AND has the tool packaged. Skip rules:

- **Cargo** applies only if the tool is a Rust crate on crates.io.
  Skip Cargo for non-Rust tools, even if `cargo` is installed.
- **Flatpak** rarely has CLI tools. Skip Flatpak if the tool is a CLI
  unless you've confirmed a Flathub app-id for it.
- Any manager that doesn't have the package skips to the next one.

Look up each candidate package name in the manager's authoritative source
**before** invoking — do not guess, and do not fabricate names when a
lookup returns nothing. Full lookup sources and naming conventions:
**[references/lookup.md](references/lookup.md)**.

---

## Step 3 — Run the tool

Minimal syntax recap below; full examples and extras in each per-manager
reference file.

### 1. Guix (`guix shell`) — preferred

```bash
guix shell <pkg> -- <command> <args>
guix shell pkg1 pkg2 -- <command> <args>    # multiple tools
```

No `-p` flag; `--` is the separator; args after `--` are exec'd directly
(no shell), so pipelines need `sh -c '...'`. Do not use the deprecated
`guix environment --ad-hoc`. See **[references/guix.md](references/guix.md)**.

### 2. Nix (`nix-shell`)

```bash
nix-shell -p <pkg> --run "<command and args>"
nix-shell -p pkg1 -p pkg2 --run "<command>"    # multiple tools
```

`--run` executes through a shell, so pipes work naturally inside the quoted
string. See **[references/nix.md](references/nix.md)**.

### 3. Cargo (`cargo install`) — Rust crates only

```bash
cargo install <crate>    # installs to ~/.cargo/bin/<binary>
<binary> <args>
```

Permanent, user-local. Binary name often differs from crate name
(`fd-find` → `fd`, `ripgrep` → `rg`). Prefer `cargo binstall` for pre-built
binaries when `cargo-binstall` is available. See
**[references/cargo.md](references/cargo.md)**.

### 4. Homebrew (`brew install`)

```bash
brew install <formula>
<binary> <args>
```

Permanent, user-local (macOS and Linux). See
**[references/brew.md](references/brew.md)**.

### 5. Flatpak (`flatpak`) — mostly GUI apps

```bash
flatpak install --user -y flathub <app-id>
flatpak run <app-id> [<args>]
```

App-ids are reverse-DNS. Most CLI tools are not on Flathub — only use
Flatpak when a confirmed app-id exists. See
**[references/flatpak.md](references/flatpak.md)**.

### 6. Snap (`snap install`) — last resort

```bash
sudo snap install <pkg>              # or --classic for CLIs that need host access
snap run <pkg> [<args>]
```

**Requires sudo.** If the AI is running without sudo, report the situation
rather than attempting the install. See
**[references/snap.md](references/snap.md)**.

---

## When to trigger

- A tool or binary is not found on `PATH` ("command not found", "No such file").
- About to reach for `apt install`, `dnf install`, `pacman -S`, `yay`,
  `zypper install`, `yum install`, etc.
- A script fails because of a missing interpreter, linter, or formatter.

---

## Minimal examples per manager

```bash
# Guix (ephemeral, preferred)
guix shell ripgrep -- rg 'TODO' src/

# Nix (ephemeral)
nix-shell -p ripgrep --run "rg 'TODO' src/"

# Cargo (Rust crate, permanent)
cargo install ripgrep && rg 'TODO' src/

# Homebrew (permanent)
brew install ripgrep && rg 'TODO' src/

# Flatpak (GUI app, example)
flatpak install --user -y flathub org.gimp.GIMP && flatpak run org.gimp.GIMP

# Snap (last resort, requires sudo)
sudo snap install <pkg> && snap run <pkg>
```

For idiomatic, per-manager example workflows — multi-tool pipelines,
containerized invocations, language-ecosystem ad-hoc envs, and cleanup —
see the linked reference files above.

---

## When nothing in the chain works

If no manager in the chain has the tool, fall through to the guidance in
**[references/fallback.md](references/fallback.md)** (Git-source Cargo
installs, language-native ad-hoc envs like `npx` / `uvx`, and hard
prohibitions on `apt`/`dnf`/`pacman`/`pip -g`/`npm -g`).

*— Built by Spacecraft Software —*
