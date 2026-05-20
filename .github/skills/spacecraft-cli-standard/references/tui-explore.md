# TUI Mode — `--format explore`

**Scope.** The `explore` output format is a Terminal User Interface (TUI)
for interactively browsing, filtering, and navigating structured output.
Inspired by Anthropic's `ant --format explore` and Nushell's `explore`
command. This reference defines activation rules, behavioral requirements,
keybindings, the Spacecraft Software palette mapping, and implementation constraints
(ratatui + crossterm).

---

## §1 — Activation & Graceful Degradation

### Activation

- Flag: `--format explore`. Short alias: `-E`.
- Requires stdout to be a TTY.

### Mandatory fallbacks

1. **Non-TTY stdout.** If stdout is piped/redirected, the TUI MUST NOT
   activate. Fall back to `--format json`, emit a warning to stderr, and
   serve the full data payload.

2. **Agent environment.** If `AI_AGENT=1` or `AGENT=1` is set, the TUI MUST
   NOT activate. Fall back to `--format json` and warn on stderr. This
   prevents agents from being trapped in an interactive render loop — a
   well-documented failure mode in the pre-Standard era.

3. **`TERM=dumb`.** Same as above: fall back to `--format json` and warn.

4. **CI mode.** `CI=true` without an explicit `--format explore` override
   also falls back to `--format json`.

The fallback warning to stderr MUST be structured when machine mode is
active:

```json
{
  "warning": {
    "code": "TUI_FALLBACK",
    "message": "Interactive explore mode unavailable; falling back to --format json",
    "reason": "stdout is not a TTY",
    "timestamp": "2026-04-10T14:30:00Z"
  }
}
```

---

## §2 — Behavioral Requirements

The TUI MUST implement:

### Keybindings (dual CUA + Vim, simultaneously active)

| Action | CUA | Vim |
|--------|-----|-----|
| Move up | ↑ | `k` |
| Move down | ↓ | `j` |
| Move left | ← | `h` |
| Move right | → | `l` |
| Page up | PgUp | `Ctrl+B` |
| Page down | PgDn | `Ctrl+F` |
| Go to top | Home | `gg` |
| Go to bottom | End | `G` |
| Cycle focus | Tab | `w` |
| Activate / expand row | Enter | Enter |
| Search/filter | `/` | `/` |
| Next search match | F3 | `n` |
| Previous search match | Shift+F3 | `N` |
| Cycle sort on current column | `s` | `s` |
| Export current view to file | `e` | `e` |
| Quit | `Esc` or `Ctrl+C` | `:q` or `q` |
| Help | F1 | `?` |

Both binding sets MUST be live simultaneously — no mode toggle. This is the
Spacecraft Software Standard dual-keybinding requirement.

### Required interactions

- **Inline search/filter.** Press `/`, type a substring, hit Enter. Filters table rows by substring match against the concatenation of all visible fields. Clear with Esc.
- **Column sorting.** Press `s` while a column header is focused to cycle: ascending → descending → none.
- **Detail view.** Press Enter on a row to expand a full record view showing every field in the JSON schema, including fields hidden from the summary table (pagination tokens, internal IDs, full timestamps).
- **Export.** Press `e` to prompt for a filename and write the current filtered/sorted view as a JSON document (with full envelope) to that file. Use the Wizard Fallback pattern for the prompt (see `validation-safety.md` §3).

---

## §3 — Color Palette Mapping

The TUI MUST use the Spacecraft Software six-token palette exclusively. No ad-hoc
colors. Honor `NO_COLOR` — in that case, render monochromatic with attribute-
based emphasis (bold, underline, reverse video) instead.

| Role | Token | Hex |
|------|-------|-----|
| Backgrounds, chrome fill | Void Navy | `#000027` |
| Body data values | Molten Amber | `#D98E32` |
| Borders, table headers, section dividers | Steel Blue | `#4B7EB0` |
| Selected / active / success | Radium Green | `#50FA7B` |
| Errors, invalid input | Red Oxide | `#FF5C5C` |
| Metadata, type hints, dimmed text | Liquid Coolant | `#8BE9FD` |

Font choice is terminal-driven; the TUI does not specify typography.
(Spacecraft Software's Share Tech Mono / Inconsolata preferences apply to the user's
terminal config, not to CLI output.)

---

## §4 — Alt-Screen Buffer and Stdout Contract

- The TUI MUST render to the **alternate screen buffer** (crossterm's
  `EnterAlternateScreen` / `LeaveAlternateScreen`). On exit, the user's
  previous terminal contents are preserved.
- All TUI rendering goes to stderr or the alternate screen buffer. **The
  final selected/exported data (if any) MUST be emitted to stdout as JSON
  upon exit**, enabling pipelines like:

  ```sh
  mytool list -E | jaq '.name'
  ```

  If the user quits without selecting/exporting, stdout is empty and the
  exit code is 0.

- Clean shutdown on SIGINT (`Ctrl+C`): restore main screen, disable raw
  mode, flush stderr. No corrupted terminal state on exit — ever.

---

## §5 — Implementation Constraints

### Framework

- **Pure Rust. No C dependencies.**
- **Recommended stack:** `ratatui` for widgets + `crossterm` for the terminal backend. Both are pure Rust and Spacecraft Software-compatible (see `spacecraft-cli-preference` / references for the broader ecosystem).

### Feature gating

TUI code MUST be gated behind a Cargo feature flag so that headless /
server / embedded deployments can build without TUI dependencies:

```toml
# Cargo.toml
[features]
default = ["tui"]
tui = ["dep:ratatui", "dep:crossterm"]

[dependencies]
ratatui = { version = "0.28", optional = true }
crossterm = { version = "0.28", optional = true }
```

The `--format explore` flag MUST be compiled out (or emit a structured
error) when the `tui` feature is disabled:

```rust
#[cfg(not(feature = "tui"))]
{
    return Err(AppError {
        code: "FEATURE_UNAVAILABLE".into(),
        exit_code: 2,
        message: "This build was compiled without TUI support".into(),
        hint: "Rebuild with --features tui, or use --format json".into(),
        // ...
    });
}
```

### Raw mode discipline

- **`isatty()` check is mandatory before entering raw mode.** Entering raw mode on a non-TTY corrupts the stream.
- **Panic hook that restores the terminal.** Install `std::panic::set_hook` to disable raw mode + leave the alternate screen before the default panic handler prints the payload. Otherwise, a panic leaves the terminal unusable.
- **Never enter raw mode in CI.** The `AI_AGENT` / `CI` / `TERM=dumb` checks in §1 must fire before any `crossterm::terminal::enable_raw_mode` call.

### Binary size

- The TUI feature typically adds 300-800 KB to the release binary. This is fine for the default build but must be opt-out-able for embedded / bootloader / library-only consumers (e.g., Zamak doesn't need TUI in its build binary).

---

## §6 — Data Model

The TUI operates on the **same data model** as `--format json`. It does not
invent new fields; it presents the JSON envelope's `data` field in a
navigable view.

- **List commands → table view.** Columns derived from the union of keys in `data[*]`. Hidden-by-default columns (IDs, tokens) visible in detail view.
- **Get/detail commands → record view.** All fields shown, nested objects collapsible.
- **Paginated output** uses `metadata.pagination` for "load more" navigation. When the user scrolls past the current page, the TUI fetches the next page automatically using `metadata.pagination.next_token`.

---

## §7 — Common Mistakes (Don't)

- Entering raw mode without an `isatty` check. Corrupts pipes.
- Omitting the panic hook. A panic mid-TUI leaves the terminal in a broken state (cursor hidden, raw mode on).
- Emitting TUI rendering to stdout instead of stderr / alt-screen. Breaks pipelines.
- Using hard-coded colors instead of palette tokens. Violates the Spacecraft Software brand.
- Activating the TUI when `AI_AGENT=1`. Agents get trapped.
- Omitting the `tui` feature flag. Headless builds drag in `ratatui` + `crossterm` unnecessarily.
- Making `e` (export) require interactive file-picker confirmation in non-TTY fallback mode. (It shouldn't even be reachable in non-TTY mode, but double-check.)

---

*See also: `output-modes.md` for the activation cascade that routes into
TUI; `validation-safety.md` §3 for the Wizard Fallback pattern used in
TUI prompts; `rust-implementation.md` §7 for a complete ratatui skeleton.*
