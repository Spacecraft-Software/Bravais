# Exit Codes & Structured Errors

**Scope.** Exit codes are how an AI agent performs control flow. Structured
errors are how an agent self-corrects without hallucination. This reference
defines both: the canonical exit code map, the mandatory structured error
schema for machine mode, the `error.code` enum, and the "tips thinking"
hint pattern.

---

## §1 — The Canonical Exit Code Map

| Code | Name | Agent behavior | Notes |
|------|------|----------------|-------|
| 0 | `SUCCESS` | Proceed; parse stdout. | The only success code. Never return 0 on failure. |
| 1 | `GENERAL_FAILURE` | Log error; may retry with different parameters. | Use sparingly — prefer a more specific code. |
| 2 | `USAGE_ERROR` | Do NOT retry. Fix invocation syntax. | Unknown flag, missing required argument, mutually exclusive flags combined, bad format for an argument. |
| 3 | `NOT_FOUND` | Adjust target; do not retry the same query. | Resource does not exist. |
| 4 | `PERMISSION_DENIED` | Escalate to user or acquire credentials. | Also used for path-traversal rejection. |
| 5 | `CONFLICT` | Use idempotent alternative or resolve conflict. | Resource already exists, concurrent modification, lock held. |
| 6–125 | Tool-specific | Per tool | MUST be documented in `<tool> schema` output. |
| 126 | `NOT_EXECUTABLE` | Check PATH and permissions. | POSIX reserved; do not reuse. |
| 127 | `COMMAND_NOT_FOUND` | Install dependency or check PATH. | POSIX reserved; do not reuse. |
| 128+N | Fatal signal N | Log crash; do not retry. | POSIX reserved. 130 = SIGINT, 143 = SIGTERM, etc. |

Codes 6 through 125 are the only band available for tool-specific
semantics. Allocate them conservatively and document every one in the
`schema` sub-command's exit-codes map.

---

## §2 — Structured Error Schema (Mandatory in Machine Mode)

In `--json` mode, on any non-zero exit, the tool MUST emit a JSON object to
**stderr** with exactly this shape:

```json
{
  "error": {
    "code": "NOT_FOUND",
    "exit_code": 3,
    "message": "Repository 'foo/bar' does not exist",
    "hint": "Run 'mytool repo list --json' to see available repositories",
    "timestamp": "2026-04-10T14:30:00Z",
    "command": "mytool repo get foo/bar",
    "docs_url": "https://SpacecraftSoftware.org/docs/repo-get"
  }
}
```

### Field contract

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `error.code` | string (upper snake case) | yes | From the enum in §3. Stable across minor versions. |
| `error.exit_code` | integer | yes | Matches the actual process exit code. |
| `error.message` | string | yes | One sentence. No trailing period. Human-readable but concise. |
| `error.hint` | string | yes | The **tips thinking** field — exact command syntax the agent can invoke to resolve or investigate the error. No prose, just the command. |
| `error.timestamp` | string (ISO 8601 UTC) | yes | When the error was produced. |
| `error.command` | string | yes | The invocation that failed, as it was parsed. |
| `error.docs_url` | string (URL) | no | Link to the relevant docs section for this error code. |

### Critical constraints

- **Single-line JSON on stderr.** PowerShell wraps each stderr line as a separate `ErrorRecord`. Multi-line stderr JSON becomes unparseable in PowerShell. Serialize the error object without pretty-printing when writing to stderr.
- **Always emit on non-zero exit in machine mode.** Missing error object = BLOCKER defect.
- **Never emit an error object on stdout.** Stdout stays pure-data or empty.
- **In human mode (TTY)**, the tool SHOULD still print the `hint` to stderr as colored text (Molten Amber for the hint, Red Oxide for the message) but MAY use prose formatting. The structured JSON object is only required in machine mode.

---

## §3 — The `error.code` Enum

These are stable, upper snake-case strings. A CLI MAY add tool-specific
codes beyond this list; tool-specific codes MUST be documented in
`<tool> schema`.

| `error.code` | Typical `exit_code` | When to use |
|--------------|---------------------|-------------|
| `NOT_FOUND` | 3 | Referenced resource does not exist. |
| `PERMISSION_DENIED` | 4 | Insufficient privileges, ACL denial, path outside allowed set. |
| `INVALID_ARGUMENT` | 2 | Argument value failed validation (wrong type, out of range, bad format). |
| `MISSING_ARGUMENT` | 2 | Required argument not supplied in non-TTY mode (Wizard Fallback). |
| `CONFLICT` | 5 | Resource already exists, concurrent modification, lock held. |
| `RATE_LIMITED` | 1 or tool-specific | Upstream rate limit hit; agent should back off. Include `retry_after` (ISO 8601 duration or absolute ISO 8601 timestamp) in an extended field. |
| `TIMEOUT` | 1 or tool-specific | Operation exceeded the deadline. |
| `NETWORK_ERROR` | 1 or tool-specific | Transport-layer failure. |
| `DEPENDENCY_MISSING` | 127 or tool-specific | Required external tool not on PATH. |
| `INTERNAL_ERROR` | 1 | Unexpected internal failure — the bug-report code. |

### Extended fields

Some error codes benefit from additional structured data. Include it as a
sibling of `message`:

```json
{
  "error": {
    "code": "RATE_LIMITED",
    "exit_code": 1,
    "message": "API rate limit exceeded",
    "hint": "Wait until the time in 'retry_after' then retry the same command",
    "retry_after": "2026-04-10T14:35:00Z",
    "timestamp": "2026-04-10T14:30:00Z",
    "command": "mytool repo list",
    "docs_url": "https://SpacecraftSoftware.org/docs/rate-limits"
  }
}
```

Document extended fields in the tool's schema output.

---

## §4 — Tips Thinking: The `hint` Field

The `hint` field is the single most important field for agent
self-correction. A well-constructed hint lets an agent recover without
hallucinating or escalating to the user.

### Hint construction rules

- **Prefer an executable command.** The ideal hint is a shell command the agent can run verbatim.

  > ✓ `Run 'mytool repo list --json' to see available repositories`
  > ✗ `You might want to check what repositories exist`

- **Name specific flags.** If a missing flag caused the error, name it.

  > ✓ `Supply --target-dir to specify the output location`
  > ✗ `You need to specify a target`

- **Stay under 120 characters** where possible. Multi-sentence hints waste agent context.

- **Never hallucinate commands.** If you don't know the right recovery command, omit the hint field rather than guess.

- **For Wizard Fallback** (missing arg in non-TTY mode), the hint MUST be the full non-interactive invocation:

  ```json
  {
    "error": {
      "code": "MISSING_ARGUMENT",
      "exit_code": 2,
      "message": "--output-path is required in non-interactive mode",
      "hint": "mytool export --output-path <path> --format json",
      "timestamp": "2026-04-10T14:30:00Z",
      "command": "mytool export"
    }
  }
  ```

---

## §5 — Error-Emission Timing

- Emit the error object **before** exiting. If the tool crashes on a panic before writing the error object, wrap the top-level in a catch-unwind (in Rust, `std::panic::catch_unwind`) that serializes an `INTERNAL_ERROR` to stderr.
- **Exit with the `exit_code` in the error object.** Mismatch between `error.exit_code` and the actual process exit code is a BLOCKER.
- Flush stderr before exit. Buffered writers that drop on exit have caused diagnostic loss in prior Spacecraft Software projects.

---

## §6 — Human-Mode Error Rendering

In human mode (TTY), the tool SHOULD render errors with color, but the
*content* MUST match the structured error:

```
error: Repository 'foo/bar' does not exist
       hint: Run 'mytool repo list' to see available repositories
```

Colors (Spacecraft Software palette):
- `error:` label — **Red Oxide** (`#FF5C5C`), bold.
- Message — Red Oxide.
- `hint:` label and hint text — **Molten Amber** (`#D98E32`).
- Timestamp (if shown) — **Liquid Coolant** (`#8BE9FD`), dimmed.

The `--json` flag switches to the structured JSON form, unconditionally.

---

## §7 — Common Mistakes (Don't)

- Emitting a narrative error ("Oops, couldn't find that repo — maybe check your spelling?") in machine mode. Unparseable.
- Returning exit 0 on failure so stdout "still works". The agent has no way to detect failure. BLOCKER.
- Mixing the error JSON into stdout alongside a partial success payload. Stdout stays pure-data or empty on failure.
- Multi-line JSON error on stderr. PowerShell fragments it.
- Hint field that reads like a paragraph ("If you'd like, you could consider running..."). Keep it a command.
- Reusing a POSIX-reserved exit code (126, 127, 128+N) for a tool-specific purpose.

---

*See also: `output-modes.md` for the success envelope; `validation-safety.md`
for the Wizard Fallback pattern that generates `MISSING_ARGUMENT` errors;
and `rust-implementation.md` §3 for the Rust `AppError` type.*
