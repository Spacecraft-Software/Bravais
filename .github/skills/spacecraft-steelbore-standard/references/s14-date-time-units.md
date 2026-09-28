<!-- Part of spacecraft-steelbore-standard — see SKILL.md for the index -->
## §14 — Date, Time & Units

### §14.1 — Date & Time Format Rules

| Concern      | Rule                                                             | Example                      |
|--------------|------------------------------------------------------------------|------------------------------|
| Date format  | ISO 8601 only: `YYYY-MM-DD`                                      | `2026-03-08`                 |
| Time format  | 24-hour only: `HH:MM:SS` — AM/PM is **never** permitted          | `14:30:00`                   |
| Timestamp    | Combined ISO 8601 UTC: `YYYY-MM-DDTHH:MM:SSZ`                    | `2026-03-08T14:30:00Z`       |
| Timezone     | **UTC Z is the default and preferred primary** for general-purpose, cross-system, and machine-readable timestamps. A project whose core domain is inherently local-time-bound (e.g., solar/prayer-time calculations) may declare local time as its primary record instead — a documented exception, not a free choice. See §14.2 and §14.2.1 | `Z` not `+00:00`             |
| Duration     | ISO 8601 duration format only                                    | `PT1H30M` not "1h 30m"       |
| Units        | Metric (SI) primary; imperial in parentheses only if locale requires | `100 km (62 mi)`         |

Apply these conventions to all generated code, documentation, comments, and any
user-facing strings. Never output AM/PM time, non-ISO dates, or imperial-primary units.

### §14.2 — UTC Z Timezone Policy

**UTC Z is the default and preferred timezone for stored, transmitted, logged,
and committed timestamps across Spacecraft Software projects.** It is the
convention every project should reach for first — it keeps cross-project tooling,
sorting, and interchange simple and unambiguous. Under this default, the `Z`
suffix is required on primary timestamps, and local time expressed as a UTC
offset (e.g., `2026-05-24T13:34:55+03:00`) may optionally accompany a UTC Z value
as a secondary, human-convenience field — but UTC Z remains the authoritative
record.

This is a strong default, not a universal mandate forced onto every domain
regardless of fit — §14.2.1 documents the exception that lets a project whose
domain is genuinely local-time-bound use local time as its primary record instead.

**Rules for projects under the UTC Z default — apply unless a project has filed
the §14.2.1 exception:**

| Rule | Detail |
|------|--------|
| `Z` suffix required | Every **primary** stored/transmitted timestamp MUST end with `Z`. `2026-03-08T14:30:00Z` ✓. A companion local-time field with UTC offset is permitted alongside it. |
| No offset notation as replacement | Offset notation (`+03:00`, `-05:00`, etc.) is **forbidden as a replacement** for UTC Z. It is permitted only as an optional companion field alongside a `Z`-suffixed primary. |
| No bare local time in data | Local-time timestamps **without** timezone info are **forbidden** in files, databases, logs, API responses, and commits. |
| Log entries use UTC + `Z` | Every log line timestamp must be `YYYY-MM-DDTHH:MM:SS.sssZ` (millisecond precision encouraged). |
| Commit timestamps use UTC | `GIT_COMMITTER_DATE` and `GIT_AUTHOR_DATE` must be UTC when set programmatically. |
| File metadata written by Spacecraft Software tools | mtime/ctime written by Spacecraft Software tools must be UTC-sourced. |

### §14.2.1 — Domain Exception: Inherently Local-Time-Bound Projects

A project whose core domain is fundamentally defined by **local civil or solar
time** — not by a moment in absolute (UTC) time — may declare local time as the
**primary** representation for that domain's data. Examples: prayer-time
calculations (`Mawaqit`), sunrise/sunset tables, local event or business-hours
scheduling. For data like this, the meaningful value *is* "06:14 local, at this
place" — collapsing it to a UTC instant first and treating that as authoritative
would misrepresent what the data actually is.

**Conditions for the exception:**

1. **Document it.** The project's README or spec must state explicitly which
   data uses local time as primary, and the *domain* reason why — not developer
   or user convenience.
2. **Keep the default everywhere else.** General-purpose machinery within the
   same project — logs, commit timestamps, internal cross-system APIs,
   telemetry — still follows the §14.2 UTC Z default. The exception covers the
   domain data itself, not the whole project.
3. **Preserve UTC derivability.** Store or compute the IANA timezone (e.g.,
   `Africa/Cairo`) alongside the local value, so a UTC instant remains derivable
   for interchange, comparison, and storage portability.
4. **This is an exception, not an escape hatch.** "Local time is more
   convenient" or "our users are mostly in one timezone" do not qualify — the
   domain itself must be inherently local-time-bound.

### §14.3 — Local Time as Optional Companion

**For projects under the UTC Z default** (§14.2), local time expressed as a UTC
offset is permitted as an **optional companion** to the UTC Z primary value — in
human-facing display, in API responses (as an additional field, never replacing
the UTC Z field), and in stored records where timezone context aids human
readers. The UTC Z value is always present and always authoritative; the
local-time companion is supplemental only. (A project operating under the
§14.2.1 domain exception inverts these roles for its domain data — local time is
primary there, with UTC kept derivable rather than displayed as authoritative.)

- The `--absolute-time` flag (defined in `spacecraft-cli-standard` §3) disables
  relative-time rendering but always renders as UTC, not local time.
- If a future CLI wants to show local time in human mode, it MUST:
  1. Accept a `--tz <IANA-zone>` flag (e.g., `--tz Africa/Cairo`).
  2. Render local time only to stdout in human mode — never in `--json` output.
  3. Always include the UTC value alongside the local rendering.
  4. Never persist or transmit the local-time rendering.
- JSON/machine output (`--format json/jsonl/yaml/csv`) MUST always use UTC + `Z`.

### §14.4 — Duration Format

Durations follow ISO 8601 duration notation:

| Format   | Example   | Meaning             |
|----------|-----------|---------------------|
| `PTnHnMnS` | `PT1H30M` | 1 hour 30 minutes |
| `PnD`    | `P7D`     | 7 days              |
| `PnYnM`  | `P1Y6M`   | 1 year 6 months     |

Prose forms like "1h 30m", "90 minutes", "1.5 hours" are **forbidden** in
machine-readable output. They are acceptable in `--help` text only.

### §14.5 — Rust Implementation Guidance

When writing Rust code that handles time:

| Concern | Rule |
|---------|------|
| Crate choice | Use `jiff` (preferred) or `chrono` — never `time` 0.1.x |
| UTC type | `jiff::Timestamp` or `chrono::DateTime<chrono::Utc>` for all stored values |
| Local type | `chrono::Local` and `jiff::Zoned` (with non-UTC zone) are **forbidden** in serialized output |
| Serialization | Always serialize as `"2026-03-08T14:30:00Z"` (string, ISO 8601, `Z` suffix) |
| `serde` | Use `#[serde(with = "...")]` or a newtype that enforces UTC on deserialization |
| `SystemTime` | Acceptable for internal durations; convert to UTC ISO 8601 string before any output |
| No `NaiveDateTime` in output | `chrono::NaiveDateTime` has no timezone — forbidden in any serialized or logged value |

---

