# Schema Introspection & Self-Description

**Scope.** How a Spacecraft Software CLI describes itself at runtime so agents never
need a man page, website, or PDF. Covers the `schema` sub-command (JSON
Schema Draft 2020-12), the `describe` sub-command (capability manifest), the
four required repo-root context files, and the noun-verb command hierarchy
that keeps the whole surface discoverable.

---

## §1 — The `schema` Sub-Command

Every Spacecraft Software CLI MUST implement:

```
<tool> schema [<noun> [<verb>]]
```

- With no arguments: emit the complete tool schema covering every command.
- With `<noun>`: emit the schema for every verb under that noun.
- With `<noun> <verb>`: emit the schema for that specific command.

Output MUST be a single valid JSON document conforming to **JSON Schema
Draft 2020-12**.

### Required schema fields per command

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "command": "caliper trace run",
  "description": "Execute a tracing pipeline on an input image.",
  "parameters": {
    "type": "object",
    "required": ["input", "output"],
    "properties": {
      "input": {
        "type": "string",
        "format": "uri-reference",
        "description": "Path to the input raster image"
      },
      "output": {
        "type": "string",
        "format": "uri-reference",
        "description": "Path for the output SVG"
      },
      "threshold": {
        "type": "number",
        "minimum": 0,
        "maximum": 1,
        "default": 0.5,
        "description": "Tracing threshold in [0.0, 1.0]"
      },
      "algorithm": {
        "type": "string",
        "enum": ["potrace", "autotrace", "spacecraft-native"],
        "default": "spacecraft-native",
        "description": "Tracing algorithm"
      }
    }
  },
  "output_schema": {
    "type": "object",
    "properties": {
      "metadata": { "$ref": "#/$defs/metadata" },
      "data": {
        "type": "object",
        "properties": {
          "output_path": { "type": "string" },
          "path_count": { "type": "integer" },
          "duration_ms": { "type": "integer" }
        }
      }
    }
  },
  "exit_codes": {
    "0": "SUCCESS — tracing completed",
    "2": "USAGE_ERROR — invalid arguments",
    "3": "NOT_FOUND — input file does not exist",
    "4": "PERMISSION_DENIED — cannot read input or write output",
    "50": "TRACING_FAILED — algorithm reported failure"
  },
  "examples": [
    {
      "command": "caliper trace run --input photo.png --output photo.svg",
      "description": "Trace a PNG to an SVG with default settings"
    },
    {
      "command": "caliper trace run --input photo.png --output photo.svg --json",
      "description": "Same, with machine-readable JSON output"
    }
  ],
  "supports_json": true,
  "supports_dry_run": false,
  "idempotent": false,
  "destructive": false
}
```

### Required properties

- `command` — full sub-command path.
- `description` — one sentence.
- `parameters` — JSON Schema for accepted input. Include `required`, `enum`, `default`, `minimum`, `maximum`, `pattern`, `format` where applicable.
- `output_schema` — JSON Schema for the `data` field in `--json` mode.
- `exit_codes` — map of exit code (stringified integer) → description.
- `examples` — at least one example invocation per command, at least one demonstrating `--json`.
- `supports_json` / `supports_dry_run` / `idempotent` / `destructive` — booleans.

### LLM function-calling compatibility

The `parameters` object MUST be directly usable as an LLM function-calling
tool definition — compatible with OpenAI's `tools[].function.parameters`,
Anthropic's tool use `input_schema`, and Google Gemini's `function_declarations[].parameters`. This means: JSON Schema Draft 2020-12
subset that these providers accept, no `$ref` to external URIs, `type` on
every property.

---

## §2 — The `describe` Sub-Command

Every Spacecraft Software CLI MUST implement:

```
<tool> describe
```

Emits a compact capability manifest enumerating every sub-command and the
surfaces the tool exposes. The manifest is smaller than the full `schema`
output and is what an agent fetches first for discovery.

```json
{
  "tool": "caliper",
  "version": "0.3.0",
  "description": "Rust raster-to-vector tracing engine",
  "license": "GPL-3.0-or-later",
  "homepage": "https://github.com/UnbreakableMJ/caliper",
  "commands": [
    {
      "name": "caliper trace run",
      "description": "Execute a tracing pipeline on an input image",
      "supports_json": true,
      "supports_dry_run": false,
      "idempotent": false,
      "destructive": false
    },
    {
      "name": "caliper trace list",
      "description": "List recent tracing jobs",
      "supports_json": true,
      "supports_dry_run": false,
      "idempotent": true,
      "destructive": false
    }
  ],
  "global_flags": [
    "--json", "--format", "--fields", "--dry-run",
    "--verbose", "--quiet", "--no-color", "--color",
    "--help", "--version", "--absolute-time", "--print0",
    "--yes", "--force"
  ],
  "output_formats": ["json", "jsonl", "yaml", "csv", "explore"],
  "mcp_available": true,
  "schema_command": "caliper schema",
  "context_files": ["CLAUDE.md", "AGENTS.md", "SKILL.md", "CONTRIBUTING.md"]
}
```

`describe` MUST exit 0 and MUST be safe to invoke (no side effects, no
network calls).

---

## §3 — Noun-Verb Command Structure

All Spacecraft Software CLIs use a consistent hierarchy:

```
<tool> <noun-singular> <verb> [flags]
```

### Singular nouns

- ✓ `ferrocast module list`
- ✗ `ferrocast modules list`

Plural nouns break tab completion, make the mental model inconsistent, and
have been an observed source of agent hallucination ("I'll run
`ferrocast packages install`..." when the real command is `ferrocast package
install`).

### Standard verb set

These verbs MUST be used consistently across all Spacecraft Software tools. If a
command fits one of these semantics, use the standard verb.

| Verb | Semantics | Idempotent? | Destructive? |
|------|-----------|-------------|--------------|
| `list` | Enumerate resources of a kind | yes | no |
| `get` | Fetch one resource by ID | yes | no |
| `create` | Create a new resource | no (use `apply` for idempotent) | no |
| `update` | Modify an existing resource | depends | no |
| `delete` | Remove a resource | yes (no-op on missing) | yes |
| `apply` | Declarative upsert (ensure resource matches spec) | yes | no |
| `sync` | Reconcile a set of resources to match a manifest | yes | yes (may delete) |
| `describe` | Emit the capability manifest (see §2) | yes | no |
| `schema` | Emit JSON Schema (see §1) | yes | no |

Prefer declarative verbs (`apply`, `sync`, `ensure`) over imperative verbs
where idempotency matters. See `validation-safety.md` §4 for idempotency
requirements.

### Aliases (human mode only)

Shortening aliases are permitted in human-mode help text:

| Alias | Canonical |
|-------|-----------|
| `ls` | `list` |
| `rm` | `delete` |

Aliases MUST NOT appear in:
- `--json` output (the envelope's `metadata.command` uses canonical form).
- `schema` output.
- `describe` output.
- `--help` synopses (mention aliases in a separate "Aliases" section if at all).

---

## §4 — Context Files at Repository Root

Every Spacecraft Software CLI repository MUST include these four files at the repo
root. Missing any one is a MAJOR compliance finding.

`CLAUDE.md` and `AGENTS.md` are **peer agent-context files**. Different AI
coding agents read different filenames by convention — both must be
present, and their content MUST be kept in sync. Treat them as two copies
of the same document, not as agent-specific variants.

| File | Purpose | Primary consumers (non-exhaustive) |
|------|---------|-------------------------------------|
| `CLAUDE.md` | AI coding-agent context: project invariants, build/test/lint commands, architectural constraints, forbidden patterns | Claude Code, Claude Desktop, Oh-My-ClaudeCode |
| `AGENTS.md` | Same content as `CLAUDE.md`, under the filename preferred by non-Anthropic agents | OpenAI Codex CLI, Cursor, Gemini CLI, Aider, generic agents |
| `SKILL.md` | Spacecraft Software skill file with YAML frontmatter: command capabilities, constraints, usage patterns | Any skill-aware AI runtime (Claude Code skills, CLI-Anything, `gws`, custom harnesses) |
| `CONTRIBUTING.md` | Human contributor guidelines | Human developers |

Keeping `CLAUDE.md` and `AGENTS.md` in sync is a CI check: run a diff and
fail the build if they diverge in substance. Some repos implement this by
having one be a symlink to the other; both approaches are acceptable.

### Minimum content (for both `CLAUDE.md` and `AGENTS.md`)

```markdown
# <tool> — AI Coding-Agent Context

## Build
cargo build --release

## Test
cargo test --all
cargo test --all --features tui

## Lint
cargo clippy --all-targets -- -D warnings
cargo fmt --check

## Architectural invariants
- All I/O goes through the `Response<T>` envelope.
- Every sub-command returns the `ExitCode` enum.
- TUI code is gated behind the `tui` feature flag.
- No `unwrap()` or `expect()` in release paths; use `AppError`.

## Forbidden patterns
- `println!` anywhere except the `output` module.
- Local timezone in any timestamp (ISO 8601 UTC only).
- Hand-written argument parsing (use clap).
```

### `SKILL.md` frontmatter

```yaml
---
name: <tool>
description: >
  Concise one-paragraph description of what the tool does and when an agent
  should invoke it. Follow the Spacecraft Software skill description conventions.
license: GPL-3.0-or-later
---
```

---

## §5 — Keeping Schema and Code in Sync

The `schema` output MUST be derived from the same source of truth as the
runtime argument parser. Hand-authored schema that drifts from runtime
behavior is a BLOCKER defect.

Recommended patterns (full Rust examples in `rust-implementation.md`):
- **clap + derive + `schemars`** — derive JSON Schema from the same structs that drive argument parsing.
- **Single source truth.** The MCP surface (`mcp-surface.md`) also uses the schema output — derive once, consume thrice (CLI, `schema` sub-command, MCP tool definitions).
- **CI check.** Add a test that invokes `<tool> schema` and validates against a checked-in reference file; review diffs on every PR.

---

## §6 — Common Mistakes (Don't)

- Writing the schema by hand as a separate JSON file. It drifts.
- Using plural nouns (`packages`, `modules`, `traces`).
- Adding a new verb (`rebuild`, `refresh`, `purge`) when an existing standard verb fits.
- Including aliases in `--json` output or schema.
- Missing `examples` in the schema output. Agents rely on these for few-shot prompting.
- Shipping without `CLAUDE.md` and `AGENTS.md` because "the README covers it". It doesn't; agents parse these specific files.
- `describe` having side effects. It is a pure query.

---

*See also: `output-modes.md` §4 for the envelope referenced by
`output_schema`; `exit-codes-errors.md` §1 for the exit codes referenced in
the schema's `exit_codes` map; `mcp-surface.md` §2 for how the MCP server
consumes the same schema.*
