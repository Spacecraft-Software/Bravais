# Running the preferred stack on the user's own machine

The §3 mapping table says which tool is *preferred*. This file says whether the
agent can actually **run** it here, and what to do when it can't. Three facts
drive everything below:

1. The preferred tool may not be installed — a substitution that assumes it is
   turns a working command into `command not found`.
2. The agent's shell is non-interactive with **no TTY**, so every full-screen
   tool in the table will hang or garble rather than work.
3. This is a real workstation, so a command that deletes or reconfigures does
   so for keeps.

Provisioning policy lives in `spacecraft-missing-pkg`; shell syntax lives in
`spacecraft-cli-shell`. This file does not restate either.

**This file is written for local-host.** Classify the session first (Step −1,
`execution-context.md`). **disposable-sandbox** needs a positive hosted marker
(`CLAUDE_CODE_REMOTE=true`, or the harness or user stating a hosted sandbox)
with no Nix/Guix, no local-container marker, and no personal login shell; a
container signal alone — a local devcontainer, Codespace, toolbox, distrobox —
is local-host. In a disposable-sandbox fact 3 does not hold for package and
tool installs or scratch state outside the working tree (the repo checkout and
its git history still count — §3), and every probe below describes the
sandbox, not the user. In **no-execution** mode nothing below is run — emit
the preferred form for the user's login shell, always with a one-line
fallback note.

---

## 1. The availability probe

Probe **once per session**, cache the answer, and route by the four-way matrix.
Re-probing before every command is wasted work.

```sh
# POSIX — check a batch at once
for t in eza bat fd rg sd dust procs jaq ouch delta just tokei xh dog; do
  command -v "$t" >/dev/null 2>&1 || echo "absent: $t"
done
```

```nu
# Nushell equivalent
[eza bat fd rg sd dust procs jaq ouch delta just tokei xh dog]
| where {|t| (which $t | is-empty) }
| each {|t| print $"absent: ($t)" }
```

`command -v` **under-reports**. It cannot see Nushell `def`s, Bash functions or
aliases, or binaries in directories missing from the agent's `PATH`
(`~/.nix-profile/bin`, `/etc/profiles/per-user/$USER/bin`, `~/.cargo/bin`, the
Homebrew prefixes). Use `spacecraft-missing-pkg`'s Step 0 checklist before
concluding a tool is genuinely absent.

### The matrix

| Preferred | Legacy | Action | Example |
|---|---|---|---|
| present | — | Substitute | `rg "TODO" src/` |
| present | absent | Substitute — the only option | `jaq '.name' pkg.json` where `jq` was never installed |
| absent | present | Legacy + note | `dig +short example.com A  # preferred: dog` |
| absent | absent | Ephemeral run via `spacecraft-missing-pkg` | `nix run nixpkgs#dog -- example.com A` (local-host) |

In a **disposable-sandbox** the two `absent` rows change: Nix/Guix are not
there, and the sandbox's own manager (`apt`, `pip`, `npm`, `cargo`, `gem`,
`go`) may install the preferred tool without consent — nothing outlives the
session. Prefer `npx` / `uvx` / `pipx run` for a one-shot. Do not assume root.

On local-host: never install a tool just to satisfy a preference. Falling back with a note
costs the user nothing; a durable install costs them disk, drift, and a cleanup
task they didn't ask for.

---

## 2. Tools that need a TTY

Never launch these in the agent's shell. When the goal is **information**, use
the headless alternative. When the goal is **interaction**, hand the command to
the user and let it run in their terminal — a fenced block for their login
shell; in the Claude Code CLI, suggest the `!` prefix.

| Tool | Why it needs a TTY | Headless alternative |
|---|---|---|
| `bottom` (`btm`) | Live full-screen monitor | `procs` for processes; `dust` for disk |
| `dua i` | Interactive navigator | `dua PATHS…` (non-interactive summary) |
| `gitui` | Full-screen Git UI | `git` / `jj` CLI |
| `yazi`, `broot`, `superfile` | File-manager UIs | `fd`, `eza`; `broot --cmd` for scripted queries |
| `trip` (Trippy) | Live traceroute TUI | `trip --mode report` |
| `gping` | Live latency graph | `ping` |
| `atuin` (search UI) | Full-screen history search | `atuin search <query>` |
| `zellij` | Terminal multiplexer | — hand off |
| `kmon` | Kernel-module TUI | `lsmod` / `modinfo` |
| `impala` | Wi-Fi TUI | `iwctl` non-interactive subcommands |
| `linutil`, `disktui` | Menu-driven system TUIs | — hand off |
| `hx`, `amp`, `rsvim`, `msedit`, `kilo` | Editors | Edit the file directly with the agent's own file tools |
| `iamb`, `rumatui`, `disrust`, `rivetui` | Chat TUIs | `matrix-commander-rs` for scripted Matrix |
| `ncspot`, `termusic`, `radio-browser` | Media TUIs | — hand off |
| `t-rec` | Records a terminal | — hand off |
| `viu` | Sixel/kitty graphics | — hand off; the transcript can't render it |
| `claude`, `aichat`, `gemini`, `codex`, `grok`, `kimi`, `kiro`, `opencode`, `minimax` | Interactive agent REPLs | Their own non-interactive/`-p` flags where documented; otherwise hand off |

Hand-off form in the Claude Code CLI:

```
! gitui
! zellij attach
```

Everywhere else — Claude Code on the web, hosted chat, other harnesses — `!`
does not exist; give the plain command in a fenced block for the user to run.

A tool being TTY-class does **not** demote it in §3. For a command the *user*
will run, `gitui` is still the preferred answer to "show me git interactively".

---

## 3. Destructive and system-mutating tools

Say what will change, then wait. Two entries deserve special care because their
destructive behaviour is the *default*, not an opt-in:

| Tool | What it does | Safer form |
|---|---|---|
| **`kondo`** | Deletes `target/`, `node_modules/`, `build/`, `dist/`, … | Run with no flags to **list** first; `-a`/`--all` deletes with no confirmation. Never pass `-a` unprompted. |
| **`fclones`** | `fclones remove` deletes duplicate files | Stop at `fclones group` and show the report |
| `gptman`, `disktui` | Edit partition tables | Never run unprompted — data loss is total. Hand off. |
| `topgrade` | Updates the whole system across every manager | Hand off; on a declarative host it is the wrong tool entirely |
| `paru`, `omni`, `zap`, `am` | Install packages | Route through `spacecraft-missing-pkg` |
| `rustup`, `cargo-update` | Install/replace toolchains and binaries | Durable — propose, don't run |
| `nmstate` (`nmstatectl`) | Applies network state | Can drop the connection you're working over. Hand off. |
| `lanzaboote` | Secure Boot / bootloader | Never. Hand off. |
| `greetd`, `lemurs`, `tuigreet` | Login daemon / display manager | Misconfiguration locks the user out. Hand off. |
| `xremap` | Remaps input devices, runs as a daemon | Hand off |
| `iwd` | Wi-Fi daemon control | Can drop connectivity. Hand off. |
| `dotter` | Deploys dotfiles over existing files | Propose with the file list; `--dry-run` first |
| `podman` | Runs containers, writes images and volumes | Read-only subcommands (`ps`, `images`, `inspect`) are fine; `run`/`build`/`rm` are durable |
| **`sudo-rs`** | Privilege escalation | **Never run.** Same rule as `sudo` — hand it off. |

Read-only subcommands of these tools are fine (`paru -Qs`, `podman ps`,
`snap info`, `topgrade --dry-run`). The gate is on state change, not on the
binary's name.

The gate protects **the user's host** and **the user's work**. In a
disposable-sandbox, package and tool installs and scratch state outside the
working tree need no consent. Consent is still required for anything that
leaves the sandbox (push, PR, publish, network write, an edit the user will
commit) and for deleting or overwriting files in the repo checkout or
rewriting git history (`rm -rf`, `git reset --hard`, `git clean -fdx`,
`kondo -a`, `fclones remove`) — the session's uncommitted work is the user's.

---

## 4. Shell-integration tools

These only work once an init line exists in the user's shell config. **Do not
write that line.** Editing `.bashrc`, `.profile`, `config.nu`, or any rc file
is prohibited (`spacecraft-missing-pkg`).

| Tool | Wants to add | Declarative equivalent |
|---|---|---|
| `zoxide` | `zoxide init <shell>` eval | `programs.zoxide.enable = true` |
| `atuin` | `atuin init <shell>` eval | `programs.atuin.enable = true` |
| `starship` | `starship init <shell>` eval | `programs.starship.enable = true` |
| `broot` | `broot --install` writes the `br` function | `programs.broot.enable = true` |
| `gitway` | `gitway --install` sets `core.sshCommand` | Git config via the host's config management, or `GIT_SSH_COMMAND=gitway` for a single invocation |
| `direnv` / `lorri` | `direnv hook` eval | `programs.direnv.enable = true` |

On a host without Home Manager, the equivalent is still the user's own
config-management, not an agent-written rc edit. Propose the change and let the
user apply it — see `spacecraft-missing-pkg`'s declarative band.

In a disposable-sandbox there is no config worth editing — skip it for the
sandbox. If the user wants the tool on their own machine, propose the host
config edit (the table above) as text. For a one-off, in any mode, most of these have a form
that needs no shell integration at all: `zoxide query`, `atuin search`, `broot --cmd`, `GIT_SSH_COMMAND=gitway git …`.

---

## 5. Host-appropriateness for the package rows

The *Package & system management* table in §3 is a menu, not an instruction.
Match the row to the host before quoting it:

| Host | Right answer | Wrong answers from the table |
|---|---|---|
| NixOS / Home Manager / nix-darwin | The host's own config; `nix` for ephemeral runs | `topgrade`, `paru`, `omni`, `zap`, `am` — all install outside the config and drift it |
| Guix System / Guix Home | Manifest or home config; `guix shell` for ephemeral | same as above |
| Arch (non-declarative) | `paru` is genuinely appropriate | — |
| macOS | `brew` | `paru`, `linutil` |
| Unknown / mixed | Ask, or stay ephemeral | anything that installs durably |
| Disposable-sandbox | The sandbox's own manager (`apt`, `pip`, `npm`, `cargo`, …) | Nix/Guix routes (absent); declarative config edits for the sandbox (nothing persists — propose one as text only if the user wants the tool on their own machine) |

Detecting which applies is `spacecraft-missing-pkg`'s Step 1 — don't duplicate
the probe, call it.
