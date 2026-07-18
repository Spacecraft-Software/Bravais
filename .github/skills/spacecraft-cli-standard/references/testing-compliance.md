# Testing & Compliance Verification

**Scope.** The test categories every Spacecraft Software CLI MUST include in its CI
pipeline, the full compliance matrix with severity ratings, and concrete
verification methods for each requirement. Use this reference when
setting up a new CLI's test suite or auditing an existing one.

---

## §1 — Required Test Categories

Every Spacecraft Software CLI CI pipeline MUST include tests in each of the
following categories. Missing a category is itself a compliance finding.

### 1. JSON Schema Validation Tests

For every command that supports `--json`, a test MUST:
1. Invoke `<tool> schema <noun> <verb>` and capture the declared schema.
2. Invoke `<tool> <noun> <verb> --json` with realistic inputs.
3. Validate the actual output against the declared schema using a
   JSON Schema 2020-12 validator (Rust: `jsonschema` crate).

Failure of a schema validation is a BLOCKER.

### 2. Exit Code Tests

Every documented exit code (0, 1, 2, 3, 4, 5, plus all tool-specific codes
6–125) MUST have at least one test case that:
1. Triggers the condition.
2. Asserts the process exit code is exactly the documented value.
3. If in `--json` mode, asserts the structured error on stderr carries
   the matching `error.exit_code`.

### 3. TTY / Non-TTY Mode Tests

Tests MUST verify the output mode cascade:
- Invoked with a PTY → human mode (ANSI escape codes present).
- Invoked with a pipe → machine mode (no ANSI, JSON envelope emitted).
- Invoked with `--json` explicitly → machine mode regardless of TTY.
- Invoked with `AI_AGENT=1` → machine mode regardless of TTY.

Rust test harness: `assert_cmd` + `portable-pty` for the PTY case.

### 4. Agent Environment Tests

Tests MUST verify correct behavior with each agent env var set:

| Env | Expected effect |
|-----|-----------------|
| `AI_AGENT=1` | `--json` output, no color, no TUI, Wizard Fallback active |
| `AGENT=1` | Same as `AI_AGENT=1` |
| `CI=true` | `--json` output, no color, no interactive prompts |
| `NO_COLOR=1` | No ANSI escape codes in output |
| `FORCE_COLOR=1` + `NO_COLOR=1` | Color enabled (FORCE_COLOR wins in human mode; still suppressed in machine mode) |
| `TERM=dumb` | No color, no TUI, no cursor movement |

### 5. Idempotency Tests

Every state-mutating command MUST have a test that:
1. Invokes the command once. Captures state.
2. Invokes the exact same command again.
3. Asserts either: (a) exit 0 with consistent response data, or
   (b) exit 5 (`CONFLICT`) with the existing resource in the error payload.

Duplicate side effects (two resources, two emails sent, etc.) → BLOCKER.

### 6. Input Validation Tests

Negative-path tests covering every threat from
`validation-safety.md` §1:

- Path traversal: `--path ../../etc/passwd` → exit 4 (`PERMISSION_DENIED`).
- Control characters: argument containing `\x00` / `\x01` / `\x1B` → exit 2 (`USAGE_ERROR`).
- Bounds violation: numeric argument outside declared `minimum`/`maximum` → exit 2.
- Oversized input: string argument exceeding declared `maxLength` → exit 2.
- Invalid UTF-8: raw bytes that are not valid UTF-8 → exit 2.

### 7. Cross-Shell Roundtrip Tests

JSON output MUST be verified for correct parsing through each primary
shell's JSON consumer:

| Shell | Consumer | Command |
|-------|----------|---------|
| POSIX/Bash | `jaq` (or `jq`) | `<tool> list --json \| jaq '.data[]'` |
| Nushell | `from json` | `<tool> list --json \| nu -c 'from json \| get data'` |
| PowerShell | `ConvertFrom-Json` | `<tool> list --json \| pwsh -Command '$input \| ConvertFrom-Json'` |

All three MUST succeed without error. Failure in any one is a CRITICAL
finding (MAJOR if the shell is not currently installed in CI; the test
remains required).

### 8. UTF-8 Encoding Tests

Output containing non-ASCII characters MUST be verified as valid UTF-8
without BOM. Test inputs:

- Arabic: `"سلام"` (name field in test fixture).
- CJK: `"你好"` / `"こんにちは"` / `"안녕하세요"`.
- Emoji: `"🦀"`.
- Combining characters: `"e\u{0301}"` (Latin `e` + combining acute).

Verification: `file --mime-encoding` on captured output must return
`utf-8`, and the first three bytes must NOT be `EF BB BF` (UTF-8 BOM).

### 9. Schema / Describe Smoke Tests

- `<tool> schema` exits 0 and produces a document validating against
  JSON Schema Draft 2020-12 meta-schema.
- `<tool> describe` exits 0 and carries every field from
  `schema-introspection.md` §2.
- `<tool> help` exits 0 and contains at least two examples per
  sub-command, at least one per command demonstrating `--json`.

### 10. Context-File Presence Tests

Repo-root file existence checks — run as part of CI, not just as a
one-time lint:

- `CLAUDE.md` exists and has non-empty build/test sections.
- `AGENTS.md` exists and has non-empty build/test sections.
- `CLAUDE.md` and `AGENTS.md` are kept in sync (substantive diff check — they MAY use different filenames but MUST convey the same content to their respective agent audiences).
- `SKILL.md` exists with valid YAML frontmatter (keys: `name`, `description`, `license`).
- `CONTRIBUTING.md` exists.

---

## §2 — Compliance Matrix

Severity levels: **BLOCKER** (does not ship), **CRITICAL** (fix this
release), **MAJOR** (fix before next minor release).

| # | Requirement | Verification method | Severity |
|---|-------------|---------------------|----------|
| 1 | ISO 8601 UTC timestamps in all output | Regex `^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$` match on every timestamp field in `--json` output | BLOCKER |
| 2 | UTF-8 without BOM encoding | `file --mime-encoding` on captured stdout + first-3-bytes check | BLOCKER |
| 3 | Exit codes match documented meanings | Table-driven test per entry in §4 of SKILL.md | BLOCKER |
| 4 | `--json` flag present on every data-returning command | Iterate sub-commands via `schema`; assert `supports_json == true` for data commands | BLOCKER |
| 5 | `schema` sub-command present | `<tool> schema` → exit 0; output validates against JSON Schema 2020-12 meta-schema | BLOCKER |
| 6 | `describe` sub-command present | `<tool> describe` → exit 0; output carries all required fields | BLOCKER |
| 7 | Structured error on stderr in `--json` mode on non-zero exit | Induce error, capture stderr, parse as JSON, validate schema | BLOCKER |
| 8 | stdout contains only data payload in machine mode | Capture stdout during error path; assert no content on error, no ANSI escapes, no log lines | BLOCKER |
<!-- REUSE-IgnoreStart -->
| 9 | GPL-3.0-or-later + SPDX header in every source file | Lint: `rg -L 'SPDX-License-Identifier: GPL-3.0-or-later' src/` → must be empty | BLOCKER |
<!-- REUSE-IgnoreEnd -->
| 10 | `NO_COLOR` suppresses ANSI | Set `NO_COLOR=1`, capture stdout+stderr, assert absence of `\x1B[` | CRITICAL |
| 11 | `FORCE_COLOR` enables ANSI (human mode) | Set `FORCE_COLOR=1` with piped stdout → human mode with ANSI | CRITICAL |
| 12 | `--dry-run` on every write / delete / destructive command | Iterate sub-commands via schema; assert `supports_dry_run == true` for write commands | CRITICAL |
| 13 | Agent env var detection | `AI_AGENT=1 <tool> <noun> list` → JSON output, no ANSI | CRITICAL |
| 14 | POSIX-first default output parseable by grep/awk/cut | Test: pipe default output through `awk '{print $1}'` and assert non-empty expected result | CRITICAL |
| 15 | Wizard Fallback: missing arg in non-TTY → structured error | Invoke without required arg in pipe mode → exit 2, `MISSING_ARGUMENT`, hint contains the full invocation | CRITICAL |
| 16 | Idempotency of state-mutating commands | Run twice; assert no duplicate side effects | CRITICAL |
| 17 | Path traversal rejection | Invoke with `--path ../../<restricted>` → exit 4 | CRITICAL |
| 18 | Control character rejection | Invoke with argument containing `\x00` → exit 2 | CRITICAL |
| 19 | TUI falls back when stdout not TTY | `<tool> list --format explore \| cat` → `--format json` fallback + stderr warning | MAJOR |
| 20 | TUI falls back when `AI_AGENT=1` | `AI_AGENT=1 <tool> list --format explore` → `--format json` fallback | MAJOR |
| 21 | `SKILL.md` / `CLAUDE.md` / `AGENTS.md` / `CONTRIBUTING.md` at repo root | File existence check in CI | MAJOR |
| 22 | Cross-shell roundtrip: jaq / from json / ConvertFrom-Json | Three-way pipe test per sub-command | MAJOR |
| 23 | Windows console code page 65001 set | Windows-specific test: `chcp` query after tool start | MAJOR |
| 24 | `--print0` NUL-delimited output works | Pipe through `xargs -0` and verify | MAJOR |
| 25 | MCP surface available for tools with >10 sub-commands | `<tool> mcp --help` → exit 0; initial `tools/list` over stdio responds | MAJOR (BLOCKER if tool advertises MCP support) |
| 26 | Dual CUA + Vim keybindings in TUI | Scripted TUI test: `arrow down` + `j` both navigate one row down | MAJOR |
| 27 | Spacecraft Software palette only in TUI | Screenshot diff against palette reference; no out-of-palette colors | MAJOR |

---

## §3 — Verification Automation

### Recommended Rust test stack

- **`assert_cmd`** — invoke the binary with controlled env + stdin, capture stdout/stderr/exit.
- **`predicates`** — composable assertions on output (`predicate::str::contains`, `predicate::str::is_match`).
- **`portable-pty`** — allocate a pseudo-TTY for TTY-detection tests.
- **`jsonschema`** — validate JSON output against schema.
- **`insta`** — snapshot testing for stable `--json` output.
- **`tempfile`** — isolated workdirs for idempotency and path-traversal tests.

### A typical test file layout

```
<repo-root>/
├── tests/
│   ├── cli_blocker.rs       # Tests for all BLOCKER-severity requirements
│   ├── cli_critical.rs      # CRITICAL requirements
│   ├── cli_major.rs         # MAJOR requirements
│   ├── schema.rs            # JSON Schema validation
│   ├── idempotency.rs       # Run-twice tests
│   ├── validation.rs        # Input validation negative tests
│   ├── cross_shell.rs       # jaq / nu / pwsh round-trips
│   ├── encoding.rs          # UTF-8 + BOM checks
│   └── fixtures/
│       └── <test inputs>
```

---

## §4 — CI Integration

### Minimal CI job matrix

- **Rust versions:** stable, beta (warning only), MSRV-pinned.
- **Operating systems:** Linux (primary), macOS, Windows.
- **Shells for round-trip tests:** bash (all OSes), nu (install step), pwsh (all OSes).

### Gate the merge

BLOCKER tests MUST pass for merge. CRITICAL tests MUST pass on main.
MAJOR tests MAY be allowed-to-fail briefly but must be fixed before the
next minor release.

### Compliance report

Emit a structured compliance report on every CI run:

```json
{
  "metadata": {
    "tool": "caliper",
    "version": "0.3.0",
    "spec_version": "the CLI Standard v1.0.0",
    "timestamp": "2026-04-10T14:30:00Z"
  },
  "data": {
    "blocker": { "total": 9, "passing": 9, "failing": 0 },
    "critical": { "total": 9, "passing": 9, "failing": 0 },
    "major": { "total": 9, "passing": 8, "failing": 1 },
    "findings": [
      {
        "severity": "MAJOR",
        "requirement_id": 22,
        "title": "Cross-shell roundtrip: PowerShell",
        "status": "failing",
        "details": "pwsh not installed in CI image"
      }
    ]
  }
}
```

This report itself follows the Standard's envelope shape — the tool eats
its own dog food.

---

## §5 — Common Mistakes (Don't)

- Testing only the happy path. Half the compliance matrix is error/edge cases.
- Using `assert_eq!(actual, expected)` for JSON comparisons. Property order and whitespace bite you. Use `serde_json::Value` comparison or `insta` snapshots.
- Testing TTY detection only on Linux. Windows and macOS have different `isatty` semantics.
- Skipping idempotency tests because "the command is obviously idempotent". Prove it in CI.
- Letting MAJOR findings sit for multiple release cycles. They compound.
- Running the compliance matrix once at v1.0 and never again. Run it on every CI.

---

*See also: every other file in this directory — this reference tests what
the others specify. `rust-implementation.md` §10 has the `assert_cmd`
scaffold and `jsonschema` integration.*
