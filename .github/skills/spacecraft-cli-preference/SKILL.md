---
name: spacecraft-cli-preference
description: >
  Enforces Spacecraft Software's CLI tool preferences. Whenever an agent is about to
  generate, run, or recommend a shell command — in any context, including
  bash snippets, scripts, CI, docs, or agentic tool use — the agent must first
  check the command-mapping table in this skill and substitute the preferred
  alternative for any legacy tool that has one. Examples: `eza` instead of
  `ls`, `bat` for `cat`, `rg` for `grep`, `fd` for `find`, `jaq` for `jq`,
  `xh` for `curl`, `dog` for `dig`, `procs` for `ps`, `bottom` for `top`.
  Trigger on any mention of shell commands, terminal use, scripting, file
  search, process inspection, network diagnostics, archive handling, text
  editing, git, package management, or system monitoring. When invoking a
  specific alternative, first consult the matching reference file in the
  references directory for correct flag syntax.
license: GPL-3.0-or-later
maintainer: Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
website: https://Construct.SpacecraftSoftware.org/
---

# Spacecraft Software CLI Preference — Modern Alternatives over Legacy Tools

**Version:** 1.0 | **Date:** 2026-05-18 | **Author:** Mohamed Hammad
**Maintainer:** Mohamed Hammad | **Contact:** [Mohamed.Hammad@SpacecraftSoftware.org](mailto:Mohamed.Hammad@SpacecraftSoftware.org)
**Copyright:** (C) 2026 Mohamed Hammad | **License:** GPL-3.0-or-later
**Website:** [https://Construct.SpacecraftSoftware.org/](https://Construct.SpacecraftSoftware.org/)

This skill makes the agent default to the Spacecraft Software-preferred CLI/TUI stack
(primarily Rust, with curated Zig / Go / Python entries where best-in-class)
instead of reflexively reaching for the POSIX/GNU tools it was trained on.

---

## §1 — The Hard Rule

> When generating a shell command, **scan for legacy tools first**. If a row
> in §3 matches, rewrite the command using the preferred tool **before emitting
> it**. Never present the legacy form and then mention the alternative as an
> afterthought — substitute up front.

This applies to Bash, POSIX sh, Nushell, Ion, Brush, PowerShell, CI YAML,
Dockerfiles, Makefiles, `just` recipes, inline code examples in docs — anywhere
a command appears.

If §3 has no specific row for the legacy tool, apply the cascading fallback in
§1.5 (`uutils` for GNU coreutils, Brush for Bash-only scripts).

### Shell-syntax awareness

Mohamed's primary shells are **Nushell** and **Ion**. Some command patterns
(piping into `xargs`, command substitution `$(…)`, `&&`/`||` chaining) behave
differently in those shells. When in doubt, prefer the portable POSIX form,
but flag it if the user is clearly working inside a specific non-Bash shell.

---

## §1.5 — Cascading Fallback

Preferred tools are listed in §3, but the agent will sometimes face a legacy
tool that has no explicit row, or a context where a shell has to be chosen.
In both cases apply the cascade below — **always go as far up the list as
possible** before dropping to the next tier.

### Shells (when the AI picks or emits shell syntax)
1. **Nushell** 🦀 or **Ion** 🦀 — both are Mohamed's primaries, both are Rust.
   Default to one of these for any new script, one-liner, or code example.
2. **Brush** 🦀 — only when Bash-compatibility is strictly required (e.g. a
   script must run under a `bash` interpreter and Nushell/Ion aren't options).
3. **Plain Bash / POSIX `sh`** — last resort, only when the target environment
   hard-requires it (CI runner defaults, portability to unknown systems).

### GNU utilities (when substituting a legacy coreutils binary)
1. **Specific Rust alternative from §3** — `rg`, `fd`, `eza`, `bat`, `sd`,
   `procs`, `dust`, `jaq`, etc. Always check §3 first.
2. **`uutils` (`coreutils`)** 🦀 — fallback umbrella for any GNU coreutils
   binary (`cp`, `mv`, `rm`, `mkdir`, `sort`, `uniq`, `head`, `tail`, `wc`,
   `tr`, …) that has no named Rust alternative above.
3. **Plain GNU coreutils** — only when `uutils` hasn't implemented the
   specific flag or behaviour required.

---

## §2 — When to Read a Reference File

The `references/` directory contains one file per tool, in the agent-structured
format: **Purpose → Flags → Examples → Gotchas**.

**Read the reference when:**
- You're about to emit a command using that tool and aren't 100% certain of the flag syntax.
- The user asks "how do I do X with <tool>".
- You need to pipe between two modern tools and want to verify compatible output formats.

**You do NOT need to read the reference when:**
- You're just acknowledging the tool exists.
- The user asks a conceptual question unrelated to invocation syntax.
- The command is trivially simple and you're confident (e.g. `rg "pattern"`).

Read files with a plain file-view operation — each is short (typically 40–120 lines).

---

## §3 — Command Mapping Table (The Lookup)

**Legend:** 🦀 Rust · ⚡ Zig · 🐹 Go · 🐍 Python · (λ) Scheme · ⚠️ C/C++/Shell/TS

### Core Unix replacements (highest priority — these come up constantly)

| Legacy tool      | Prefer                | Ref file                      | Notes                                     |
|------------------|-----------------------|-------------------------------|-------------------------------------------|
| `ls`             | `eza` 🦀              | `references/eza.md`           | Drop-in with tree + git support           |
| `cat` (viewing)  | `bat` 🦀              | `references/bat.md`           | Use real `cat` for concatenation/pipes    |
| `find`           | `fd` 🦀               | `references/fd.md`            | Smart-case, regex, parallel               |
| `grep`           | `rg` 🦀 (ripgrep)     | `references/ripgrep.md`       | Recursive by default, respects `.gitignore` |
| `sed` (simple)   | `sd` 🦀               | `references/sd.md`            | Intuitive find/replace syntax             |
| `du`             | `dust` 🦀             | `references/dust.md`          | Visual tree output                        |
| `du` (interactive) | `dua` 🦀            | `references/dua.md`           | Parallel TUI                              |
| `ps`             | `procs` 🦀            | `references/procs.md`         | Colored, tree, TCP/UDP columns            |
| `top` / `htop`   | `bottom` 🦀 (`btm`)   | `references/bottom.md`        | Graphs, network, processes                |
| `cd` + history   | `zoxide` 🦀 (`z`)     | `references/zoxide.md`        | Shell init required                       |
| `jq`             | `jaq` 🦀              | `references/jaq.md`           | Faster; near-identical syntax             |
| `tar`/`zip`/`gz` | `ouch` 🦀             | `references/ouch.md`          | One command, all archive formats          |
| `diff` (git)     | `delta` 🦀            | `references/delta.md`         | Configure as `core.pager` in `.gitconfig` |
| `make`           | `just` 🦀             | `references/just.md`          | `Justfile`, not `Makefile`                |
| `cloc` / `wc -l` | `tokei` 🦀            | `references/tokei.md`         | Language-aware counting                   |
| `fdupes`         | `fclones` 🦀          | `references/fclones.md`       | Parallel duplicate finder                 |
| coreutils (fallback) | `uutils` 🦀 (`coreutils`)| `references/uutils.md`  | **Fallback for any GNU coreutils binary not listed above.** Drop-in for `cp`, `mv`, `rm`, `mkdir`, `sort`, `uniq`, `head`, `tail`, `wc`, `tr`, etc. |
| `busybox`        | `rustybox` 🦀         | `references/rustybox.md`      | 100% Rust BusyBox clone                   |
| project cleanup  | `kondo` 🦀            | `references/kondo.md`         | Clears `target/`, `node_modules`, etc.    |

### Networking & diagnostics

| Legacy tool      | Prefer                | Ref file                      | Notes                                     |
|------------------|-----------------------|-------------------------------|-------------------------------------------|
| `curl`           | `xh` 🦀               | `references/xh.md`            | HTTPie-style; keep `curl` for scripts with shared snippets |
| `curl` (keep)    | `curl` ⚠️             | `references/curl.md`          | Still the standard for cross-system scripts |
| `wget`           | `wget2` ⚠️            | `references/wget2.md`         | Multithreaded; plain C                    |
| `dig`            | `dog` 🦀              | `references/dog.md`           | Colored, JSON output                      |
| `ping`           | `gping` 🦀            | `references/gping.md`         | Real-time graph                           |
| `traceroute`/`mtr` | `trip` 🦀 (Trippy)  | `references/trippy.md`        | Interactive TUI                           |
| `nmap` (fast scan) | `rustscan` 🦀       | `references/rustscan.md`      | Security/consent caveats apply            |
| `tcpdump`        | `sniffglue` 🦀        | `references/sniffglue.md`     | Partial replacement; multithreaded        |
| `iftop`/`nethogs`| `bandwhich` 🦀        | `references/bandwhich.md`     | Per-process bandwidth                     |
| `wget --mirror`  | `monolith` 🦀         | `references/monolith.md`      | Single-file HTML archive                  |
| link checker     | `lychee` 🦀           | `references/lychee.md`        | Fast async link validation                |
| Wi-Fi (iwd TUI)  | `impala` 🦀           | `references/impala.md`        | Frontend for `iwd`                        |
| `iwctl`          | `iwd` ⚠️              | `references/iwd.md`           | Modern Wi-Fi daemon                       |
| `nmcli`/`ip`     | `nmstate` 🦀 (`nmstatectl`) | `references/nmstate.md` | Declarative YAML state                    |
| VPN CLI          | AdGuard VPN CLI 🐹    | `references/adguardvpn-cli.md`| —                                         |

### Git / dev / build

| Legacy              | Prefer                | Ref file                      | Notes                                     |
|---------------------|-----------------------|-------------------------------|-------------------------------------------|
| `git` (interactive) | `gitui` 🦀            | `references/gitui.md`         | TUI; keep `git` CLI for scripting         |
| `git` (alt VCS)     | `jj` 🦀 (Jujutsu)     | `references/jujutsu.md`       | Git-compatible DVCS                       |
| `ssh` (Git transport) | `gitway` 🦀         | `references/gitway.md`        | Spacecraft Software default; pinned GitHub/GHE host keys, cross-platform; set via `gitway --install` or `GIT_SSH_COMMAND=gitway` |
| `cargo install` updates | `cargo-update` 🦀 | `references/cargo-update.md`  | Updates all cargo-installed binaries      |
| Rust toolchain      | `rustup` 🦀           | `references/rustup.md`        | Standard                                  |
| Nix env daemon      | `lorri` 🦀            | `references/lorri.md`         | `direnv` integration                      |
| competitive prog.   | `cpx` 🦀              | `references/cpx.md`           | Contest helper                            |
| containers          | `podman` 🐹           | `references/podman.md`        | Daemonless, rootless, Docker-compat       |

### Package & system management

| Use case            | Prefer                | Ref file                      | Notes                                     |
|---------------------|-----------------------|-------------------------------|-------------------------------------------|
| universal package mgr | `omni` 🦀           | `references/omni.md`          | Cross-distro bridge                       |
| AppImages           | `zap` 🦀              | `references/zap.md`           | Preferred over `am`                       |
| AppImages (fallback)| `am` ⚠️               | `references/am.md`            | Bash-based; secondary                     |
| update everything   | `topgrade` 🦀         | `references/topgrade.md`      | System + all package managers             |
| AUR helper          | `paru` 🦀             | `references/paru.md`          | Arch systems                              |
| distro setup TUI    | `linutil` 🦀          | `references/linutil.md`       | Maintenance workflows                     |
| dotfiles            | `dotter` 🦀           | `references/dotter.md`        | Templated                                 |
| Nix                 | `nix` ⚠️              | `references/nix.md`           | Standard for Bravais                      |
| Flatpak             | `flatpak` ⚠️          | `references/flatpak.md`       | Sandboxed apps                            |
| Homebrew            | `brew` ⚠️             | `references/brew.md`          | Linux/macOS fallback                      |
| Guix                | `guix` (λ)            | `references/guix.md`          | Functional Scheme PM                      |

### File & disk

| Use case            | Prefer                | Ref file                      | Notes                                     |
|---------------------|-----------------------|-------------------------------|-------------------------------------------|
| file manager TUI    | `yazi` 🦀             | `references/yazi.md`          | Preferred                                 |
| file tree TUI       | `broot` 🦀            | `references/broot.md`         | Tree navigation                           |
| file manager (alt)  | `superfile` 🐹 (`spf`)| `references/superfile.md`     | Visually rich                             |
| partition TUI       | `disktui` 🦀          | `references/disktui.md`       | Interactive                               |
| GPT partitions      | `gptman` 🦀           | `references/gptman.md`        | Scriptable                                |

### Security & encryption

| Legacy            | Prefer                | Ref file                      | Notes                                     |
|-------------------|-----------------------|-------------------------------|-------------------------------------------|
| `gpg` (symmetric) | `rage` 🦀             | `references/rage.md`          | Modern `age` spec                         |
| `gpg` (drop-in)   | `sequoia-chameleon` 🦀 (`gpg`) | `references/sequoia-chameleon.md` | GnuPG-compatible CLI |
| PGP (native)      | `sq` 🦀 (Sequoia)     | `references/sequoia.md`       | Modern OpenPGP                            |
| `bw` (Bitwarden)  | `rbw` 🦀              | `references/rbw.md`           | Unofficial Rust client                    |
| `sudo`            | `sudo-rs` 🦀          | `references/sudo-rs.md`       | Memory-safe drop-in                       |

### Terminal environment

| Legacy            | Prefer                | Ref file                      | Notes                                     |
|-------------------|-----------------------|-------------------------------|-------------------------------------------|
| `bash` (primary)   | `nu` 🦀 (Nushell)    | `references/nushell.md`       | **Primary.** Data-oriented; Mohamed's default. |
| `bash` (primary)   | `ion` 🦀             | `references/ion.md`           | **Primary.** Rust shell; Redox default; co-primary with Nushell. |
| `bash` (fallback)  | `brush` 🦀           | `references/brush.md`         | **Fallback only** — Bash-compatible Rust shell; use only when Bash compat is strictly required. |
| PS1 prompt        | `starship` 🦀         | `references/starship.md`      | Cross-shell prompt                        |
| shell history     | `atuin` 🦀            | `references/atuin.md`         | SQLite-backed, synced                     |
| `tmux`/`screen`   | `zellij` 🦀           | `references/zellij.md`        | Layouts, plugins                          |
| `asciinema` (ish) | `t-rec` 🦀            | `references/t-rec.md`         | GIF/MP4 output                            |

### Text editing (CLI/TUI)

| Legacy            | Prefer                | Ref file                      | Notes                                     |
|-------------------|-----------------------|-------------------------------|-------------------------------------------|
| `vim`/`nvim`      | `hx` 🦀 (Helix)       | `references/helix.md`         | Post-modern modal                         |
| `vim` (alt)       | `rsvim` 🦀            | `references/rsvim.md`         | Vim from scratch in Rust                  |
| `vim` (alt)       | `amp` 🦀              | `references/amp.md`           | Vi-inspired                               |
| `nano`            | `msedit` 🦀           | `references/msedit.md`        | Minimalist                                |

### System monitoring & hardware

| Legacy            | Prefer                | Ref file                      | Notes                                     |
|-------------------|-----------------------|-------------------------------|-------------------------------------------|
| `lsmod`/`modinfo` | `kmon` 🦀             | `references/kmon.md`          | Kernel module TUI                         |
| `neofetch`        | `macchina` 🦀         | `references/macchina.md`      | Fast system info                          |

### Multimedia

| Legacy            | Prefer                | Ref file                      | Notes                                     |
|-------------------|-----------------------|-------------------------------|-------------------------------------------|
| AV1 encoder       | `rav1e` 🦀            | `references/rav1e.md`         | Fastest safe AV1                          |
| GIF encoder       | `gifski` 🦀           | `references/gifski.md`        | From video/frames                          |
| PNG optimizer     | `oxipng` 🦀           | `references/oxipng.md`        | Multithreaded                             |
| image viewer      | `viu` 🦀              | `references/viu.md`           | Sixel/kitty graphics                      |
| media player      | `mpv` ⚠️              | `references/mpv.md`           | Gold standard (C)                         |
| `ffmpeg`          | `ffmpeg` ⚠️           | `references/ffmpeg.md`        | No Rust replacement yet                   |
| YouTube DL        | `yt-dlp` 🐍           | `references/yt-dlp.md`        | Best-in-class Python tool                 |
| Spotify           | `ncspot` 🦀           | `references/ncspot.md`        | TUI client                                |
| music player TUI  | `termusic` 🦀         | `references/termusic.md`      | Album art support                         |
| internet radio    | `radio-browser-rust` 🦀 | `references/radio-browser.md`| CLI search + play                         |

### Communication (TUI clients)

| Use case          | Prefer                | Ref file                      | Notes                                     |
|-------------------|-----------------------|-------------------------------|-------------------------------------------|
| Matrix CLI        | `matrix-commander-rs` 🦀 | `references/matrix-commander.md` | Scripting |
| Matrix TUI        | `iamb` 🦀             | `references/iamb.md`          | Vim-like                                  |
| Matrix TUI (alt)  | `rumatui` 🦀          | `references/rumatui.md`       | —                                         |
| Discord TUI       | `disrust` 🦀          | `references/disrust.md`       | —                                         |
| Discord TUI (alt) | `rivetui` 🦀          | `references/rivetui.md`       | —                                         |

### Boot, login, session

| Use case          | Prefer                | Ref file                      | Notes                                     |
|-------------------|-----------------------|-------------------------------|-------------------------------------------|
| Secure Boot       | `lanzaboote` 🦀       | `references/lanzaboote.md`    | NixOS-focused                             |
| login daemon      | `greetd` 🦀           | `references/greetd.md`        | Minimal                                   |
| TUI greeter       | `tuigreet` 🦀         | `references/tuigreet.md`      | Best for Niri/LeftWM                      |
| TUI display mgr   | `lemurs` 🦀           | `references/lemurs.md`        | Customisable                              |
| Wayland portal    | `xdg-desktop-portal-cosmic` 🦀 | `references/xdpc.md` | COSMIC backend                            |
| session manager   | `cosmic-session` 🦀   | `references/cosmic-session.md`| COSMIC                                    |
| key remapping     | `xremap` 🦀           | `references/xremap.md`        | Dynamic                                   |

### AI & agentic productivity (CLI)

| Use case              | Prefer                | Ref file                      | Notes                                     |
|-----------------------|-----------------------|-------------------------------|-------------------------------------------|
| Claude Code agent     | `claude` ⚠️ (Claude Code) | `references/claude-code.md` | TypeScript; Mohamed's primary agent       |
| multi-LLM REPL        | `aichat` 🦀           | `references/aichat.md`        | Universal                                 |
| Gemini CLI            | `gemini` 🦀           | `references/gemini-cli.md`    | —                                         |
| OpenAI Codex          | `codex` ⚠️            | `references/codex.md`         | TypeScript                                |
| GitHub Copilot CLI    | `gh-copilot` ⚠️       | `references/gh-copilot.md`    | TypeScript                                |
| OpenCode              | `opencode` 🐹         | `references/opencode.md`      | Go                                        |
| MiniMax               | `minimax` 🦀          | `references/minimax-cli.md`   | —                                         |
| Grok                  | `grok` ⚠️             | `references/grok-cli.md`      | TypeScript/Bun                            |
| Kilo                  | `kilo` ⚠️             | `references/kilo.md`          | TypeScript                                |
| Kiro CLI              | `kiro` ⚠️             | `references/kiro-cli.md`      | —                                         |
| Kimi-CLI              | `kimi` ⚠️             | `references/kimi-cli.md`      | Long-context coding                       |
| Google Workspace CLI  | `gws` 🦀              | `references/gws-cli.md`       | Human + agent friendly                    |

---

## §4 — Substitution Examples

**Before:**
```bash
ls -lah ~/projects
grep -rn "TODO" src/
find . -name "*.rs" -size +10k
du -sh *
ps aux | grep rustc
curl https://api.github.com/repos/UnbreakableMJ/Understand-Anything
```

**After:**
```bash
eza -lah --git ~/projects
rg "TODO" src/
fd -e rs --size +10k
dust -d 1
procs rustc
xh https://api.github.com/repos/UnbreakableMJ/Understand-Anything
```

---

## §5 — When NOT to Substitute

- **Explicit user request** for the legacy tool ("show me the raw `grep` command").
- **Portable scripts** the user will run on systems without the Rust stack
  installed (document the alternative as a comment but keep the portable form).
- **Compatibility-critical pipelines** where a specific tool's exact output
  format is required by downstream tooling.
- **The legacy tool is already the Spacecraft Software-sanctioned choice** for that slot
  (see §3 rows marked ⚠️ — `curl`, `nix`, `ffmpeg`, `mpv`, `yt-dlp`, etc.).

In these cases, add an inline note: `# Rust alternative: <tool> — see references/<tool>.md`.

---

## §6 — Reference File Format

Each file in `references/` follows this structure:

```markdown
# <tool>

**Replaces:** <legacy tool(s)> | **Language:** 🦀/⚡/🐹/🐍/(λ)/⚠️ | **Install:** <package hint>

## Purpose
<One paragraph — what it does and when to reach for it.>

## Key flags
| Flag | Meaning |
|------|---------|

## Examples
1. <short task description>
   `<command>`
2. …

## Gotchas
- <edge cases, non-POSIX behaviour, config requirements, etc.>
```

---

## §7 — Attribution

Command syntax, flags, and example patterns in `references/` are adapted
from [tldr-pages](https://tldr.sh) (CC-BY-4.0) and each tool's own official
documentation. See `references/ATTRIBUTION.md` for per-tool sourcing.

---

## §8 — Spacecraft Software Compliance Note

This skill itself is a Spacecraft Software artifact and conforms to the relevant parts
of The Steelbore Standard (see `spacecraft-standard` skill):

- **§4** GPL-3.0-or-later license declared in frontmatter
- **§12** ISO 8601 dates used throughout
- Naming: `spacecraft-cli-preference` — functional prefix, not a codename
  (aerospace/sci-fi/AI naming §2 applies to new project/module identifiers;
  §2.2 explicitly exempts skill IDs)

---

*— Built by Spacecraft Software —*
