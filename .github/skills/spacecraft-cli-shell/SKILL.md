---
name: spacecraft-cli-shell
description: >
  Syntax-compliance guard for shell commands. Companion to spacecraft-cli-preference
  (which picks the tool; this one checks the syntax around it). ALWAYS consult the
  first time in a conversation an agent is about to run, write, or suggest a shell
  command — one-liners, scripts, `.nu`/`.ion`/`.ps1`/`.sh` files, CI blocks, README
  snippets, docs. Also consult whenever the user mentions Nushell, Ion, Brush,
  PowerShell, ash, Redox, POSIX, bashisms, shell portability, or a `$SHELL`.
  Measures the host rather than guessing, and targets whichever shell will
  actually execute the command: agent-run goes to the agent's own shell,
  user-run to their login shell, a file to its shebang. Blocks Bash-only
  patterns that silently break elsewhere (`[[ ]]`, `(( ))`, `<(...)`,
  `${var^^}`, Bash arrays, `function`, `source`) and routes to the correct
  per-shell reference. Syntax priority — POSIX sh first, then shell-native
  (PowerShell or Ion or Nushell or ash) where POSIX diverges, Bash last.
license: GPL-3.0-or-later
maintainer: Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
website: https://Construct.SpacecraftSoftware.org/
---

# Spacecraft Software CLI Shell — POSIX-First, Avoid Bashisms

**Maintainer:** Mohamed Hammad | **Contact:** [Mohamed.Hammad@SpacecraftSoftware.org](mailto:Mohamed.Hammad@SpacecraftSoftware.org)
**Copyright:** (C) 2026 Mohamed Hammad & Spacecraft Software | **License:** GPL-3.0-or-later
**Website:** [https://Construct.SpacecraftSoftware.org/](https://Construct.SpacecraftSoftware.org/)

**Default rule: write POSIX. Avoid bashisms.** POSIX sh is the only syntax family that survives the trip across every shell this skill cares about — Bash, dash, ash, zsh, plus the non-POSIX targets (Nushell, Ion, PowerShell) where bashisms simply don't parse. Reach for shell-native syntax only inside `.nu`, `.ion`, or `.ps1` files. Reach for Bash extensions (`[[ ]]`, `(( ))`, arrays, `${var^^}`, `<( )`, `&>`, `$RANDOM`) **never as a first choice** — only when POSIX cannot express the operation *and* the target is confirmed Bash.

Sibling skill to `spacecraft-cli-preference`. That skill decides **which tool** to run (`rg` over `grep`, `eza` over `ls`); this skill makes sure the **syntax around it** parses in the target shell.

Four non-Bash shells matter most here: **Nushell** (Mohamed's primary interactive + Bravais/Spacecraft Software default), **Ion** (Redox default, secondary), **PowerShell** (Windows-first, cross-platform), and **ash** (Alpine Linux / embedded POSIX). Nushell and Ion are Rust-written and neither accepts Bash scripts as-is. Bashisms that "always worked" in Bash will fail — sometimes loudly, sometimes silently — in any of them.

**Brush** (Bourne RUsty SHell) is a fifth Rust shell, but it sits in the *Bash family*: unlike Nushell and Ion, it is built to accept POSIX and Bash syntax, so for this skill's purposes **treat Brush as Bash** — write POSIX first, and confirm any exotic Bash feature against Brush's still-maturing compatibility matrix. The Steelbore Standard §7 names the four first-class shell environments as **Nushell, Ion, Brush, and Bash**; this skill additionally guards PowerShell and ash because they show up as real operational targets. See `references/brush.md` for the Brush-vs-Bash gaps.

## When to consult

- **First shell command in a conversation** — always, regardless of how trivial it looks.
- Any time work involves `.nu`, `.ion`, `.ps1`, or `.sh` files (reading, writing, editing).
- Any CI block, Makefile/`justfile` recipe, README snippet, or doc example containing shell.
- Any time the user names a shell (Nushell, Ion, Brush, PowerShell, ash, bash, dash, zsh) or says "POSIX", "portable script", "bashism".

After the first consult in a session, trust the decision and proceed — don't re-load on every command unless the target shell changes or a new script file is opened. The same applies to Step 0's host probe: measure once, cache, reuse.

## Step 0 — Measure the host, don't guess it

On a local machine the shell landscape is **observable**. Measure it once at
the start of a session, cache the result, and skip the guesswork the signals
below would otherwise need:

```sh
getent passwd "$(id -un)" | awk -F: '{print $NF}'   # the USER's login shell
ps -p "$$" -o comm=; echo "${BASH_VERSION:-}"       # the AGENT's own shell
readlink -f /bin/sh                                 # what `#!/bin/sh` really runs
for s in nu ion brush pwsh ash dash bash zsh; do
  command -v "$s" >/dev/null 2>&1 && echo "have $s" || echo "MISSING $s"
done
```

Use `ps -p "$$" -o comm=` rather than `echo "$0"` — inside a script `$0` is the
*script's* path, not the interpreter's, so it answers the wrong question.

Because this is measurement rather than inference it counts as **evidence** —
commit to it silently. No "assuming Nushell…" announcement is needed once the
probe has answered.

Two results routinely surprise:

- **The user's login shell and the agent's shell are usually different.** A
  host whose `passwd` entry says `nu` still hands the agent a Bash tool.
  Neither fact implies the other.
- **`/bin/sh` is not necessarily a POSIX shell.** It is bash on many systems.
  That matters for verification — see *Verifying portability* below.

Full probe, per-result interpretation, and the local gotchas:
**[references/local-shells.md](references/local-shells.md)**.

## Step 0.5 — Route by who will execute the command

The target shell is decided by **the executor**, not by ambient project
context. Three paths, three answers:

| Path | Target shell | Syntax to emit |
|---|---|---|
| The **agent** runs it (Bash tool) | the agent's own shell — Bash | POSIX; Bash accepts all of it |
| The **user** runs it (`!` prefix, or pasted into their terminal) | their **login shell** (Step 0) | Whatever that shell takes — POSIX is *wrong* if it's Nushell or Ion |
| It's **written to a file** | the shebang / extension | Step 1 signals 1–2, unchanged |

Getting this backwards is the classic failure: writing `TZ=UTC cmd` into a
hand-off for a Nushell user (invalid there), or wrapping the agent's own
commands in `^bash -c '…'` when the agent is already running Bash (pure
overhead).

**Hand-off syntax — stay in the common subset.** Plain `cmd --flags args`
parses identically in Bash, Nushell, and Ion, and covers the vast majority of
hand-offs. Where the shells genuinely diverge, give the form for the user's
actual shell — or both, when it isn't confirmed:

| Construct | Bash / POSIX | Nushell |
|---|---|---|
| inline env var | `TZ=UTC git log` | `^bash -c 'TZ=UTC git log'` or `with-env { TZ: "UTC" } { … }` |
| command substitution | `$(cmd)` | `(cmd)` |
| shadowed external | `zip -qr a.zip d/` | `^zip -qr a.zip d/` |

`references/nushell.md` documents `^` and `with-env` in full — consult it
rather than reconstructing the rules here.

## Step 1 — Detect the target shell

**Auto-detect first, ask only as last resort.** Try these signals in order, stop at the first that resolves. The goal is to never pause the conversation for a question that context already answers.

Signals 1–3 are **direct evidence** — commit silently, proceed.
Signal 4 is **inference** — commit *and announce the assumption in one line* so the user can correct if wrong.
Signal 5 is the only one that asks.

1. **File extension** *(evidence)* — `.nu` → Nushell; `.ion` → Ion; `.ps1` / `.psm1` / `.psd1` → PowerShell; `.sh` → POSIX; `.bash` → Bash. (Brush has no distinct extension — it runs `.sh`/`.bash` files; identify it by shebang or explicit mention.)
2. **Shebang** *(evidence)* — `#!/usr/bin/env nu` → Nushell; `#!/usr/bin/env ion` → Ion; `#!/usr/bin/env brush` → Brush (Bash-family); `#!/usr/bin/env pwsh` or `#!/usr/bin/env powershell` → PowerShell; `#!/bin/ash` → ash; `#!/bin/sh` or `#!/usr/bin/env sh` → POSIX; `#!/bin/bash` → Bash.
3. **Explicit user mention** *(evidence)* — "in Nushell", "my Ion script", "Brush", "PowerShell", "in ash", "POSIX-compatible", "bash one-liner".
4. **Environmental inference** *(announce)* — only for what Step 0 could not measure. State the assumption in a short sentence, e.g. "Assuming Nushell (your primary) — say the word for Ion, PowerShell, or POSIX.":
   - `bash_tool` in an agent environment runs **Bash**. Commands executed here and now should target **POSIX** (Bash accepts all POSIX). Step 0's `$0` / `$BASH_VERSION` probe confirms this directly — prefer the measurement.
   - "My shell" / a command the *user* will run → their **login shell** as measured in Step 0, not the project's ambient default. Absent a measurement, Spacecraft Software / Bravais context implies **Nushell** (Mohamed's primary), with **Ion** a reasonable secondary since he runs both.
   - Redox OS context → **Ion**.
   - Windows-first or `.ps1` context → **PowerShell**.
   - Alpine Linux / Docker / embedded context → **ash** (POSIX-compliant; avoid bashisms).
   - GitHub Actions `run:` block without `shell:` override → **Bash** on Linux/macOS runners, `pwsh` on Windows; default to POSIX-compliant for cross-platform.
5. **Still ambiguous** *(ask)* — one short question, commit to the answer for the rest of the conversation.

## Step 2 — Apply the priority order

Within the detected shell, emit constructs in this preference order:

| Rank | Syntax family | Use when |
|------|---------------|----------|
| 1 | **POSIX sh** | The target shell accepts POSIX (sh, dash, Bash, zsh, ash, partially Ion). Maximally portable. |
| 2 | **Shell-native** (PowerShell / Ion / Nushell / ash) | Target is a shell that diverges from or rejects POSIX. Use PowerShell syntax for `.ps1`; Ion syntax when target is Ion; Nushell syntax for `.nu`; ash is POSIX-compatible — stay at rank 1 unless an ash-specific extension is explicitly needed. |
| 3 | **Bash extensions** | Last resort. Only when the target is confirmed Bash (or Brush) *and* no POSIX or native equivalent works. Under Brush, prefer the widely-implemented subset (`[[ ]]`, indexed arrays, `local`) over exotic features (`declare -A`, `mapfile`, `$PIPESTATUS`) that its compatibility matrix may not yet cover — see `references/brush.md`. |

"POSIX first" means *prefer constructs that happen to be both POSIX and valid in the target shell* — not *write POSIX into a `.nu` file*. Nushell scripts get Nushell syntax; Ion scripts get Ion syntax; PowerShell scripts get PowerShell syntax; the POSIX preference applies to sh / bash / dash / zsh / ash targets and to any portability crossroads.

**When the target is Bash, still write POSIX.** Bash accepts every POSIX construct, so a Bash target is not a license to reach for `[[ ]]`, `(( ))`, arrays, or `${var^^}`. Stay at rank 1 by default; drop to rank 3 only when POSIX genuinely cannot express the operation (e.g., `$PIPESTATUS`, process substitution, `shopt -s globstar`).

**When you do use a rank-3 Bash extension, announce it.** One short inline note is enough: "Using `$PIPESTATUS` here — Bash-only; no POSIX equivalent." This makes the deviation auditable and gives the user a chance to request a rewrite or accept the trade-off.

## Step 3 — Load the right reference before emitting

Once the target is known, read the matching file **before** writing the command. These files carry the gotchas — variable syntax, string interpolation, redirection, command substitution — that this SKILL.md deliberately does not duplicate.

- **Nushell** → `references/nushell.md`
- **Ion** → `references/ion.md`
- **Brush** (Bash-family Rust shell) → `references/brush.md` (then `references/posix-safe.md` for the syntax itself — Brush accepts POSIX)
- **PowerShell** → `references/powershell.md`
- **ash** → `references/ash.md`
- **POSIX sh / dash / bash-in-POSIX-mode** → `references/posix-safe.md`
- **Bashism translation** (when converting an existing Bash snippet to any other target) → `references/bashisms.md`
- **Local execution context** (host probe, executor routing, the `/bin/sh` trap, non-interactive gotchas) → `references/local-shells.md`

## Step 4 — Confirm the interpreter exists before suggesting a run

Emitting syntax for a shell is free; **running** it needs that shell installed.
Step 0's `command -v` sweep already answered this — check it before telling the
user to execute a `.nu`, `.ion`, `.ps1`, or ash script. `ash`, `dash`, and
`zsh` are absent from many otherwise well-equipped hosts.

When the interpreter is missing, provisioning is **`spacecraft-missing-pkg`**'s
job, not this skill's — and an ephemeral run needs no install at all:

```sh
nix run nixpkgs#dash -- script.sh
```

Writing a `.ion` file for a host without `ion` is still perfectly valid; only
the instruction to *run* it needs the gate.

## Verifying portability

**A script running locally does not prove it is POSIX.** `/bin/sh` is bash on
many systems (check with `readlink -f /bin/sh`), and bash silently accepts
every bashism this skill warns about. "It ran fine" is the single most
misleading signal available — the check most likely to be trusted is exactly
the one that passes everything.

Verify with a tool that actually knows the POSIX subset. Neither is commonly
installed, so run them ephemerally (see `spacecraft-missing-pkg`):

```sh
nix run nixpkgs#shellcheck -- -s sh script.sh   # flags bashisms statically
nix run nixpkgs#dash -- script.sh               # rejects what bash tolerates
```

Both are also available through `guix shell shellcheck -- …` and the other
provisioners in that skill's Band A.

## The agent's shell is non-interactive

The Bash tool's shell is non-interactive and has no TTY, with consequences
that masquerade as syntax errors:

- **No rc files are sourced.** `.bashrc`, `.profile`, and `config.nu` are not
  read, so the user's aliases and functions **do not exist** for the agent. A
  command that works when the user types it can fail for the agent for this
  reason alone — check it before debugging the syntax.
- **No TTY.** `read`, password prompts, pagers, job control, and full-screen
  programs hang or misbehave. Pass non-interactive flags, or hand the command
  to the user.
- **`$SHELL` describes the harness, not the login shell.** Use the `passwd`
  probe in Step 0 for the latter.

## Top bashisms that break silently in Nushell, Ion, PowerShell, and ash

These are the high-frequency offenders. Catching them up front saves a reference-file lookup:

- **`[[ cond ]]`** — Bash-only. Use `test` / `[ ]` in POSIX, `exists`/`test` in Ion, `if $var == ... { }` in Nushell.
- **`(( arith ))`** — Bash-only. POSIX: `$(( ... ))`. Ion: `let a += 1` style arithmetic on `let`. Nushell: direct expressions like `$x + 1`.
- **`${var^^}` / `${var,,}` / `${var//pat/rep}`** — Bash-only. No portable equivalent; use `tr` / `sed` (POSIX), Ion string methods (`$upper(var)`, `$replace(var ...)`), or Nushell (`$var | str upcase`, `$var | str replace ...`).
- **`arr=(a b c)` with `${arr[@]}`** — Bash-only array syntax. Ion: `let arr = [a b c]`, expand with `@arr`. Nushell: `let arr = [a b c]`, expand with `$arr`.
- **`<(cmd)` process substitution** — Bash/zsh only. Not in POSIX, Ion, or Nushell. Use a pipe or a tempfile instead.
- **`function name { ... }`** — Bash syntax. POSIX: `name() { ... }`. Ion: `fn name; ...; end`. Nushell: `def name [] { ... }`.
- **`&>file`** — Bash. POSIX: `>file 2>&1`. Ion supports `&>`. Nushell: `out+err> file`.
- **`source file`** — Bash. POSIX: `. file`. Ion and Nushell both accept `source`.
- **`$RANDOM`, `$SECONDS`, `$LINENO`** — Bash-only specials. Use `shuf -i`, `date +%s`, or shell-native equivalents.

Full table: `references/bashisms.md`.

## Steelbore Standard Requirements (Shell Scripts)

When writing Spacecraft Software shell script files, these rules from
[The Steelbore Standard](../spacecraft-standard-constitution/SKILL.md) apply.

### §4 — SPDX License Header (mandatory)

Every shell script file that is a **source artifact** (`.sh`, `.ps1`, `.nu`, `.ion` —
not a one-liner, README snippet, or `--help` doc example) must include the SPDX
header as the first comment, immediately after the shebang (if present):

```sh
# SPDX-License-Identifier: GPL-3.0-or-later
```

All four shells use `#` for comments, so the syntax is identical across Bash/POSIX,
PowerShell, Nushell, and Ion. Inline scripts passed via `--run` or `-c` flags are
exempt; named script files are not.

### §6.1 — POSIX Compliance

CLI tools, daemons, and system utilities must be POSIX-compliant. Platform-specific
extensions must go behind feature flags and must not be required for core
functionality. This skill's rank-1 POSIX-first priority order directly enforces §6.1.

### §7 — Shell Environment (v1.22)

The Standard names four first-class shell environments — **Nushell, Ion, Brush,
and Bash** — and §7.1 mandates POSIX-compatible scripts by default, Nushell/Ion
native variants where shell-native idioms are required, and **no Bashisms in
shared scripts**. This skill *is* the operational enforcement of §7.1: the
detect → POSIX-first → announce-the-bashism workflow above keeps shared scripts
portable across all four. Brush, being Bash-compatible, runs the POSIX default
unchanged (`references/brush.md`).

---

## Handoff

This skill stops at syntax. Three skills divide the work and none duplicates
another:

| Question | Owner |
|---|---|
| **Which shell** will run this, and does the syntax parse there? | **this skill** |
| **Which tool** should the command use (`grep` → `rg`, `ls` → `eza`)? | `spacecraft-cli-preference` |
| **How do I get** a tool or interpreter that isn't installed? | `spacecraft-missing-pkg` |

`spacecraft-cli-preference` defers to this skill's Step 0.5 for executor
routing rather than restating it. All three are expected to be active
simultaneously.
