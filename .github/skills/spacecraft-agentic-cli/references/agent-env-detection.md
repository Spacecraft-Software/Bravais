# Agent Environment Detection — Behavioral Cascade

The Spacecraft Software CLI Standard mandates detection of agent-presence
environment variables. This reference specifies the exact cascade,
behavioral adaptations per variable, and concrete Rust / Nushell /
PowerShell implementations.

## Table of contents

- §1 — The detection cascade (priority order)
- §2 — Per-variable behavioral changes
- §3 — Rust implementation pattern
- §4 — Nushell-side detection (when shells invoke the CLI)
- §5 — PowerShell-side detection
- §6 — Telemetry and metadata.invoking_agent
- §7 — Anti-patterns

---

## §1 — The detection cascade (priority order)

The CLI computes its `OutputMode` exactly once at process startup. The
cascade evaluates these signals in order; the first matching signal sets
the mode, but **lower-priority signals still apply their non-conflicting
adaptations**.

```
Priority   Signal                         Effect on mode
─────────  ────────────────────────────── ──────────────────────────────
1 (top)    --format / --json flag         Sets format unconditionally
2          AI_AGENT=1 / AGENT=1           Sets format=json + agent profile
3          CI=true                        Sets format=json + ci profile
4          stdout is not a TTY            Sets format=json (ant pattern)
5 (bot)    stdout is a TTY                Sets format=human

Adaptations applied separately (do NOT short-circuit):
─────────────────────────────────────────────────────────
NO_COLOR=<non-empty>                      Disable ANSI color
FORCE_COLOR=<non-empty>                   Enable ANSI color (overrides NO_COLOR)
CLICOLOR=0                                Disable ANSI color
TERM=dumb                                 Disable color + TUI
CLAUDECODE=1                              Set metadata.invoking_agent="claude-code"
CURSOR_AGENT=1                            Set metadata.invoking_agent="cursor"
GEMINI_CLI=1                              Set metadata.invoking_agent="gemini-cli"
TRAE_AI_SHELL_ID=<any>                    Set metadata.invoking_agent="trae"
```

**Key invariant:** once the format is determined, the adaptations layer
on top. A user invoking with `--format human FORCE_COLOR=1 NO_COLOR=1`
still gets human mode (flag wins) with FORCE_COLOR overriding NO_COLOR
(higher precedence per `spacecraft-cli-standard` §5).

---

## §2 — Per-variable behavioral changes

### `AI_AGENT=1` — full agent profile

When detected, simultaneously:

- Output format defaults to json (compact, not pretty-printed)
- ANSI color suppressed unconditionally (NO_COLOR-equivalent)
- TUI suppressed; `--format explore` falls back to json with stderr warning
- Interactive prompts return their default-deny path (as if `--no` was
  passed); destructive ops require `--yes` / `--force`
- Verbosity reduced to "errors only" — successful operations emit just
  their JSON envelope; no progress, no banners
- Pagination defaults to page-size 50 (matches typical context budgets)
- `metadata.invoking_agent` set to "agent" if no more specific signal

### `AGENT=1` — equivalent fallback

`AGENT=1` triggers exactly the same profile as `AI_AGENT=1`. Both are
recognized because the community has not fully converged; supporting both
costs nothing and avoids breaking either ecosystem.

### `CI=true` — CI profile (subtly different)

CI is not necessarily an agent — it may be a deterministic build script.
The CI profile differs from the agent profile in two ways:

- Verbosity stays at "normal" (CI logs benefit from progress info on
  stderr)
- `metadata.invoking_agent` is set to "ci", not "agent"

Otherwise identical: json format, no color, no TUI, non-interactive.

### `CLAUDECODE=1`, `CURSOR_AGENT=1`, `GEMINI_CLI=1`, `TRAE_AI_SHELL_ID`

**Informational only.** These do NOT change the output format on their
own — they require `AI_AGENT=1` or `AGENT=1` to also be set for full
agent profile. They serve only to populate
`metadata.invoking_agent` for telemetry and post-hoc analysis.

If an agent harness sets `CLAUDECODE=1` without setting `AI_AGENT=1`,
that's a harness bug — but the CLI still benefits from recording the
specific agent for diagnostics. Don't over-correct: respect the harness
even when it forgets to set the generic flag.

### `TERM=dumb` — terminal capability signal

A "dumb" terminal cannot render ANSI escapes or alt-screen TUI. This
signal is independent of agent presence — some legitimate human terminals
(serial consoles, basic emulators) report `dumb`. Suppress color and TUI
without inferring agent intent.

### `NO_COLOR` / `FORCE_COLOR` / `CLICOLOR` — color-only

These affect color rendering only, not format selection. Per
no-color.org and the FORCE_COLOR convention:

```
Priority for color:
1. --color=<when> flag             (highest — explicit user intent)
2. FORCE_COLOR=<non-empty>         (force on)
3. NO_COLOR=<non-empty>            (force off)
4. CLICOLOR=0                      (force off)
5. TERM=dumb                       (force off)
6. isatty(stdout)                  (auto: on if TTY)
```

---

## §3 — Rust implementation pattern

The canonical implementation lives in a single struct computed at startup:

```rust
// SPDX-License-Identifier: GPL-3.0-or-later

use std::env;
use std::io::IsTerminal;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OutputFormat {
    Json,
    Jsonl,
    Yaml,
    Csv,
    Explore,
    Human,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AgentProfile {
    None,
    Agent,    // AI_AGENT or AGENT set
    Ci,       // CI set, no agent flag
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InvokingAgent {
    Unknown,
    Agent,        // generic
    Ci,
    ClaudeCode,
    Cursor,
    GeminiCli,
    Trae,
}

#[derive(Debug, Clone, Copy)]
pub struct OutputMode {
    pub format: OutputFormat,
    pub color: bool,
    pub tui_allowed: bool,
    pub interactive: bool,
    pub profile: AgentProfile,
    pub invoking_agent: InvokingAgent,
    pub verbose: bool,
    pub quiet: bool,
}

impl OutputMode {
    pub fn detect(
        format_flag: Option<OutputFormat>,
        color_flag: Option<ColorWhen>,
        verbose_flag: bool,
        quiet_flag: bool,
    ) -> Self {
        // Priority cascade for format
        let env_agent = is_truthy("AI_AGENT") || is_truthy("AGENT");
        let env_ci = env::var("CI").as_deref() == Ok("true");
        let stdout_tty = std::io::stdout().is_terminal();

        let (format, profile) = match format_flag {
            Some(f) => (f, agent_profile(env_agent, env_ci)),
            None if env_agent => (OutputFormat::Json, AgentProfile::Agent),
            None if env_ci => (OutputFormat::Json, AgentProfile::Ci),
            None if !stdout_tty => (OutputFormat::Json, AgentProfile::None),
            None => (OutputFormat::Human, AgentProfile::None),
        };

        // TUI guard: never trap an agent
        let tui_allowed = format == OutputFormat::Explore
            && profile == AgentProfile::None
            && env::var("TERM").as_deref() != Ok("dumb");

        // Color cascade
        let color = compute_color(color_flag, stdout_tty, profile);

        // Interactivity: non-TTY or any non-None profile = non-interactive
        let interactive = stdout_tty
            && profile == AgentProfile::None
            && std::io::stdin().is_terminal();

        // Invoking agent (informational)
        let invoking_agent = detect_invoking_agent(profile);

        // Verbosity adjustment
        let verbose = verbose_flag;
        let quiet = quiet_flag || profile == AgentProfile::Agent;

        Self {
            format, color, tui_allowed, interactive,
            profile, invoking_agent, verbose, quiet,
        }
    }
}

fn is_truthy(var: &str) -> bool {
    matches!(env::var(var).as_deref(), Ok("1") | Ok("true"))
}

fn agent_profile(env_agent: bool, env_ci: bool) -> AgentProfile {
    if env_agent { AgentProfile::Agent }
    else if env_ci { AgentProfile::Ci }
    else { AgentProfile::None }
}

fn detect_invoking_agent(profile: AgentProfile) -> InvokingAgent {
    if is_truthy("CLAUDECODE") { return InvokingAgent::ClaudeCode; }
    if is_truthy("CURSOR_AGENT") { return InvokingAgent::Cursor; }
    if is_truthy("GEMINI_CLI") { return InvokingAgent::GeminiCli; }
    if env::var("TRAE_AI_SHELL_ID").is_ok() { return InvokingAgent::Trae; }
    match profile {
        AgentProfile::Agent => InvokingAgent::Agent,
        AgentProfile::Ci => InvokingAgent::Ci,
        AgentProfile::None => InvokingAgent::Unknown,
    }
}

#[derive(Debug, Clone, Copy)]
pub enum ColorWhen { Always, Never, Auto }

fn compute_color(flag: Option<ColorWhen>, stdout_tty: bool, profile: AgentProfile) -> bool {
    // Flag wins
    if let Some(when) = flag {
        return match when {
            ColorWhen::Always => true,
            ColorWhen::Never => false,
            ColorWhen::Auto => default_color(stdout_tty, profile),
        };
    }
    // FORCE_COLOR overrides everything below
    if env::var("FORCE_COLOR").as_deref().map(|v| !v.is_empty()) == Ok(true) {
        return true;
    }
    // NO_COLOR forces off
    if env::var("NO_COLOR").as_deref().map(|v| !v.is_empty()) == Ok(true) {
        return false;
    }
    if env::var("CLICOLOR").as_deref() == Ok("0") {
        return false;
    }
    if env::var("TERM").as_deref() == Ok("dumb") {
        return false;
    }
    default_color(stdout_tty, profile)
}

fn default_color(stdout_tty: bool, profile: AgentProfile) -> bool {
    profile == AgentProfile::None && stdout_tty
}
```

This computes `OutputMode` once and threads it through every sub-command
via a context struct. Sub-commands NEVER recompute the mode.

---

## §4 — Nushell-side detection (when shells invoke the CLI)

When a Nushell user wants to invoke a Spacecraft Software CLI in agent mode for
testing:

```nushell
# Single invocation
$env.AI_AGENT = "1"
ferrocast cmdlet list

# Scoped to one command
with-env { AI_AGENT: "1" } { ferrocast cmdlet list }

# Confirm cli sees it
with-env { AI_AGENT: "1" } { ferrocast describe } | from json | get invoking_agent
```

Nushell's structured pipeline means the CLI's JSON output integrates
naturally; no special accommodation needed beyond what the CLI already
emits.

---

## §5 — PowerShell-side detection

```powershell
# Single invocation
$env:AI_AGENT = "1"
ferrocast cmdlet list

# Scoped via a script block
& {
    $env:AI_AGENT = "1"
    ferrocast cmdlet list | ConvertFrom-Json
}
```

PowerShell's `$env:VAR` is process-scoped. To set for a single command
invocation only, prepend on the same line in the OS shell or wrap in
`& { ... }` to scope.

---

## §6 — Telemetry and metadata.invoking_agent

The JSON envelope `metadata` field carries `invoking_agent`:

```json
{
  "metadata": {
    "tool": "ferrocast",
    "version": "0.1.0",
    "command": "ferrocast cmdlet list",
    "timestamp": "2026-04-10T14:30:00Z",
    "invoking_agent": "claude-code",
    "pagination": { ... }
  },
  "data": [ ... ]
}
```

The string values are canonical:

| InvokingAgent enum | JSON string |
|--------------------|-------------|
| Agent (generic)    | `"agent"`   |
| Ci                 | `"ci"`      |
| ClaudeCode         | `"claude-code"` |
| Cursor             | `"cursor"`  |
| GeminiCli          | `"gemini-cli"` |
| Trae               | `"trae"`    |
| Unknown            | omitted (use `serde(skip_serializing_if = "Option::is_none")`) |

Telemetry use: aggregate `invoking_agent` across CLI invocations to
understand which agents drive the most usage; tune the agent-facing
surface accordingly.

---

## §7 — Anti-patterns

### Anti-pattern: recomputing per sub-command

Every sub-command must use the OutputMode computed once at process
startup. Do NOT call `detect()` again inside a sub-command — env vars
might have changed (a child process modified them) and the result will
be inconsistent with what was already emitted.

### Anti-pattern: using CLAUDECODE alone as a profile signal

```rust
// WRONG
if is_truthy("CLAUDECODE") {
    profile = AgentProfile::Agent;
}
```

`CLAUDECODE` is informational. Some Claude Code configurations set it
without setting `AI_AGENT` (older versions). Inferring profile from it
breaks on those configurations and contradicts the cascade priority.

### Anti-pattern: trusting environment variables blindly

A malicious upstream may set `AI_AGENT=1` to suppress confirmations
during a privilege escalation. Confirmation defaults still require
`--yes` / `--force` for destructive operations even in agent mode — the
profile reduces friction (no interactive prompt) but must not bypass the
flag-based confirmation.

### Anti-pattern: forgetting `TERM=dumb` for color

A subtle bug: TUIs and color work over SSH to a `xterm-256color` host,
but a serial console reports `TERM=dumb` and gets garbled output. Always
respect `TERM=dumb` for color and TUI suppression even when the agent
profile is None.

---

*End of agent-env-detection.md*
