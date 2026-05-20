# Tips-Thinking — Error Hint Authoring Discipline

When a CLI emits an error, the AI agent has two options: (1) consult its
training data and guess what to try next, or (2) follow an explicit hint.
Option (1) costs many tokens and often fails. Option (2) is direct and
cheap. The `hint` field in the structured-error envelope is where Spacecraft Software
CLIs choose option (2) for the agent.

This reference catalogs the discipline of authoring `hint` strings well.

## Table of contents

- §1 — The structural rule (what every hint must satisfy)
- §2 — Hint formulas by `error.code` value
- §3 — Cascading hints for compound failures
- §4 — Anti-patterns
- §5 — Testing hints
- §6 — Localization and human-mode rendering

---

## §1 — The structural rule

**Every `hint` is a runnable command.** Not a sentence about a command.
Not a hyperlink to documentation. A literal string the agent can paste
into its next tool invocation.

### The "paste test"

For every hint string you write, apply this test: **could an agent paste
this string into a shell and have it execute meaningfully?** If yes, the
hint passes. If no, rewrite it.

| Hint string | Passes paste test? |
|-------------|--------------------|
| `mytool repo list --json` | Yes |
| `Run mytool with the list flag.` | No (prose) |
| `See https://docs.example.com/repo` | No (URL, not a command) |
| `Try mytool repo list` | No (hedged language) |
| `mytool config get --field auth.token` | Yes |

### The single-command rule

Each `hint` carries **one** command, not a sequence. If recovery requires
multiple steps, see §3 (cascading hints) — chain via successive
invocations, not via shell `&&` glue inside a single hint.

---

## §2 — Hint formulas by `error.code`

The `error.code` enum from `spacecraft-cli-standard` defines the canonical
error codes. Each has a hint formula:

### `NOT_FOUND` (exit 3)

The agent asked for a resource that does not exist. The hint must point to
the listing command for that resource type.

**Formula:** `<tool> <noun> list --json [--filter <hint-from-attempt>]`

**Example:**
```json
{
  "code": "NOT_FOUND",
  "message": "Repository 'foo/bar' does not exist",
  "hint": "ferrocast repo list --json"
}
```

If the failed argument was a fuzzy match for an existing resource,
include a `--filter` to narrow the listing:
```json
{
  "hint": "ferrocast repo list --json --filter foo"
}
```

### `INVALID_ARGUMENT` / usage error (exit 2)

The agent provided an argument that doesn't parse or violates a constraint.
The hint must show the correct invocation form.

**Formula:** `<tool> schema <noun> <verb>` (point to the schema)

**Example:**
```json
{
  "code": "INVALID_ARGUMENT",
  "message": "Argument '--port' expects integer in range 1–65535, got '8080x'",
  "hint": "ferrocast schema host listen"
}
```

The schema sub-command output is itself agent-readable, so this hint is a
recursive escape hatch: the agent reads the schema, fixes the arg, retries.

### `PERMISSION_DENIED` (exit 4)

The agent lacks credentials or filesystem permissions. The hint must
point to the credential-acquisition command.

**Formula:** `<tool> auth login [--scope <required-scope>]` or path-fix
command.

**Example:**
```json
{
  "code": "PERMISSION_DENIED",
  "message": "Repository 'foo/bar' requires 'repo:write' scope",
  "hint": "ferrocast auth login --scope repo:write"
}
```

Filesystem permission case:
```json
{
  "code": "PERMISSION_DENIED",
  "message": "Cannot write to '/etc/ferrocast/config.toml': permission denied",
  "hint": "sudo chown $USER /etc/ferrocast/config.toml"
}
```

### `CONFLICT` (exit 5)

The resource already exists or is in a conflicting state. The hint must
offer the idempotent or override path.

**Formula:** `<tool> <noun> <verb> --force` OR `<tool> <noun> get <id>`
(view existing).

**Example:**
```json
{
  "code": "CONFLICT",
  "message": "Repository 'foo/bar' already exists",
  "hint": "ferrocast repo get foo/bar --json"
}
```

### `RATE_LIMITED` (tool-specific)

The agent hit a rate limit. The hint must include the wait time or
backoff command.

**Formula:** include a `retry_after` field, hint suggests sleep + retry.

**Example:**
```json
{
  "code": "RATE_LIMITED",
  "message": "API rate limit exceeded; retry after 60 seconds",
  "retry_after_seconds": 60,
  "hint": "sleep 60 && ferrocast repo list --json"
}
```

### `INTERNAL_ERROR` (exit 1)

The tool itself failed. The hint must point to the diagnostics command or
log file.

**Formula:** `<tool> diagnose --json` OR a log-tail command.

**Example:**
```json
{
  "code": "INTERNAL_ERROR",
  "message": "Cmdlet registry corrupt",
  "hint": "ferrocast diagnose registry --json"
}
```

### `MISSING_DEPENDENCY` (tool-specific)

A required external tool is missing from PATH. The hint must show the
install command preferred by `spacecraft-missing-pkg`.

**Formula:** `nix-shell -p <pkg>` (preferred) or the discovery command.

**Example:**
```json
{
  "code": "MISSING_DEPENDENCY",
  "message": "Required tool 'rage' not found in PATH",
  "hint": "nix-shell -p rage"
}
```

---

## §3 — Cascading hints for compound failures

When recovery genuinely requires multiple steps (auth → list → retry), do
not concatenate them with `&&`. Instead, structure the hint as the
**first** step, and rely on the subsequent commands' own hints to chain
forward.

**Wrong:**
```json
{
  "hint": "ferrocast auth login && ferrocast repo list --json && ferrocast repo get foo/bar --json"
}
```

**Right:** First error response:
```json
{
  "code": "PERMISSION_DENIED",
  "message": "Authentication required",
  "hint": "ferrocast auth login"
}
```

After the agent runs `ferrocast auth login` successfully, it retries the
original command. If the new failure is `NOT_FOUND`, that error's own hint
takes the agent to `ferrocast repo list --json`. The chain emerges from
the agent's natural retry loop, not from the hint string.

This is why **single-command hints** matter: they preserve the agent's
ability to course-correct between steps. A glued chain forces a path that
may no longer be valid by the time the agent reaches step 3.

---

## §4 — Anti-patterns

### Anti-pattern: prose hints

**Wrong:** `"hint": "Make sure the repository exists and you have access."`

**Why wrong:** the agent must parse English, infer a command, and guess.
Tokens wasted, hallucination risk added.

**Right:** `"hint": "ferrocast repo list --json"`

### Anti-pattern: hints that lie

If your hint suggests `ferrocast repo list --json` but the tool doesn't
have that sub-command, the agent will run it, get exit 127 or 2, and
spiral. **Every hint must be a real, currently-supported command in the
current version of the tool.** Tests must verify hint validity (see §5).

### Anti-pattern: vague hints

**Wrong:** `"hint": "Check the configuration."`

**Right:** `"hint": "ferrocast config get --json"`

### Anti-pattern: hints requiring inference

**Wrong:** `"hint": "Try with a valid token."`

**Right:** `"hint": "ferrocast auth login"`

### Anti-pattern: hints that point to URLs

**Wrong:** `"hint": "See https://docs.SpacecraftSoftware.org/troubleshooting/auth"`

**Why wrong:** the agent cannot consume the URL during a CLI loop. Even
if it can web-fetch, it consumes more tokens than running the local
diagnostic command.

**Right:** `"hint": "ferrocast diagnose auth --json"`

The `docs_url` field is for **human** users in TTY mode; it is rendered
to stderr as a clickable link. The `hint` field is for the agent loop.
They serve different audiences.

### Anti-pattern: empty or null hints

Every error MUST have a non-empty `hint`. If a recovery path genuinely
doesn't exist (rare — usually `INTERNAL_ERROR`), the hint MUST be the
diagnostics command:

```json
{
  "code": "INTERNAL_ERROR",
  "hint": "ferrocast diagnose --verbose --json"
}
```

A null hint signals to the agent that you forgot to design the recovery
path.

### Anti-pattern: hints that contradict idempotency

**Wrong:** A `CONFLICT` error returning `"hint": "ferrocast repo delete foo/bar && ferrocast repo create foo/bar"`

**Why wrong:** destructive recovery for a benign conflict. The agent will
delete the existing resource (which may belong to a different
human-managed workflow) just to retry its create.

**Right:** `"hint": "ferrocast repo get foo/bar --json"` — let the agent
inspect the existing resource and decide whether to proceed, override
intentionally with `--force`, or abort.

---

## §5 — Testing hints

Hint correctness is a CI concern. Every error path must have a test that:

1. Triggers the error
2. Captures the JSON error envelope
3. Parses out `error.hint`
4. Splits the hint into argv
5. Invokes the hint with `--dry-run` (or the inspection variant)
6. Asserts exit code 0 OR exit code 2 with a different `error.code`

The last condition allows for hints that themselves require credentials
(e.g., the `auth login` hint can't run unattended in CI without a stored
token), but rules out hints that are syntactically invalid.

A property-based test that walks every code path and verifies hint
runnability is the gold standard. See
`references/testing-compliance.md` in `spacecraft-cli-standard` for the
test scaffold.

---

## §6 — Localization and human-mode rendering

In human (TTY) mode, the hint field SHOULD still be rendered as a
suggestion to the human user. Format it visibly:

```
Error: Repository 'foo/bar' does not exist
  → Try: ferrocast repo list --json
```

The arrow + `Try:` prefix MUST NOT appear in the JSON `hint` field
itself. It is added at render time only. The JSON hint stays a pure
runnable string.

**Localization:** the `message` field MAY be localized for human users.
The `hint` field MUST NOT be localized — it is always the literal command
string in its canonical English form, because the command syntax itself
is not translated. Localize the wrapper, not the command.

---

*End of tips-thinking.md*
