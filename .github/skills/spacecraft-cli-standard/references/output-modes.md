# Output Modes — Human, Machine, Color, Envelope

**Scope.** Everything about what a Spacecraft Software CLI emits to stdout and stderr:
the mode detection cascade in full, human-mode rendering requirements,
machine-mode JSON requirements, color precedence (NO_COLOR / FORCE_COLOR /
CLICOLOR), the Spacecraft Software palette tokens for terminal output, and the exact
JSON envelope structure.

---

## §1 — Mode Detection Cascade (Full Rules)

The output mode is determined by a strict precedence. First match wins.

1. **Explicit flag.** `--format <fmt>` or `--json` → that mode, unconditionally.
   `--json` is equivalent to `--format json`.
2. **Agent environment variable.**
   - `AI_AGENT=1` or `AI_AGENT=true` → full agent mode: `json` output, no color, no TUI, no interactive prompts.
   - `AGENT=1` / `AGENT=true` / `AGENT=<name>` → same effect as `AI_AGENT`.
   - `CI=true` → CI mode: `json` output, no color, no interactive prompts (but not strictly "agent mode" — a full TUI may still be requested explicitly).
3. **TTY detection.** `isatty(stdout) == true` → human mode with color.
4. **Non-TTY.** stdout is piped or redirected → `json` mode (the `ant` CLI auto-switch).
5. **Fallback.** None of the above → human mode.

Also honor:
- `TERM=dumb` → disable color, disable cursor movement, disable TUI activation even if `--format explore` was requested (emit a warning to stderr and fall back to `--format json`).
- `CLAUDECODE=1`, `CURSOR_AGENT=1`, `GEMINI_CLI=1` — informational only. MUST NOT alter output format on their own; `AI_AGENT` handles that. MAY be recorded in `metadata.tool_agent` in JSON output.

---

## §2 — Human-Oriented Mode

Human mode targets a live terminal emulator with a sighted operator.

### Required characteristics

- **Color palette.** Use the Spacecraft Software six-token palette via ANSI escape sequences, with semantic mapping:
  - Success messages → **Radium Green** (`#50FA7B`)
  - Warnings → **Molten Amber** (`#D98E32`)
  - Errors → **Red Oxide** (`#FF5C5C`)
  - Informational text → **Steel Blue** (`#4B7EB0`)
  - Data values → **Liquid Coolant** (`#8BE9FD`)
  - Backgrounds / neutral chrome → **Void Navy** (`#000027`)
- **Column-aligned tabular output** for `list` commands, using Unicode box-drawing characters for borders. Keep data on single lines where feasible so the output is still grep-parseable.
- **Relative timestamps** for recency in human mode (e.g., "3 minutes ago"). The underlying data is always stored and transmitted as ISO 8601 UTC; relative display is a rendering convenience. `--absolute-time` toggles back to ISO 8601 UTC.
- **Progress indicators** (spinners, progress bars) rendered to stderr only, never to stdout.
- **Interactive prompts** (confirmations, selection menus) rendered to stderr. When stdin is not a TTY, prompts MUST auto-decline (safe default) and emit a structured error to stderr explaining which flags are required for non-interactive invocation — this is the **Wizard Fallback pattern**, see `validation-safety.md`.

### Forbidden in human mode

- Do not emit raw ANSI escape codes to stdout when stdout is piped (honor the cascade).
- Do not print anything to stdout that is not "the answer" — progress/spinners/banners go to stderr.

---

## §3 — Machine-Readable Mode (`--json` / `--format`)

Machine mode targets agents, pipelines, and structured-data shells.

### Required characteristics

- **Single, complete, valid JSON document.** No trailing commas, no comments, no BOM, no ANSI escape codes, no log lines interspersed.
- **All timestamps as ISO 8601 with `Z` suffix.** No relative times. No locale-dependent formatting.
- **Numbers as JSON numbers, not strings.** `1234`, not `"1234"`. Filesizes in bytes as integers (Nushell's `into filesize` converts them).
- **Booleans as `true` / `false`.** Never `"yes"` / `"no"`.
- **Nulls as JSON `null`.** Never `""`, never `"N/A"`.
- **Property names in `snake_case`.** Canonical. PascalCase aliases MAY be added in parallel for PowerShell ergonomics (`created_at` AND `CreatedAt`), but snake_case is required.
- **Depth ≤ 3 by default** without strong justification. PowerShell's `ConvertTo-Json` defaults to depth 2 for round-tripping; shallow structures are preferred for cross-shell round-tripping.
- **Errors to stderr, not to the stdout JSON object.** Never put an error inside the `data` field. See `exit-codes-errors.md`.

### Forbidden in machine mode

- ANSI escape codes (even if `FORCE_COLOR=1`).
- Interactive prompts (fall back to Wizard Fallback).
- Multi-line stderr error objects (PowerShell wraps each stderr line as a separate `ErrorRecord`; keep stderr errors single-line JSON).

---

## §4 — The Envelope: `metadata` + `data`

Every `--json` response is a single JSON document with this structure:

```json
{
  "metadata": {
    "tool": "caliper",
    "version": "0.3.0",
    "command": "caliper trace list",
    "timestamp": "2026-04-10T14:30:00Z",
    "pagination": {
      "page": 1,
      "per_page": 50,
      "total": 142,
      "next_token": "abc123"
    },
    "tool_agent": "cursor"
  },
  "data": [ ... ]
}
```

| Field | Required | Notes |
|-------|----------|-------|
| `metadata.tool` | yes | Binary name (e.g., `"caliper"`). |
| `metadata.version` | yes | Tool version (semver). |
| `metadata.command` | yes | Full invocation (e.g., `"caliper trace list --limit 50"`). |
| `metadata.timestamp` | yes | ISO 8601 UTC at response time. |
| `metadata.pagination` | when the command paginates | `page`, `per_page`, `total` as integers; `next_token` as string or null. |
| `metadata.tool_agent` | no | Detected agent label (one of `"claude-code"`, `"cursor"`, `"codex"`, `"gemini-cli"`, `"aider"`, or another value if a future agent is detected). |
| `data` | yes | Payload. Array for list commands, object for get/detail commands. |

**Never** serialize bare data without the envelope. A single `Response<T>`
type in Rust enforces this (see `rust-implementation.md` §2).

---

## §5 — `--format` Variants

| Format | Content |
|--------|---------|
| `json` (default structured) | Single JSON document with envelope (§4). |
| `jsonl` | Newline-delimited JSON. Each line is an independently parseable JSON object. One record per line, terminated by `\n` (0x0A). Use for streaming and large result sets. The envelope's `metadata` MAY be emitted as the first line with `data: null`, or omitted entirely; be explicit in the tool's schema. |
| `yaml` | YAML 1.2. Envelope structure preserved. |
| `csv` | RFC 4180. Header row = field names. No envelope (CSV is inherently flat). Metadata is emitted to stderr as a one-line JSON comment. |
| `explore` | TUI mode. See `tui-explore.md`. |

**`--fields <f1,f2,...>`** applies after mode selection, narrowing output to
the listed fields. Supported in `json`, `jsonl`, `yaml`, `csv`.

---

## §6 — Color Precedence Chain

Strict order. First match decides. Implement as a single function returning
`ColorMode::{Always, Never, Auto}`.

1. `--color=never` / `--no-color` flag → disable.
2. `--color=always` flag → enable (including when piped).
3. `NO_COLOR` env var (set + non-empty) → disable.
4. `FORCE_COLOR` env var (set + non-empty) → enable. **Overrides `NO_COLOR`.**
5. `CLICOLOR=0` → disable.
6. `TERM=dumb` → disable.
7. TTY detection: `isatty(stdout) == true` → enable. Else disable.

**In machine mode (`--json`, `--format json|yaml|csv|jsonl`), all ANSI
escape codes MUST be suppressed regardless of color settings.** Only
`--format explore` (TUI) uses color when in machine-adjacent contexts, and
the TUI itself already has its own activation guard (no color if `NO_COLOR`
is set).

---

## §7 — stdout / stderr Separation

This is a hard rule that enables composability in POSIX, Ion (with its
enhanced `^>` / `^|` / `&>` / `&|` redirection operators), Bash, and
Nushell.

- **stdout** carries only the data payload. Nothing else.
- **stderr** carries everything else: progress indicators, warnings, informational messages, interactive prompts, structured errors.

A tool that writes a progress spinner to stdout is broken — pipe consumers
(`jq`, `from json`, `ConvertFrom-Json`) will choke on mixed content.

---

## §8 — Common Mistakes (Don't)

- Writing the prompt "Continue? [y/N]" to stdout. (Use stderr.)
- Leaving ANSI codes in JSON output when `FORCE_COLOR=1` is set. (Machine mode always suppresses.)
- Serializing timestamps as `"created": 1712754000`. (Use ISO 8601 strings.)
- Using `WidthType.PERCENTAGE` for rendered tables when they'll be parsed downstream. (Human mode uses Unicode box-drawing, machine mode emits structured data.)
- Putting error text inside the `data` field. (Errors go to stderr as their own JSON object, never mixed with success output.)
- Emitting NDJSON by default. (Default `--json` is a single document. `--format jsonl` is explicit opt-in.)
- Relying on `TERM` alone to detect interactive capability. (Check `isatty()`.)

---

*See also: `exit-codes-errors.md` for the error schema that pairs with this
envelope; `shell-compat.md` for per-shell consumption patterns; and
`rust-implementation.md` §2 for the `Response<T>` generic.*
