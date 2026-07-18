---
name: spacecraft-cli-standard
description: >
  Enforces the Spacecraft Software Dual-Mode Self-Documenting CLI Standard (v1.0.0)
  on every CLI the AI writes or reviews. ALWAYS consult when working on ANY
  command-line interface — new binaries, sub-commands, clap wiring, --json or
  --format output, exit codes, structured errors to stderr, ratatui TUI,
  schema introspection, MCP server surface, or CLI tests. Triggers include
  noun-verb command design, TTY detection, NO_COLOR/FORCE_COLOR, JSON output
  envelopes, ISO 8601 UTC timestamps, UTF-8 encoding, POSIX compatibility,
  Nushell/PowerShell 7+/Ion/Bash output, and agent env vars (AI_AGENT, AGENT,
  CI, CLAUDECODE, CURSOR_AGENT, GEMINI_CLI). If a Spacecraft Software project
  (Ferrocast, Caliper, Craton, Ironway, Zamak, Bravais, Mawaqit, Flux, or any
  future project) has a CLI component, this skill governs it — even when the
  user does not explicitly mention the Standard. Use proactively the moment
  CLI code appears on the horizon.
license: GPL-3.0-or-later
maintainer: Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
website: https://Construct.SpacecraftSoftware.org/
---

# Spacecraft Software CLI Standard — Dual-Mode Self-Documenting CLI Framework

**Version:** 1.0.0 | **Spec Date:** 2026-04-10 | **Author:** Mohamed Hammad
**Maintainer:** Mohamed Hammad | **Contact:** [Mohamed.Hammad@SpacecraftSoftware.org](mailto:Mohamed.Hammad@SpacecraftSoftware.org)
**Copyright:** (C) 2026 Mohamed Hammad | **License:** GPL-3.0-or-later
**Website:** [https://Construct.SpacecraftSoftware.org/](https://Construct.SpacecraftSoftware.org/) | **Source Spec:** Spacecraft Software Dual-Mode Self-Documenting CLI Standard (v1.0.0)

This skill encodes the CLI Standard so every CLI the AI writes for a
Spacecraft Software project ships with two co-equal output personalities: a
**human-oriented mode** for interactive terminals (color, tables, TUI) and
an **agent-native machine-readable mode** for LLM agents, automation
pipelines, and structured-data shells.

The Standard applies to **every** Spacecraft Software CLI binary and sub-command:
Ferrocast, Caliper, Craton, Ironway, Zamak, Bravais, Mawaqit, Flux, and every
future project exposing a command line. Prior art includes Anthropic's `ant`
CLI (auto-TTY detection, `--format explore`, `--format json/yaml/jsonl`),
Google's `gws` (schema + MCP bridge), GitHub's `gh`, and `kubectl` — this
skill generalizes their shared patterns into a portable, shell-agnostic,
agent-agnostic framework.

---

## §1 — The Non-Negotiables (BLOCKER severity)

Violation of any item below blocks shipping. No exceptions.

| # | Rule | Enforcement |
|---|------|-------------|
| 1 | **ISO 8601 + UTC timestamps** everywhere | All stored, transmitted, logged, and committed timestamps MUST be `YYYY-MM-DDTHH:MM:SSZ` — the `Z` suffix is mandatory, not optional. Offset notation (`+03:00`, `-05:00`) is forbidden in data. Local time is forbidden in all machine-readable output. `--local-time` flag is explicitly prohibited. Durations use ISO 8601 duration format (`PT1H30M`). See Spacecraft Software Standard §12.2. |
| 2 | **UTF-8 without BOM** for all output | stdout, stderr, file writes. On Windows, set console output code page to 65001 at startup. Never rely on system locale. |
| 3 | **POSIX-first default output** | No-flag output must parse correctly in POSIX sh using only grep/awk/cut/sed/tr. No Bash-isms, no Nushell-isms, no PowerShell-isms in default mode. |
| 4 | **Metric + 24-hour** | SI units only. No AM/PM. No imperial units. |
| 5 | **GPL-3.0-or-later + SPDX header** | Every source file. |
| 6 | **`--json` on every data-returning command** | With a stable schema. Breaking schema changes require a major version bump + deprecation cycle. JSON output is a superset of text output. |
| 7 | **stdout = data only, stderr = everything else** | No progress indicators, banners, log lines, or ANSI escapes mixed into stdout. Ever. |
| 8 | **Structured errors on stderr in machine mode** | JSON object with `error.{code, exit_code, message, hint, timestamp, command, docs_url}`. See `references/exit-codes-errors.md`. |

---

## §2 — The Eight Rules of Agent-Friendly CLI Design

Read the mapped reference file before implementing that rule; these
one-liners are the mental anchor, not the spec.

1. **Structured output is not optional** — every data command MUST support `--json`; `--format` accepts `json` (default structured), `jsonl`, `yaml`, `csv`, `explore`. JSON is a superset of text. [`references/output-modes.md`]
2. **Exit codes are the agent's control flow** — use the canonical map (§4). Non-zero exit + JSON error object to stderr. [`references/exit-codes-errors.md`]
3. **Make commands idempotent** — same invocation twice, same result. Prefer `ensure` / `apply` / `sync` over `create` / `delete`. Every destructive command supports `--dry-run`. [`references/validation-safety.md`]
4. **Self-documenting beats external docs** — every tool ships `<tool> schema` and `<tool> describe` sub-commands, plus `CLAUDE.md`, `AGENTS.md`, `SKILL.md`, `CONTRIBUTING.md` at repo root. [`references/schema-introspection.md`]
5. **Structured errors, not narrative messages** — JSON error object on stderr in machine mode. The `hint` field carries the exact command to fix the error ("tips thinking"). [`references/exit-codes-errors.md`]
6. **Design for composability** — stdout is pure data payload. `--fields` limits payload for token budgets. `jsonl` for streaming. [`references/output-modes.md`]
7. **Consistent noun-verb structure** — `<tool> <noun-singular> <verb>`. Standard verbs: `list`, `get`, `create`, `update`, `delete`, `apply`, `sync`, `describe`, `schema`. Global flags identical across all Spacecraft Software CLIs. [`references/schema-introspection.md`]
8. **Understand when MCP beats CLI** — tools with >10 sub-commands SHOULD also expose an MCP server via `<tool> mcp`. Lazy-load schemas to avoid context bloat. [`references/mcp-surface.md`]

---

## §3 — Global Flags (Identical Across All Spacecraft Software CLIs)

Every Spacecraft Software CLI MUST accept these flags with identical name, type, and
behavior. Divergent implementation is a BLOCKER.

| Flag | Effect |
|------|--------|
| `--json` | Alias for `--format json`. |
| `--format <fmt>` | One of: `json`, `jsonl`, `yaml`, `csv`, `explore`. |
| `--fields <f1,f2,...>` | Restrict output to listed fields. Reduces token cost. |
| `--dry-run` | Emit action plan as JSON; no side effects. MUST be accepted by every write / delete / destructive command. |
| `--verbose` / `-v` | Diagnostic output to stderr. |
| `--quiet` / `-q` | Suppress non-error stderr. |
| `--no-color` | Disable ANSI color. Equivalent to `--color=never`. |
| `--color <when>` | `never` / `always` / `auto`. |
| `--help` / `-h` | Help text with ≥2 examples per sub-command (one demonstrating `--json`). Footer MUST include project URL (e.g., `https://<ProjectName>.SpacecraftSoftware.org/`) and maintainer name. |
| `--version` | Version + build info. MUST include maintainer line: `Maintained by Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>` and project URL. In `--json` mode, include `"maintainer"` and `"website"` keys in the metadata envelope. |
| `--absolute-time` | Disable relative-time rendering in human mode. Data is always stored and transmitted as ISO 8601 UTC with mandatory `Z` suffix; relative and local-time display are render-only and never appear in `--json` output. |
| `--print0` / `-0` | NUL-delimited output for filename-safe piping through `xargs -0`. |
| `--yes` / `--force` | Skip confirmation in non-TTY mode. |

Human-mode aliases are permitted (`ls` for `list`, `rm` for `delete`) but
MUST NOT appear in `--json` output, `schema`, or `describe`.

---

## §4 — Canonical Exit Code Map

| Code | Meaning | Agent behavior |
|------|---------|----------------|
| 0 | Success | Proceed; parse stdout |
| 1 | General failure | Log; may retry with different params |
| 2 | Usage error (bad arguments) | Do NOT retry; fix invocation syntax |
| 3 | Resource not found | Adjust target; do not retry same query |
| 4 | Permission denied | Escalate to user or acquire credentials |
| 5 | Conflict (already exists) | Use idempotent alternative or resolve conflict |
| 6–125 | Tool-specific | MUST be documented in `<tool> schema` output |
| 126 | Command not executable (POSIX reserved) | Check PATH/permissions |
| 127 | Command not found (POSIX reserved) | Install dependency |
| 128+N | Fatal signal N (POSIX reserved) | Log crash; do not retry |

Any non-zero exit in machine mode MUST also emit a structured error object
to stderr. Full schema: `references/exit-codes-errors.md`.

---

## §5 — Output Mode Detection Cascade

First matching condition wins:

1. **Explicit flag.** `--format <fmt>` or `--json` → that mode unconditionally.
2. **Agent env var.** `AI_AGENT=1`, `AGENT=1`, or `CI=true` → json mode, no color, no TUI, no interactivity.
3. **TTY.** `isatty(stdout) == true` → human mode with color.
4. **Non-TTY.** stdout piped/redirected → json mode (the `ant` CLI pattern).
5. **Fallback.** → human mode.

`--format explore` has an extra constraint: if `AI_AGENT=1` or `AGENT=1` is
set, the TUI MUST NOT activate — fall back to `--format json` and warn on
stderr. Never trap an agent in an interactive render loop.

Full color precedence (`NO_COLOR`, `FORCE_COLOR`, `CLICOLOR`, `TERM=dumb`)
and machine-mode details: `references/output-modes.md`.

---

## §6 — The JSON Output Envelope

Every `--json` response is a single valid JSON document with this shape:

```json
{
  "metadata": {
    "tool": "caliper",
    "version": "0.3.0",
    "command": "caliper trace list",
    "timestamp": "2026-04-10T14:30:00Z",
    "pagination": { "page": 1, "per_page": 50, "total": 142, "next_token": "abc123" }
  },
  "data": [ ... ]
}
```

- Property names in **snake_case** (canonical). PascalCase aliases MAY be added for PowerShell ergonomics but are not required.
- Numbers as JSON numbers (not strings). Booleans as `true`/`false`. Nulls as JSON `null` (not `""`, not `"N/A"`).
- No trailing commas, no comments, no BOM, no ANSI escapes.
- No log lines interspersed. A single valid JSON document.
- For list commands: `data` is an array of homogeneous records with consistent keys — this maps cleanly to Nushell `table` and PowerShell object arrays.

---

## §7 — When to Read Which Reference File

The `references/` directory expands each topic to full normative detail.
Read before implementing; don't fly blind.

| File | Read when implementing... |
|------|---------------------------|
| `references/output-modes.md` | Human mode rendering, machine mode output, color precedence, Spacecraft Software palette tokens, JSON envelope, metadata wrapper |
| `references/exit-codes-errors.md` | Any error path, structured error schema, "tips thinking" hint pattern, `error.code` enum values |
| `references/schema-introspection.md` | `<tool> schema` (JSON Schema Draft 2020-12), `<tool> describe` manifest, `CLAUDE.md` / `AGENTS.md` / `SKILL.md` / `CONTRIBUTING.md` context files, noun-verb structure |
| `references/shell-compat.md` | Output that must parse in POSIX sh, Bash 5+, Brush, Nushell 0.111+, PowerShell 7.6+, or Ion (RedoxOS) |
| `references/tui-explore.md` | `--format explore` / `-E` TUI mode, ratatui+crossterm, dual CUA+Vim keybindings, alt-screen buffer, search/filter/sort/detail/export |
| `references/validation-safety.md` | File path arguments, string arguments, `--dry-run`, destructive-op confirmation flow, Wizard Fallback pattern, threat model |
| `references/mcp-surface.md` | Tools with >10 sub-commands; implementing `<tool> mcp`, lazy schema loading, stdio/sse/streamable-http transports |
| `references/testing-compliance.md` | CI test suite, compliance matrix (BLOCKER/CRITICAL/MAJOR), cross-shell roundtrip tests, required test categories |
| `references/rust-implementation.md` | Crate choices (clap, serde, chrono/jiff, ratatui, crossterm, rmcp, ...), concrete Rust scaffolds for every section above |

---

## §8 — New-CLI Quick-Start Checklist

When starting a fresh Spacecraft Software CLI, walk this list before writing business
logic. Each step has a reference file to consult.

1. **Workspace layout.** Cargo workspace set up, SPDX headers in every file, `license = "GPL-3.0-or-later"` in every Cargo.toml.
2. **Global flag scaffolding.** Implement every §3 flag before any sub-command. See `references/rust-implementation.md` for the clap skeleton.
3. **Output mode detection.** Wire the §5 cascade into a single `OutputMode` struct shared by every sub-command.
4. **JSON envelope type.** Define `Response<T>` (the `metadata` + `data` wrapper) as a generic. Never let a sub-command serialize bare data.
5. **Exit-code enum.** Single `ExitCode` enum mapping to the §4 table. Return from every sub-command.
6. **Structured error type.** Single `AppError` struct with all `error.*` fields. See `references/exit-codes-errors.md`.
7. **Noun-verb tree.** Draft the full sub-command tree using singular nouns and the standard verb set before implementing any leaf.
8. **`schema` + `describe` sub-commands.** Wire these early; they force introspectability.
9. **Context files.** Add `CLAUDE.md`, `AGENTS.md`, `SKILL.md`, `CONTRIBUTING.md` at repo root on day one.
10. **Test stubs.** Add all categories from `references/testing-compliance.md` (JSON schema validation, exit codes, TTY/non-TTY, agent env, idempotency, input validation, cross-shell, UTF-8) as failing stubs so nothing gets forgotten.

---

## §9 — Compliance Severity Levels

When reviewing existing CLI code, categorize findings by severity. These
come from the CLI Standard §11.2 Compliance Matrix.

- **BLOCKER** — does not ship. Fix before merge.
  Missing ISO 8601 UTC timestamps, BOM in output, wrong exit codes, missing `--json` on a data command, missing `schema` / `describe`, unstructured errors in JSON mode.
- **CRITICAL** — fix this release cycle.
  `NO_COLOR` not honored, missing `--dry-run` on a write command, `AI_AGENT` env var not detected.
- **MAJOR** — fix before next minor release.
  TUI doesn't fall back when stdout is piped, missing `CLAUDE.md` / `AGENTS.md` / `SKILL.md`.

Full matrix + verification methods: `references/testing-compliance.md`.

---

## §10 — Relation to Other Spacecraft Software Skills

- **`spacecraft-standard`** — the master Standard. This skill is subordinate; master wins on conflict.
- **`spacecraft-cli-preference`** — governs which *external* CLI tools to invoke (e.g., `rg` over `grep`). Complementary: that skill picks tools, this one defines how the CLI you're *building* should behave.
- **`spacecraft-cli-shell`** — governs shell syntax (Nushell / Ion / POSIX) in generated commands. Complementary.
- **`rust-guidelines`** — Microsoft Pragmatic Rust Guidelines. Consult alongside `references/rust-implementation.md`.
- **`spacecraft-brand-guidelines`** — source of truth for the six-token color palette (Void Navy, Molten Amber, Steel Blue, Radium Green, Liquid Coolant, Red Oxide).

---

*End of SKILL.md. Full normative spec: Spacecraft Software Dual-Mode
Self-Documenting CLI Standard (v1.0.0), 2026-04-10.*
