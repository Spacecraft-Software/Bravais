# AGENTS.md / CLAUDE.md / SKILL.md Authoring Patterns

Context files are runtime configuration for AI agents, not documentation
for humans. They are loaded into the agent's context window every time
the agent operates in the repository, so every line costs tokens. Write
them with the discipline of a function signature: high information
density, zero filler.

This reference covers what each file is for, what belongs in each, what
does NOT belong, and provides anti-pattern catalogs.

## Table of contents

- §1 — File responsibilities (what each file is for)
- §2 — AGENTS.md: contents and structure
- §3 — CLAUDE.md: how it differs from AGENTS.md
- §4 — SKILL.md: the CLI's own skill manifest
- §5 — CONTRIBUTING.md: human contributor guidance
- §6 — Anti-patterns to avoid
- §7 — Length budgets and format conventions

---

## §1 — File responsibilities

| File | Reader | Lifetime | Authoritative on |
|------|--------|----------|------------------|
| `AGENTS.md` | Generic agents (Codex CLI, Cursor, Aider, OpenCode, Goose) | Loaded each session | Coding conventions, build/test commands, project invariants |
| `CLAUDE.md` | Claude Code | Loaded each session | Same as AGENTS.md, plus Claude-specific tool/skill/MCP context |
| `SKILL.md` | Spacecraft Software Skills, CLI-Anything, `gws`-style skill systems | Loaded by skill loader | The CLI's own capability surface and triggering description |
| `CONTRIBUTING.md` | Human contributors | Read once during onboarding | Dev environment setup, PR conventions |

**Critical principle:** AGENTS.md is for **project-specific** invariants
that an agent cannot infer from the code itself. The Spacecraft Software SFRS rules
are NOT project-specific — they live in `spacecraft-cli-standard` and
`spacecraft-agentic-cli` skills, not in AGENTS.md. Dumping the SFRS into
AGENTS.md duplicates skill content and wastes tokens.

---

## §2 — AGENTS.md contents and structure

### Required sections

```markdown
# AGENTS.md — <project-name>

## Project identity
One paragraph: what this CLI is, who uses it, what role it plays in
Spacecraft Software. Include the noun (Zamak, Ferrocast, Caliper, etc.) and one
sentence on its mission.

## Build, test, lint
Concrete commands the agent runs to verify changes. NOT a tutorial — the
exact commands.

## Architectural invariants
Things the code's structure assumes that aren't visible in any single
file. E.g., "all sub-commands return ExitCode::Success or an AppError
that maps to ExitCode::*"; "the JSON envelope wrapper is the only thing
that serializes to stdout."

## Forbidden patterns
Things that look reasonable but break this codebase. E.g., "do not call
println! directly; use the OutputMode-aware emit() helper"; "do not use
chrono::Local; only chrono::Utc."

## Environment expectations
What the agent can assume is installed. What it must NOT assume.

## Where to look for ___
Pointers to the canonical location of common concerns: where errors are
defined, where the schema sub-command lives, where tests for X are.
```

### Example skeleton (Ferrocast)

```markdown
# AGENTS.md — Ferrocast

## Project identity
Ferrocast is the Rust rewrite of PowerShell, organized as a 16-crate
Cargo workspace. It targets POSIX shell environments first and PowerShell
7+ object-pipeline compatibility second. Part of Project Spacecraft Software.

## Build, test, lint
- Build: `cargo build --workspace --all-features`
- Test: `cargo test --workspace`
- Lint: `cargo clippy --workspace --all-targets -- -D warnings`
- Format check: `cargo fmt --all --check`
- SFRS compliance check: `cargo run -p ferrocast-audit -- check .`

## Architectural invariants
- Every sub-command returns `Result<Response<T>, AppError>`; never bare
  `T` and never raw `eyre::Report` to stdout.
- All timestamps use `jiff::Timestamp`; chrono is forbidden.
- The `OutputMode` is computed once at main entry and threaded through
  every sub-command — never recompute mid-command.

## Forbidden patterns
- `println!` / `eprintln!` direct calls. Use `output::emit_data()` /
  `output::emit_error()` exclusively.
- `chrono::*`. Use `jiff::*`.
- `unwrap()` outside tests. Use `?` with appropriate `AppError`
  conversion.
- Local-time formatting anywhere. UTC only.

## Environment expectations
- Rust toolchain: stable, MSRV 1.85.
- `cargo`, `rustc`, `clippy`, `rustfmt` installed.
- Do NOT assume nightly features.
- Do NOT install crates from outside the workspace lockfile.

## Where to look for ___
- Error types: `crates/ferrocast-error/src/lib.rs`
- Schema sub-command: `crates/ferrocast-cli/src/cmd/schema.rs`
- JSON envelope: `crates/ferrocast-output/src/envelope.rs`
- Output mode detection: `crates/ferrocast-output/src/mode.rs`
- Integration tests: `crates/ferrocast-cli/tests/`
```

---

## §3 — CLAUDE.md: how it differs from AGENTS.md

CLAUDE.md MUST be a strict superset of AGENTS.md. Start by symlinking or
copying AGENTS.md, then add Claude-specific sections:

```markdown
# CLAUDE.md — <project-name>

<!-- All AGENTS.md content above -->

## Skills referenced
- `spacecraft-standard` — master Standard
- `spacecraft-cli-standard` — structural SFRS
- `spacecraft-agentic-cli` — agent-facing UX
- `spacecraft-brand-guidelines` — color palette
- `rust-guidelines` — Microsoft Pragmatic Rust

## MCP servers expected
- `<tool> mcp` — this project's own MCP surface
- (Any others the project expects to coexist with)

## Tool preferences
- Use `rg` over `grep`, `fd` over `find`, `bat` over `cat`. (Aligns with
  spacecraft-cli-preference.)
- Use `cargo nextest` over `cargo test` if available; fall back if not.

## Notes for Claude specifically
- The repository has a `tasks/` directory with TaskMaster MCP task
  definitions. Claude Code uses these as work units.
- Inline TODOs use `// TODO(claude):` to distinguish from human TODOs.
```

The Claude-specific sections matter because Claude Code has features
(skills, MCP, TaskMaster integration) that other agents may not use.
Mentioning them in AGENTS.md would mislead a Codex CLI session into
expecting capabilities it doesn't have.

---

## §4 — SKILL.md: the CLI's own skill manifest

This is **not** the same as a skill in `~/.claude/skills/`. This is the
SKILL.md that ships *inside* the CLI's repository, advertising the CLI's
own surface to skill-aware loaders (CLI-Anything, Google's `gws` skill
system, Anthropic's skill discovery).

```markdown
---
name: ferrocast
description: >
  PowerShell-equivalent shell and CLI tooling, Rust implementation. Use
  when the user wants to invoke pipeline-style operations, manipulate
  structured data with cmdlet-like commands, or interoperate with
  PowerShell 7+ scripts. Subcommands: pipeline, cmdlet, module, host.
license: GPL-3.0-or-later
version: 0.1.0
---

# Ferrocast — capability surface

## Sub-command tree
- `ferrocast pipeline run` — execute a pipeline expression
- `ferrocast cmdlet list` — list available cmdlets
- `ferrocast cmdlet get <name>` — get cmdlet schema
- `ferrocast module list` — list loaded modules
- `ferrocast host info` — runtime host information
- `ferrocast schema [<noun> [<verb>]]` — emit JSON Schema
- `ferrocast describe` — capability manifest
- `ferrocast mcp [--transport stdio|sse]` — MCP server

## Output formats
json (default when piped), jsonl, yaml, csv, explore (TUI)

## Standard global flags
--json, --format, --fields, --dry-run, --verbose, --quiet, --no-color,
--color, --help, --version, --absolute-time, --print0, --yes, --force

## Exit codes
0 success, 1 general failure, 2 usage error, 3 not found,
4 permission denied, 5 conflict, 6–125 tool-specific (see schema output),
126/127/128+N POSIX reserved

## Examples
ferrocast cmdlet list --json
ferrocast pipeline run --expr 'Get-Process | Where-Object CPU -gt 5' --json
ferrocast schema cmdlet get
```

---

## §5 — CONTRIBUTING.md: human contributor guidance

CONTRIBUTING.md is for human contributors; agents should not read it
during normal operation. Standard sections:

- Setup: dev environment, toolchain, optional tools
- Workflow: branching strategy, PR checklist, commit conventions
- Code review: what reviewers look for
- Spacecraft Software Standard compliance: link to spec, audit command
- Reporting bugs / proposing changes

Keep it human-focused. Repeating AGENTS.md content here is fine because
the audiences are different — humans benefit from prose explanations
that would waste agent tokens.

---

## §6 — Anti-patterns to avoid

### Anti-pattern: dumping the SFRS verbatim

**Wrong:**
```markdown
# AGENTS.md

## The Eight Rules
1. Structured output is not optional — every data command MUST support
   --json, --format accepts json (default structured), jsonl, yaml...
[continues for 200 lines]
```

**Why wrong:** the SFRS lives in `spacecraft-cli-standard`. Repeating it
in AGENTS.md duplicates the skill's content and wastes the agent's
context window every session.

**Right:**
```markdown
# AGENTS.md

## Standards compliance
This project follows the Spacecraft Software SFRS v1.0.0. The
`spacecraft-cli-standard` and `spacecraft-agentic-cli` skills are
authoritative on structural and agentic conventions. This file
documents project-specific deviations and supplements only.
```

### Anti-pattern: vague invariants

**Wrong:** "Try to write idiomatic Rust."

**Right:** "Use `?` with `AppError` conversions, never `unwrap()` outside
tests. Use `tracing::*` for logging, never `println!`. Implement
`Display` for all public types."

### Anti-pattern: outdated commands

The agent will run the commands you put in AGENTS.md verbatim. If the
test command changes from `cargo test` to `cargo nextest run`, update
AGENTS.md in the same commit. A stale command in AGENTS.md is worse than
no command — the agent will trust it.

### Anti-pattern: marketing prose

**Wrong:** "Ferrocast is a blazing-fast, cutting-edge, memory-safe..."

**Right:** "Ferrocast is the Rust rewrite of PowerShell, organized as a
16-crate Cargo workspace."

Agents do not respond to marketing language; they respond to facts.

### Anti-pattern: assuming directory layout

**Wrong:** "Tests are in the usual place."

**Right:** "Integration tests are in `crates/<crate>/tests/`. Unit tests
are inline in `#[cfg(test)] mod tests {}` blocks."

---

## §7 — Length budgets and format conventions

| File | Target length | Hard cap |
|------|---------------|----------|
| AGENTS.md | 80–200 lines | 400 lines |
| CLAUDE.md | 100–250 lines | 500 lines |
| SKILL.md | 50–150 lines | 300 lines |
| CONTRIBUTING.md | (no agent-loaded budget) | — |

If AGENTS.md exceeds 400 lines, split topic-specific concerns into
referenced files: `AGENTS.md` → "For build details, see
`docs/agents/build.md`." The split files are loaded only when the agent
needs them, mirroring the skill progressive-disclosure pattern.

### Format conventions

- Use ATX-style headers (`# Heading`), not Setext.
- Use code fences with language tags for runnable commands.
- Use tables for "what / where / when" mappings; use lists for sequences.
- ISO 8601 UTC timestamps in any examples involving dates.
- UTF-8 without BOM. No smart quotes in code blocks.

### What never goes in AGENTS.md

- Implementation details visible from reading the code (function names,
  module structure)
- General-purpose Rust advice (it's in `rust-guidelines`)
- General-purpose Spacecraft Software conventions (in the master Standard skill)
- Marketing copy
- Aspirational descriptions of features that don't exist yet
- Personal preferences not reflected in the code or CI

---

*End of agents-md-authoring.md*
