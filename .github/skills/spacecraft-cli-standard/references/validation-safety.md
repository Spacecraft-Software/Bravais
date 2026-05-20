# Input Validation & Agent-Safety Hardening

**Scope.** When an AI agent invokes a Spacecraft Software CLI, the agent is not a
trusted operator. Agents hallucinate arguments, relay adversarial payloads
from untrusted upstream data (indirect prompt injection), and occasionally
request operations they don't understand. This reference defines the
threat model, required validations, the `--dry-run` contract, the Wizard
Fallback pattern for missing arguments, and idempotency requirements.

---

## §1 — Threat Model

A Spacecraft Software CLI MUST defend against:

| Threat | Example |
|--------|---------|
| Path traversal | `--config ../../etc/passwd` |
| Embedded control characters | `--name $'evil\x00boundary'` (NUL bytes, ESC, etc.) |
| Double-encoded UTF-8 | `%c0%af` → `/` after naive decoding |
| Shell metacharacter injection | `--target "foo; rm -rf ~"` when the value is interpolated into a sub-process |
| Memory/disk exhaustion | `--count 9999999999`, 10 GB JSON document on stdin |
| Resource-exhausting timeouts | Slow-loris reads on network arguments |
| Hallucinated arguments | Flags or values that don't exist; unrelated values from agent context |

The defense is layered: parse strictly, validate aggressively, canonicalize
paths, reject on ambiguity, and use `--dry-run` as the agent's safety net.

---

## §2 — Required Validations

### Path arguments

- **Canonicalize every path argument** with `std::fs::canonicalize` (or `std::path::absolute` when the path may not yet exist). Reject any path that, after canonicalization, escapes a configurable **allowed-paths list**.
- The allowed-paths list defaults to:
  - The current working directory.
  - `$XDG_CONFIG_HOME` or `~/.config/<tool>`.
  - `$XDG_DATA_HOME` or `~/.local/share/<tool>`.
  - `$XDG_CACHE_HOME` or `~/.cache/<tool>`.
- Tools that need broader access (e.g., Caliper reading arbitrary input images) can widen the set via configuration, but the widening MUST be explicit, documented, and logged.
- Rejection emits `PERMISSION_DENIED` (exit code 4) with a hint naming the allowed paths.

### String arguments

- **Reject control characters.** Any argument containing bytes `0x00–0x08`, `0x0B–0x0C`, or `0x0E–0x1F` is rejected with `USAGE_ERROR` (exit 2). Exceptions: tab (`0x09`), LF (`0x0A`), CR (`0x0D`) are permitted in fields explicitly typed as free-text (e.g., commit messages, descriptions).
- **Reject invalid UTF-8.** `std::str::from_utf8` is not optional. Rejection is `USAGE_ERROR`.
- **Bound every string length.** Set per-field max lengths in the schema (`"maxLength": 1024` etc.) and enforce them in code. A 10 MB `--name` argument is always an error.

### Numeric arguments

- **Bounds check against schema-declared `minimum` / `maximum`.** Single source of truth — the schema (`schema-introspection.md`) declares the bounds; the runtime enforces them. No `as i32` or `as usize` truncation. Use `TryFrom` conversions and return `USAGE_ERROR` on failure.
- **Reject `NaN` and `Infinity`** for floating-point arguments unless the field is explicitly typed to accept them.

### Sub-process arguments

- **Never interpolate user values into a shell.** Always use `std::process::Command` with separate `.arg()` calls — no `sh -c "..."` wrappers with interpolated user strings.
- If a value must be shell-escaped (e.g., writing to a config file that will be sourced later), use `shell-escape` or `shell-words` crates. Never hand-escape.

---

## §3 — The Wizard Fallback Pattern

An interactive CLI may prompt the user for missing required arguments in
TTY mode. In non-TTY mode (pipes, agents, CI), prompting is impossible and
dangerous. The **Wizard Fallback pattern**:

### Rules

1. **In TTY mode with stdin-is-a-TTY**, the tool MAY prompt for missing
   required arguments. Prompts go to stderr.

2. **In non-TTY mode** (stdout piped OR stdin not a TTY OR `AI_AGENT=1` OR
   `AGENT=1` OR `CI=true`), the tool MUST NOT prompt. Instead, emit a
   structured error with `MISSING_ARGUMENT`:

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

3. **The `hint` MUST be the complete non-interactive invocation.** The
   agent can copy it verbatim (filling `<placeholders>`) and retry.

4. **Auto-decline confirmations** in non-TTY mode. Never default to "yes" on a destructive prompt when stdin is not a TTY. The `--yes` / `--force` flag is required to skip confirmation in non-interactive contexts.

---

## §4 — `--dry-run` Contract

The `--dry-run` flag is the agent's primary safety mechanism. It MUST be
accepted by every command that performs a write, delete, or destructive
operation.

### Requirements

- **Before any side effect.** The dry-run check runs after argument validation, before any file write, network call, or state mutation.
- **Output is a structured action plan** as JSON on stdout. The envelope includes `metadata.dry_run: true`:

  ```json
  {
    "metadata": {
      "tool": "craton",
      "version": "0.2.0",
      "command": "craton package install foo --dry-run",
      "timestamp": "2026-04-10T14:30:00Z",
      "dry_run": true
    },
    "data": {
      "actions": [
        { "action": "download", "target": "foo-1.2.3.tar.gz", "url": "..." },
        { "action": "verify", "target": "foo-1.2.3.tar.gz", "checksum": "sha256:..." },
        { "action": "extract", "target": "~/.local/share/craton/foo" },
        { "action": "link", "source": "...", "target": "~/.local/bin/foo" }
      ],
      "summary": "Would install 1 package (foo 1.2.3) consuming ~8.4 MB"
    }
  }
  ```

- **Exit 0 on successful dry run**, even though no action was taken. The agent can inspect `data.actions` and decide whether to proceed.
- **Idempotent dry-runs.** Same invocation twice must produce the same action plan.

### Exempt commands

Read-only commands (`list`, `get`, `schema`, `describe`) do not need
`--dry-run` — they have no side effects to preview. Accepting the flag is
fine; ignoring it is fine; rejecting it with `USAGE_ERROR` is also fine
(and arguably clearest).

---

## §5 — Idempotency Requirements

Agents retry on failure. A command that is not idempotent causes duplicate
side effects when retried.

### Requirements

- **State-mutating commands MUST be idempotent by default.** Running the same `create` twice MUST NOT create a duplicate resource. Either:
  - Return success (exit 0) with the existing resource's data, OR
  - Return `CONFLICT` (exit 5) with the existing resource in the error's extended fields.
- **Prefer declarative verbs** (`apply`, `sync`, `ensure`) over imperative verbs (`create`, `delete`) where feasible. See `schema-introspection.md` §3 for the standard verb set.
- **Where true idempotency is impossible** (e.g., sending an email, enqueuing a job with a generated ID), the tool MUST support `--dry-run` to preview the action, AND MUST document the non-idempotency in the `schema` output (`"idempotent": false`).
- **`delete` is idempotent.** `delete` on a missing resource returns exit 0 with `data: { deleted: false, reason: "not found" }` — not exit 3. (The resource is in the desired end state.)

---

## §6 — Confirmation Prompts for Destructive Operations

- In **TTY + stdin-is-a-TTY**, destructive commands SHOULD prompt for confirmation.
- In **non-TTY mode**, destructive commands WITHOUT `--yes` / `--force` MUST exit with `MISSING_ARGUMENT` and a hint pointing at the `--yes` or `--force` flag.
- Prompts go to stderr. The answer is read from stdin.
- **Default to "no."** A lazy press of Enter on a confirmation prompt must NOT execute the destructive action.

---

## §7 — Large-Input Protection

- **stdin size cap.** If the command accepts structured input on stdin (e.g., `apply -f -`), enforce a configurable maximum size (default: 16 MiB). Reject with `USAGE_ERROR` + a hint pointing at file-based input.
- **Stream, don't slurp.** For `--format jsonl` input, parse line-by-line. Don't collect the whole stream into a `String` before parsing.
- **Network-fetched inputs.** When a URL argument is accepted, enforce a timeout (default: 30 s) and a size cap (default: 64 MiB). Reject with `TIMEOUT` or `USAGE_ERROR`.

---

## §8 — Common Mistakes (Don't)

- Passing user strings to `sh -c "..."`. Classic injection.
- Skipping canonicalization because "my code just opens the file". Path traversal doesn't need you to execute it — the file read itself is the breach.
- Prompting for a missing arg when `AI_AGENT=1` is set. Agent hang / silent failure.
- Defaulting destructive prompts to "yes". One stray pipe command = data loss.
- Creating a new resource on every retry because the tool is not idempotent. Causes duplicate state on flaky networks.
- `delete` on a missing resource returning exit 3 (`NOT_FOUND`). Breaks idempotent retries. Return 0.
- `--dry-run` that does the side effect "just to get realistic output." Defeats the point.
- Accepting unbounded `String` input. Memory exhaustion.

---

*See also: `exit-codes-errors.md` for `MISSING_ARGUMENT` and `PERMISSION_DENIED` formatting; `schema-introspection.md` for schema-declared bounds; `rust-implementation.md` §6 for path canonicalization and control-character validation helpers.*
