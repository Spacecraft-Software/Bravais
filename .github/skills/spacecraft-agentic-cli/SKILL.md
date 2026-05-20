---
name: spacecraft-agentic-cli
description: >
  The agent-facing UX layer for Spacecraft Software CLIs — loads alongside
  spacecraft-cli-standard. cli-standard defines structure; this skill
  defines how the CLI must feel to an AI agent. ALWAYS use when
  scaffolding or auditing a Spacecraft Software CLI, writing AGENTS.md or
  CLAUDE.md, designing tips-thinking error hints, implementing agent
  env-var detection (AI_AGENT, AGENT, CI, CLAUDECODE, CURSOR_AGENT,
  GEMINI_CLI), shaping schema output for LLM function-calling
  (Anthropic, OpenAI, Gemini, MCP), defending against prompt injection
  / path traversal / hallucinated args, designing an MCP surface with
  lazy schema loading, or optimizing output for agent token budgets.
  Triggers: "scaffold a CLI", "audit this CLI", "agent-friendly",
  "agent-native", AGENTS.md, CLAUDE.md, MCP server, Claude Code,
  Codex CLI, Cursor, function calling, tips-thinking. Applies to
  every Spacecraft Software project with a CLI (Ferrocast, Caliper, Craton,
  Ironway, Zamak, Bravais, Mawaqit, Flux, future).
license: GPL-3.0-or-later
maintainer: Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
website: https://Construct.SpacecraftSoftware.org/
---

# Spacecraft Software Agentic CLI — Agent-Facing UX Layer

**Version:** 1.0.0 | **Spec Date:** 2026-04-10 | **Author:** Mohamed Hammad
**Maintainer:** Mohamed Hammad | **Contact:** [Mohamed.Hammad@SpacecraftSoftware.org](mailto:Mohamed.Hammad@SpacecraftSoftware.org)
**Copyright:** (C) 2026 Mohamed Hammad | **License:** GPL-3.0-or-later
**Website:** [https://Construct.SpacecraftSoftware.org/](https://Construct.SpacecraftSoftware.org/) | **Source Spec:** Spacecraft Software SFRS v1.0.0 — Dual-Mode Self-Documenting CLI Framework

This skill is the **agent-facing UX specialist** for Spacecraft Software CLIs. The
companion skill `spacecraft-cli-standard` already encodes the structural
SFRS rules (output cascade, exit codes, JSON envelope, schema sub-command,
TUI graceful degradation, shell compat). This skill goes deeper on the
disciplines that determine whether an AI agent can actually *use* the CLI
well in practice:

- AGENTS.md / CLAUDE.md / SKILL.md as first-class repository artifacts
- Tips-thinking error hints that prevent agent hallucination loops
- Agent environment-variable detection cascades (concrete, behavioral)
- `<tool> schema` output that drops directly into LLM function-calling APIs
- MCP lazy-loading discipline so tool definitions don't eat the context window
- Token-economy hygiene (`--fields`, `jsonl`, payload minimization)
- The agent-invoked threat model (prompt injection, hallucinated args)

If the SFRS structural rules conflict with anything in this skill, the SFRS
wins and `spacecraft-cli-standard` is authoritative. This skill never
weakens the structural Standard; it only adds depth to the agent-facing
surfaces.

---

## §1 — The Two-Readers Mental Model

Every Spacecraft Software CLI has two co-equal readers, and every design decision
must satisfy both:

| Reader | Optimizes for | Reads via |
|--------|---------------|-----------|
| **Human in a terminal** | Discoverability, forgiveness, visual scanning | TTY with color, tables, TUI |
| **AI agent paying for tokens** | Predictability, schema stability, token frugality | Pipes, JSON, schema introspection, MCP |

The two readers are **orthogonal, not opposite**. The same command must
serve both — but the human-mode and agent-mode renderings are independently
tuned. When they trade off, the agent-mode rendering optimizes for the
agent's constraints (tokens, parseability, stability), and the human-mode
rendering optimizes for the human's constraints (visual clarity,
discoverability). Never sacrifice one for the other; render twice.

The Mei Park framing applies: **human DX optimizes for discoverability and
forgiveness; agent DX optimizes for predictability and defense-in-depth.**
Hold both lenses simultaneously. When in doubt, ask: "Would an agent
hallucinate here? Would `gh` ship this?"

---

## §2 — AGENTS.md / CLAUDE.md / SKILL.md as First-Class Artifacts

Context files are not documentation — they are **runtime configuration for
agents**. Every Spacecraft Software CLI repository ships these four files at the
repository root, on day one, before business logic:

| File | Primary consumer | Contents |
|------|------------------|----------|
| `AGENTS.md` | Generic agents (Codex CLI, Cursor, Aider, OpenCode) | Coding conventions, test/build commands, forbidden patterns, repository invariants |
| `CLAUDE.md` | Claude Code agent | Same as AGENTS.md, plus Claude Code–specific context (skills referenced, MCP servers expected, tool preferences) |
| `SKILL.md` | Spacecraft Software Skills + CLI-Anything + `gws` | YAML frontmatter (name, description, license) + capability surface for the CLI itself |
| `CONTRIBUTING.md` | Human contributors | Onboarding, dev environment setup, PR conventions |

**Read `references/agents-md-authoring.md` before writing any of these
files.** It contains canonical templates, the difference between AGENTS.md
and CLAUDE.md content, and anti-patterns (e.g., dumping the SFRS verbatim
into AGENTS.md is wrong — agents already have the cli-standard skill;
AGENTS.md is for *project-specific* invariants).

Drop-in templates live in `assets/agents-md.template.md` and
`assets/claude-md.template.md`. Never copy them blindly — each file must be
specialized for the project.

---

## §3 — Tips-Thinking: The Anti-Hallucination Discipline

When a CLI emits a narrative error message ("invalid argument"), an AI
agent has nowhere to go but **hallucinatory exploration**: it guesses
flag names, retries with permuted arguments, and burns tokens until it
either succeeds by accident or exhausts its retry budget. Tips-thinking
inverts this: every error carries the **exact next command** the agent
should run.

The structured error in machine mode (defined by `spacecraft-cli-standard`)
already mandates a `hint` field. This skill specifies *how to author it*:

```json
{
  "error": {
    "code": "NOT_FOUND",
    "exit_code": 3,
    "message": "Repository 'foo/bar' does not exist",
    "hint": "Run 'mytool repo list --json' to see available repositories",
    ...
  }
}
```

**A good hint is a runnable command, not a sentence about the command.**
"Use the list flag" is bad. `mytool repo list --json | jq '.data[].name'`
is good. The agent can directly execute the hint without further
inference.

**Read `references/tips-thinking.md` for the full pattern catalog**,
including:
- Hint formulas for each canonical `error.code` value
- Anti-patterns (vague hints, hints that lie, hints requiring inference)
- Cascading hints (when the hint itself might fail → what to point at next)

Canonical hint strings for every standard error code live in
`assets/error-hint-catalog.json` — use them as starting points.

---

## §4 — Agent Environment Detection (Behavioral Cascade)

`spacecraft-cli-standard` §5 specifies *which* env vars to detect. This
skill specifies *what each one should change* in behavior. The cascade
checks specific variables in priority order and adjusts multiple aspects
simultaneously:

| Variable | Output format | Color | TUI | Interactivity | Verbosity |
|----------|---------------|-------|-----|---------------|-----------|
| `AI_AGENT=1` | json | off | suppressed | non-interactive (--yes implicit) | minimal — failures only |
| `AGENT=1` | json | off | suppressed | non-interactive | minimal |
| `CI=true` | json | off | suppressed | non-interactive | normal |
| `CLAUDECODE=1` | (informational) | (per other rules) | (per other rules) | (per other rules) | (per other rules) |
| `CURSOR_AGENT=1` | (informational) | (per other rules) | (per other rules) | (per other rules) | (per other rules) |
| `GEMINI_CLI=1` | (informational) | (per other rules) | (per other rules) | (per other rules) | (per other rules) |
| `TERM=dumb` | (per other rules) | off | suppressed | (per other rules) | (per other rules) |

`CLAUDECODE`, `CURSOR_AGENT`, and `GEMINI_CLI` are **informational only**.
They MUST NOT override the output format on their own — `AI_AGENT` /
`AGENT` / `CI` handle that. They MAY appear in `metadata.invoking_agent`
in the JSON envelope for telemetry, never as behavioral switches.

`TERM=dumb` deserves special care: a dumb terminal is not necessarily an
agent, but it is incompatible with TUI and ANSI escapes. Suppress those
without inferring agent intent.

**Read `references/agent-env-detection.md`** for concrete Rust detection
code, the canonical priority order, and a Bun-style verbosity adaptation
(suppress passing test logs under `AI_AGENT`; emit only failure traces).

---

## §5 — Schema Output as LLM Function-Calling Surface

The `<tool> schema` sub-command (mandated by `spacecraft-cli-standard` §2
Rule 4) is not just human-readable JSON Schema. It must be **directly
droppable** into the function-calling APIs of the major LLM providers:

| Provider | Format expected | Adapter required |
|----------|-----------------|------------------|
| Anthropic | `tools[].input_schema` (JSON Schema Draft 2020-12) | None — direct paste |
| OpenAI | `tools[].function.parameters` (JSON Schema subset) | Wrap with `{type:"function", function:{name, description, parameters}}` |
| Google Gemini | `tools[].function_declarations[].parameters` | Wrap with `{name, description, parameters}` |
| MCP | `tools[].inputSchema` | None — direct paste |

`<tool> schema --format anthropic|openai|gemini|mcp` SHOULD emit the
provider-specific wrapping. The default (`--format json`) emits the raw
JSON Schema, which equals the Anthropic/MCP format.

**Read `references/llm-tool-calling.md`** for the exact wrapper templates,
required-field rules per provider (e.g., OpenAI requires `description`
on every parameter), and the gotchas (Gemini doesn't support `oneOf`;
OpenAI strict mode disallows `additionalProperties`).

The `examples` array in the schema output is also agent-facing: each
example MUST be a complete, runnable invocation. An agent reads these
to bootstrap its first attempt, so accuracy matters more than density.

---

## §6 — MCP Lazy-Loading Discipline

`spacecraft-cli-standard` §2 Rule 8 mandates an MCP surface for tools with
>10 sub-commands. This skill specifies the **token-economy discipline**
required to make that surface actually useful.

The naive MCP server pattern advertises every tool's full schema on
connection, consuming 50–150 KB of agent context window before the agent
has done anything. The Spacecraft Software pattern advertises only:

- Tool names
- One-line descriptions
- Capability tags (e.g., `read`, `write`, `destructive`)

Full input/output schemas are loaded **only when the agent calls
`tools/get`** for a specific tool. This mirrors:

- Claude Code's deferred MCP schema injection
- Cursor's tool-search approach (reported 46.9% token reduction)
- Anthropic's `ant` lazy tool registry

**Read `references/token-economy.md`** for the lazy-loading server
implementation pattern, the `tools/list` minimal envelope, and the
trade-off matrix between eager and lazy loading.

The discipline extends to **CLI output too**: the `--fields` flag is the
agent's primary mechanism for trimming token cost when full records are
unnecessary. Every list command MUST honor `--fields`. Streaming use
cases use `--format jsonl` — one JSON object per line — so the agent can
process records as they arrive without buffering the full payload.

---

## §7 — The Agent-Invoked Threat Model

When a Spacecraft Software CLI is invoked by a human, the human has agency and
intent. When invoked by an agent, the agent may be:

1. **Hallucinating arguments** — guessing flag names and values
2. **Operating on untrusted input** — processing email, web pages, files
   from external sources that may contain prompt-injection payloads
3. **Retrying after failure** — possibly mutating state idempotently
4. **Operating with elevated privileges** — running as the human's user

The CLI is the last line of defense before the host system. The threat
model in SFRS §7 is non-negotiable, and this skill operationalizes it:

- **Path arguments**: canonicalize, validate against allow-list, reject
  traversal sequences (`..`, encoded variants, symlink escapes)
- **String arguments**: reject control characters (0x00–0x08, 0x0B–0x0C,
  0x0E–0x1F) at parse time
- **Numeric arguments**: bounds-check against schema-declared min/max
- **Confirmation flow**: destructive operations require `--yes` /
  `--force` in non-TTY mode; default-deny when interactive prompt is
  unavailable
- **Sub-process arguments**: never interpolate user-provided strings into
  shell commands; use argv arrays exclusively

**Read `references/agent-threat-model.md`** for the full attack catalog,
the indirect-prompt-injection scenarios specific to CLI tools, and
example Rust validation code.

---

## §8 — Token-Economy Hygiene Checklist

When designing or auditing a Spacecraft Software CLI for agent friendliness, walk
this checklist. Each item maps to a token-cost lever:

1. **`--fields` honored on every list/get command** — agents trim payload
   to what they need. Without this, an agent paying for tokens is forced
   to receive the full record.
2. **`jsonl` mode available** — for any list command that may return >50
   records, support streaming so the agent can process incrementally.
3. **Error hints are runnable commands, not prose** — see §3.
4. **MCP advertises names + descriptions only** — full schemas are
   `tools/get`-loaded. See §6.
5. **`schema` sub-command emits Anthropic-format JSON Schema by default**
   — drops directly into function-calling without translation.
6. **Default JSON output is compact** (no pretty-printing) when stdout is
   not a TTY. Pretty-printing wastes tokens.
7. **Timestamps as ISO 8601 strings, not objects** — `"2026-04-10T14:30:00Z"`
   is 22 chars; an object with `{year, month, day, hour, minute, second,
   tz}` is 80+. Use the string form.
8. **No null-padding fields** — omit fields whose value is null in JSON
   output (use `serde(skip_serializing_if = "Option::is_none")`). Each
   `"field": null` line is wasted tokens.

---

## §9 — Audit Checklist (Agentic Dimension)

When reviewing an existing Spacecraft Software CLI for agent-friendliness
(complementary to the structural audit in `spacecraft-cli-standard` §9),
walk this list:

| # | Check | Severity if missing |
|---|-------|---------------------|
| 1 | `AGENTS.md` exists at repo root | MAJOR |
| 2 | `CLAUDE.md` exists at repo root | MAJOR |
| 3 | `SKILL.md` exists at repo root | MAJOR |
| 4 | Every error response has a non-empty `hint` field | CRITICAL |
| 5 | Hints are runnable commands, not prose | CRITICAL |
| 6 | `AI_AGENT=1` triggers json + no-color + non-interactive | CRITICAL |
| 7 | `<tool> schema` output is valid JSON Schema Draft 2020-12 | BLOCKER |
| 8 | `--fields` honored on every list/get | CRITICAL |
| 9 | `--format jsonl` works for streaming-eligible commands | MAJOR |
| 10 | MCP server (if present) uses lazy loading | CRITICAL |
| 11 | Path arguments are canonicalized + allow-list validated | BLOCKER |
| 12 | Control-character rejection on string arguments | CRITICAL |
| 13 | Non-TTY destructive ops require `--yes` / `--force` | BLOCKER |
| 14 | JSON output omits null fields | MAJOR |
| 15 | JSON output is compact (not pretty) when stdout is non-TTY | MAJOR |

Findings categorized as BLOCKER / CRITICAL / MAJOR per
`spacecraft-cli-standard` §9.

---

## §10 — When to Read Which Reference File

| File | Read when implementing... |
|------|---------------------------|
| `references/agents-md-authoring.md` | Writing AGENTS.md / CLAUDE.md / SKILL.md / CONTRIBUTING.md; choosing what goes where; avoiding template anti-patterns |
| `references/tips-thinking.md` | Authoring the `hint` field of any error; designing cascading hints; avoiding vague hint anti-patterns |
| `references/agent-env-detection.md` | Implementing the env-var detection cascade; writing detection in Rust / Nushell / PowerShell; behavioral adaptation per variable |
| `references/llm-tool-calling.md` | Shaping `<tool> schema` output for Anthropic / OpenAI / Gemini / MCP; provider-specific wrappers; required-field rules |
| `references/token-economy.md` | MCP lazy loading; `--fields`; jsonl streaming; payload minimization; null-field omission |
| `references/agent-threat-model.md` | Input validation; path canonicalization; control-character rejection; indirect prompt injection defenses |

Assets:
- `assets/agents-md.template.md` — drop-in AGENTS.md template
- `assets/claude-md.template.md` — drop-in CLAUDE.md template
- `assets/error-hint-catalog.json` — canonical hint strings keyed by `error.code`

---

## §11 — Relation to Other Spacecraft Software Skills

This skill is the **agent-UX layer** in the Spacecraft Software CLI skill stack:

- **`spacecraft-standard`** — master Standard. Master wins on conflict.
- **`spacecraft-cli-standard`** — structural SFRS rules (what the CLI must
  be). Authoritative on structure. This skill is subordinate; never
  weakens its rules. Both load together when a Spacecraft Software CLI is in scope.
- **`spacecraft-cli-preference`** — picks which *external* CLI tools to
  invoke (e.g., `rg` over `grep`). Complementary.
- **`spacecraft-cli-shell`** — shell syntax (Nushell / Ion / POSIX) in
  generated commands. Complementary.
- **`rust-guidelines`** — Microsoft Pragmatic Rust Guidelines. Consult
  when writing Rust.
- **`spacecraft-brand-guidelines`** — six-token color palette source of
  truth.

---

*End of SKILL.md. Full normative spec: Spacecraft Software SFRS v1.0.0 "Dual-Mode
Self-Documenting CLI Framework", §3 (Eight Rules), §6 (Schema
Introspection), §7 (Input Hardening), §9 (Agent Environment Detection),
§10 (MCP Surface). Companion skill: `spacecraft-cli-standard`.*
