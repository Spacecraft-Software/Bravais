# Shell Compatibility

**Scope.** Per-shell requirements for how Spacecraft Software CLI output is consumed
in: POSIX sh / dash / ash / Bash 5+ / Brush (P0 baseline), Nushell 0.111+
(P1 primary), PowerShell 7.6+ (P1 primary), and Ion / RedoxOS (P2
secondary). Each shell has idioms that affect JSON property typing, stderr
framing, and record separation.

---

## §1 — POSIX sh / dash / ash / Bash 5+ / Brush (P0)

The baseline. Default text output MUST work here with nothing but POSIX
utilities.

### Required behavior

- **Single-line records for list commands.** One record per line, fields tab-separated or space-aligned. `grep` / `awk` / `cut` friendly.
- **Avoid multi-line field values in text mode.** If a field legitimately contains newlines, truncate to a single line in text mode (append `…` Unicode ellipsis) and preserve the full value in `--json` mode.
- **`--print0` / `-0` for filename-safe output.** NUL-delimited records for safe consumption via `xargs -0` or `while IFS= read -r -d '' path`.
- **No Bash-isms in the tool's own shell completions or hook scripts** if POSIX compatibility is a goal. Provide separate completions for bash, zsh, fish, nushell.
- **JSON consumption** is via `jq` — or its Spacecraft Software-preferred replacement `jaq` (see `spacecraft-cli-preference`). Either way, the `--json` single-document output works directly:

```sh
mytool repo list --json | jaq '.data[].name'
```

### Brush (Rust POSIX-compatible shell)

Brush's behavioral contract guarantees identical treatment of text streams
to POSIX sh. **No Brush-specific accommodations are needed.** If it works
in POSIX sh, it works in Brush.

### Bash-specific consumption

Bash users may want array capture:

```sh
# NUL-delimited for safe filename handling
mapfile -d '' names < <(mytool repo list --print0)

# JSON via jq pipeline (jaq preferred per spacecraft-cli-preference)
readarray -t names < <(mytool repo list --json | jaq -r '.data[].name')
```

---

## §2 — Nushell 0.111+ (P1)

Nushell is Mohamed's primary shell. It consumes CLI output via the
`from json` pipeline command, which converts JSON into Nushell's typed
structured data model.

### Requirements

- **`--json` default output MUST be a single valid JSON document, not NDJSON.** Nushell's `from json` expects a complete document. Streaming use cases use `--format jsonl`, consumed with `from json --objects`.
- **Semantic JSON types matter.** Nushell's pipeline converts JSON into typed values — getting the JSON types right lets users skip coercion:

  | JSON field | Nushell type after `from json` | Conversion idiom |
  |-----------|--------------------------------|------------------|
  | ISO 8601 string | `string` | `into datetime` to get native `datetime` |
  | Integer bytes | `int` | `into filesize` to get native `filesize` |
  | ISO 8601 duration string | `string` | `into duration` |
  | JSON number | `int` or `float` (Nushell infers) | — |
  | JSON boolean | `bool` | — |
  | JSON null | `nothing` | — |

  So: filesizes are emitted as integer bytes, not `"1.2 MB"`. Dates are ISO 8601 strings, not Unix timestamps.

- **Non-zero exit correctly signals error.** Nushell since v0.98 treats non-zero exits as errors by default. The structured error on stderr (see `exit-codes-errors.md`) is visible in the `$env.LAST_EXIT_CODE` context plus stderr capture.

- **List commands → `table`.** When a command returns a list of homogeneous records, the JSON MUST be the standard envelope with `data` as an array of objects sharing consistent keys. This maps cleanly to Nushell's `table` type:

  ```nu
  mytool repo list --json | from json | get data | where stars > 100 | select name url stars
  ```

- **Optional Nushell plugins.** Spacecraft Software CLIs MAY provide a `nu-plugin-<tool>` crate for native integration, but this is not required. `--json | from json` is the primary integration path.

### Nushell pipeline example

```nu
# Filter traces by duration, keep name and output path
caliper trace list --json
  | from json
  | get data
  | where duration_ms > 1000
  | select name output_path
  | into table
```

---

## §3 — PowerShell 7.6+ (P1)

PowerShell consumes CLI output via `ConvertFrom-Json`, which produces
`PSCustomObject` instances in the .NET object pipeline.

### Requirements

- **`--json` output MUST be a single JSON document, not NDJSON.** `ConvertFrom-Json` expects a complete JSON string.
- **Nesting depth ≤ 3** without strong justification. `ConvertTo-Json` defaults to depth 2 for round-tripping; `ConvertFrom-Json` supports depth 1024 for reading, but shallow structures round-trip better.
- **snake_case is canonical. PascalCase aliases MAY be provided in parallel** for PowerShell idiomatic access (`$r.created_at` AND `$r.CreatedAt` both work). Implement via serde `#[serde(alias = "...")]` or by emitting both keys. Do NOT replace snake_case with PascalCase — snake_case is what Nushell, jq, and other consumers expect.
- **UTF-8 without BOM is mandatory.** PowerShell 7 uses UTF-8 by default, but Windows PowerShell 5.1 emits UTF-16 LE. The tool MUST NOT emit UTF-16 or rely on the system OEM code page. On Windows, set console output code page to 65001 at startup.
- **Errors on stderr MUST be single-line JSON.** PowerShell wraps each stderr line as a separate `ErrorRecord`. Multi-line JSON becomes fragmented and unparseable. Serialize error objects compactly when writing to stderr.

### PowerShell pipeline example

```powershell
$traces = mytool trace list --json | ConvertFrom-Json
$traces.data |
  Where-Object { $_.duration_ms -gt 1000 } |
  Select-Object name, output_path
```

### Windows specifics

- Detect Windows console: `GetConsoleMode` + `GetStdHandle`. TTY detection on Windows goes through `isatty` equivalents (Rust: `std::io::IsTerminal`).
- Virtual terminal sequences must be enabled for ANSI color on legacy Windows consoles (`ENABLE_VIRTUAL_TERMINAL_PROCESSING`). On Windows Terminal and ConHost post-Anniversary Update, this is fine.
- Console output code page: `SetConsoleOutputCP(65001)` at startup. Restore on exit if the tool is a short-lived utility.

---

## §4 — Ion Shell / RedoxOS (P2)

Ion is a text-stream shell with typed variables but without a structured
pipeline model like Nushell or PowerShell.

### Requirements

- **Default text output works identically to POSIX sh.** No special accommodations required.
- **Strict stdout/stderr separation matters more in Ion.** Ion's enhanced stderr redirection operators (`^>`, `^|`, `&>`, `&|`) let users pipe stderr and stdout independently — a cleanly-separating tool benefits from more granular control.
- **One record per line for Ion array capture.** Ion's `@(command)` array-splitting captures lines into an array. List commands emitting one record per line work naturally.
- **JSON parsing in Ion requires external tooling (`jq` or `jaq`).** The `--json` mode requires no special adaptation — Ion users consume JSON the same way POSIX users do, via an external JSON tool.

### Ion pipeline example

```ion
# Capture list output into an Ion array
let names = @(mytool repo list --print0 | xargs -0 -n1 echo)

# Or via JSON + jaq
let names = @(mytool repo list --json | jaq -r '.data[].name')
```

---

## §5 — Cross-Shell Contract Summary

| Property | POSIX/Bash | Brush | Nushell | PowerShell | Ion |
|----------|------------|-------|---------|------------|-----|
| Default text output format | tab/space aligned | tab/space aligned | tab/space aligned | tab/space aligned | tab/space aligned |
| `--json` as single document | required | required | required | required | required |
| `--format jsonl` for streaming | yes | yes | yes (`from json --objects`) | line-by-line via `ForEach-Object` | yes |
| Non-zero exit signals error | yes | yes | yes (v0.98+) | yes (`$LASTEXITCODE`) | yes |
| Structured error on stderr | single-line JSON | single-line JSON | single-line JSON | **MUST be single-line** | single-line JSON |
| PascalCase property aliases | unused | unused | unused | optional nice-to-have | unused |
| snake_case canonical | yes | yes | yes | yes | yes |
| NUL-delimited `--print0` | yes (xargs -0) | yes | via `from nuon` adapters | via custom parsing | yes |

If the CLI satisfies all of the above, it works in every Priority 0 and
Priority 1 shell with no per-shell code. Priority 2 (Ion) gets the same
benefits automatically.

---

## §6 — Cross-Shell Round-Trip Testing

Every Spacecraft Software CLI's CI pipeline MUST include a cross-shell round-trip
test: for each sub-command supporting `--json`, invoke it and pipe through:

1. `jaq '.'` (POSIX/Bash path).
2. `nu -c 'from json | to json'` (Nushell path).
3. `pwsh -Command 'ConvertFrom-Json | ConvertTo-Json -Depth 10'` (PowerShell path).

All three MUST round-trip without error. See `testing-compliance.md` §2 for
the test harness.

---

## §7 — Common Mistakes (Don't)

- Emitting NDJSON by default. Nushell's `from json` and PowerShell's `ConvertFrom-Json` reject it. Use `--format jsonl` for explicit streaming.
- Emitting filesizes as `"1.2 MB"` strings. Emit bytes as integers; let the shell format.
- Using PascalCase as the canonical property naming. Break Nushell and jq idioms. snake_case canonical; PascalCase alias-only.
- Multi-line JSON error objects on stderr. PowerShell fragments them.
- Relying on the system locale for encoding. UTF-8 everywhere, always.
- Shipping a bash-only completion script. Provide bash, zsh, fish, nushell.
- Forgetting `SetConsoleOutputCP(65001)` on Windows. Console emits mojibake.

---

*See also: `output-modes.md` for the envelope and `--format` variants;
`testing-compliance.md` §2 for the cross-shell round-trip harness;
`rust-implementation.md` §8 for concrete Rust patterns (`IsTerminal`,
Windows console setup, serde aliases).*
