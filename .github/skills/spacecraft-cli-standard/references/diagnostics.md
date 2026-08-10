# Diagnostics — Severity Ladder, Message Style, Envelopes, Rendering

**Scope.** Every message a Spacecraft Software CLI emits that is *not* the data
payload: errors, warnings, informational notes, and success confirmations.
This reference defines the severity ladder, the message style rules, the
machine-mode diagnostic envelope for non-error severities, the severity
floor that `--quiet` / `--verbose` / agent detection control, and the
unified human-mode rendering — one layout serving both audiences: an AI
agent parsing stderr line-by-line, and a human reading color-coded output.

Design lineage: the rustc diagnostic model (severity + stable code, JSONL
machine output, "the message states what happened; only the help suggests
the fix"), the GNU error format, clig.dev's errors chapter, and the
`[TAG]` accessibility rule from the Steelbore Standard §18.2.1.

---

## §1 — The Severity Ladder

Four severities, matching the §18.2.1 text-tag vocabulary exactly. Rank
order, lowest to highest: `INFO < OK < WARN < ERROR`.

| Severity | Tag | When to use |
|----------|-----|-------------|
| `error` | `[ERROR]` | The command failed. Always paired with a non-zero exit code and the structured `error` envelope (`exit-codes-errors.md` §2). Never suppressible. |
| `warn` | `[WARN]` | The command continues, but something is degraded, deprecated, or fell back — the user or agent should know before trusting the result. Example: TUI fallback, stale cache used, deprecated flag accepted. |
| `ok` | `[OK]` | A side-effect completed: file written, resource created, state changed. clig.dev's "if you change state, tell the user." In machine mode the stdout envelope already carries success, so `ok` diagnostics are for side-effect confirmations and MAY be omitted there. |
| `info` | `[INFO]` | Diagnostic narration useful when debugging: resolved paths, detected modes, timing. Hidden by default; shown under `--verbose`. |

**`hint` is a field, not a severity.** Any diagnostic of any severity MAY
carry a `hint` — the exact runnable command that resolves or investigates
the condition ("tips thinking", `exit-codes-errors.md` §4). It is required
on errors, optional elsewhere. There is no `[HINT]` tag and no fifth
level: the message states *what happened*; only the `hint` suggests what
to do about it. Keeping those in separate fields is what lets an agent
branch on `severity`+`code` and execute `hint` verbatim without parsing
prose.

---

## §2 — Message Style Rules

These apply to the `message` field in every envelope and to human-mode
rendering alike — the content is identical in both modes.

- **Lowercase first word, no trailing period.** `repository not found`,
  not `Repository not found.` (GNU error convention; also makes
  `grep '^\[ERROR\]'` output uniform.)
- **Backticks around identifiers.** Flags, paths, commands, and resource
  names are set in backticks: ``unknown flag `--vebose` ``.
- **Echo the failing input back.** Agents lose track of what they passed.
  ``repository `foo/bar` does not exist`` beats `repository does not
  exist`. Sanitize control characters first (`validation-safety.md`).
- **State what happened, never how to fix it.** The fix belongs in
  `hint`, exclusively. A message that embeds advice ("try running X")
  duplicates the hint in unparseable form.
- **One sentence.** Detail goes in extension fields, not prose.
- **The word "illegal" is prohibited.** Use `invalid` or something more
  specific (rustc style rule).
- **No blame, no exclamation marks, no "oops".** Neutral register.
- **Transient vs permanent is encoded in `code`.** `RATE_LIMITED`,
  `TIMEOUT`, and `NETWORK_ERROR` are retryable; everything else is not
  unless the tool's schema documents otherwise. Agents decide whether to
  retry from the code, never from the wording.

---

## §3 — Machine-Mode Envelopes

Two envelopes, one field skeleton. Both are emitted to **stderr** as a
**single line** of JSON (PowerShell fragments multi-line stderr), are
independently parseable (JSONL-safe), and never appear on stdout.

### `error` — severity `error` (unchanged)

The structured error object defined in `exit-codes-errors.md` §2 **is**
the error-severity diagnostic. Its shape, `error` key, and required
fields (`code`, `exit_code`, `message`, `hint`, `timestamp`, `command`)
are unchanged by this section; existing consumers keep working.

### `diagnostic` — severities `ok`, `warn`, `info`

```json
{"diagnostic":{"severity":"warn","code":"TUI_FALLBACK","message":"interactive explore mode unavailable; falling back to `--format json`","hint":"<tool> list --json","reason":"stdout is not a TTY","timestamp":"2026-08-10T14:30:00Z","command":"<tool> list --format explore"}}
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `diagnostic.severity` | string | yes | `"ok"`, `"warn"`, or `"info"` — lowercase. `"error"` is forbidden here: an error-severity diagnostic is the `error` envelope. |
| `diagnostic.code` | string (upper snake case) | yes | Stable across minor versions, documented in `<tool> schema` alongside the `error.code` enum. |
| `diagnostic.message` | string | yes | Per §2. Identical to the human-mode message. |
| `diagnostic.hint` | string | no | Runnable command, same contract as `error.hint`. Optional here (required on errors). |
| `diagnostic.timestamp` | string (ISO 8601 UTC) | yes | `Z` suffix mandatory. |
| `diagnostic.command` | string | yes | The invocation that produced the diagnostic. |
| `diagnostic.docs_url` | string (URL) | no | Human-audience link; agents follow `hint`, not URLs. |
| *(extensions)* | any | no | Extra structured context as siblings of `message` (e.g. `reason`), documented in the tool's schema. |

**The legacy `{"warning": {...}}` key is deprecated.** Earlier revisions
of `tui-explore.md` specified a one-off `warning` object for the TUI
fallback; it lacked `severity` and `hint` and diverged from the error
shape. New code emits the `diagnostic` envelope above. Parsers SHOULD
accept the old key from tools predating this section.

### Emission rules

- **stderr only, never stdout** — a diagnostic on stdout is a BLOCKER
  defect (`testing-compliance.md` §2).
- **One diagnostic per line**, compact serialization, no ANSI escapes.
- **Order-independent**: an agent must be able to parse each stderr line
  in isolation — try `error` key, then `diagnostic`, else treat the line
  as opaque passthrough (e.g. subprocess output under `--verbose`).
- **Errors bypass everything.** The severity floor (§4) never suppresses
  an `error` envelope.

---

## §4 — The Severity Floor

The floor is the minimum severity emitted to stderr. `--quiet` and
`--verbose` (SKILL.md §3) are defined *as* floor settings, and agent
detection (`spacecraft-agentic-cli` §4) lowers verbosity to failures
only. Explicit flags beat environment detection.

| Condition | Floor | Effect |
|-----------|-------|--------|
| `--quiet` / `-q` | `error` | Errors only. |
| `AI_AGENT` / `AGENT` set (presence-based, SKILL.md §5) | `warn` | Failures and degradations only. Passing-state chatter (`ok`, `info`) costs agent tokens and carries no decision value — but a warning does: a TUI fallback or deprecation tells the agent its invocation needs adjusting (compliance matrix rows 19–20 expect the fallback warning under `AI_AGENT`). |
| default (including `CI`) | `ok` | Errors, warnings, and side-effect confirmations. |
| `--verbose` / `-v` | `info` | Everything, including diagnostic narration and raw subprocess passthrough (which is `info`-level output). |

- `--quiet` and `--verbose` are mutually exclusive; supplying both is a
  usage error (exit 2).
- The floor applies identically in human and machine mode.
- The floor gates *emission*, not *severity assignment* — a suppressed
  diagnostic is simply not written; it is never downgraded or merged
  into stdout.

---

## §5 — Human-Mode Rendering

One layout for every severity. The tag comes first, then the message;
`hint` and `docs_url` render as indented continuation lines:

```
[ERROR] repository `foo/bar` does not exist
  hint: <tool> repo list --json
  docs: https://SpacecraftSoftware.org/docs/repo-get
[WARN] interactive explore mode unavailable; falling back to `--format json`
  hint: <tool> repo list --json
[OK] installed 3 skills into `~/.agents/skills`
[INFO] resolved theme `steelbore` from SPACECRAFT_THEME
```

- The `hint:` line is added at **render time only** — the JSON `hint`
  field stays a pure runnable string with no prefix, arrow, or wrapper.
  The `message` MAY be localized; the `hint` MUST NOT be (it is a
  command, not prose).
- `docs_url` renders as a dimmed `docs:` line in human mode only — it is
  the human-audience counterpart of `hint` and never replaces it.

### Colors (theme tokens, Standard §11.1)

Color the **tag** (and the `hint:`/`docs:` labels); the message body
stays in the default foreground. Reference tokens, never bare hex — the
hex values below are the `steelbore` theme's and travel with the theme
(§11.6); high-contrast and mono variants substitute automatically.

| Element | Theme token | `steelbore` value | Weight |
|---------|-------------|-------------------|--------|
| `[ERROR]` | `error` | Mars Red `#FF3B3B` | bold |
| `[WARN]` | `warning` | Plasma Magenta `#E445FF` | bold |
| `[OK]` | `success` | Acid Lime `#B4FF00` | normal |
| `[INFO]` | `structure` | Pulse Violet `#8A6CFF` | normal |
| `hint:` label + hint text | `accent` | Plasma Orange `#FF5E00` | normal |
| `docs:` label + URL | `foreground` | Platinum Mist `#D9DEE5` | dim |
| message body | `foreground` | Platinum Mist `#D9DEE5` | normal |

There is no `info` theme token in the §11.1 contract; `structure` is the
informational color (consistent with `output-modes.md` §2). Do not mint
new tokens or inline new hex values.

### Colorless and accessible rendering

- **The tag is the meaning; color is reinforcement.** Under `NO_COLOR`,
  `TERM=dumb`, `--no-color`, or a non-TTY, the same lines are emitted
  verbatim minus the escapes — `[ERROR] ...`, `  hint: ...`. Color is
  never the sole carrier of meaning (§18.2.1); a colored line without a
  tag is non-compliant.
- Color precedence is the `output-modes.md` §6 chain — not restated
  here.
- In accessible mode (§18.2.2) diagnostics are already compliant by
  construction: append-only lines, no animation, tags legible to a
  screen reader.

---

## §6 — Downcast to CI Annotation Formats (non-normative)

When a tool offers a CI-annotation output mode, map severities as
follows. This is guidance, not a required feature.

| Spacecraft severity | GitHub Actions | Azure Pipelines | SARIF `level` |
|---------------------|----------------|-----------------|---------------|
| `error` | `::error ...::` | `type=error` | `error` |
| `warn` | `::warning ...::` | `type=warning` | `warning` |
| `info` | `::notice ...::` | — (omit) | `note` |
| `ok` | — (omit) | — (omit) | `none` (`kind: "pass"`) |

Escape `%` → `%25`, CR → `%0D`, LF → `%0A` in GitHub annotation values.

---

## §7 — Common Mistakes (Don't)

- Inventing a `[HINT]` or `[NOTE]` severity. Hint is a field on a
  diagnostic; the ladder is exactly the four §18.2.1 tags.
- Emitting `severity: "error"` inside a `diagnostic` envelope. Errors use
  the `error` envelope with `exit_code`.
- Raw JSON warnings in human mode. The envelope is machine-mode only;
  human mode renders `[WARN] ...`.
- A red message with no `[ERROR]` tag. Fails §18.2.1 and disappears
  entirely under `NO_COLOR`.
- Embedding the fix in the message ("not found — run `<tool> list`").
  The fix is the `hint` field; the message states what happened.
- Letting `--quiet` suppress errors, or `--verbose` widen *stdout*. The
  floor governs stderr diagnostics only; the data payload is unaffected.
- Suppressing a warning by downgrading it to `info` so the default floor
  hides it. Pick the severity by the definition in §1, then let the
  floor do its job.
- Pretty-printing the diagnostic envelope. Single line, always.

---

*See also: `exit-codes-errors.md` for the error envelope, exit codes, and
hint construction; `output-modes.md` §6 for color precedence and §7 for
the stdout/stderr contract; `tui-explore.md` §1 for the TUI-fallback
diagnostic; `spacecraft-agentic-cli` `references/tips-thinking.md` for
hint authoring formulas.*
