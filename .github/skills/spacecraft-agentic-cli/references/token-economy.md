# Token Economy — Designing for the Agent's Context Budget

When an AI agent invokes a Spacecraft Software CLI, every byte of stdout flows
through the agent's tokenizer and consumes its context window. A naive
CLI that emits a 50 KB JSON envelope when a 2 KB summary would suffice
costs the agent ~12,500 tokens — a meaningful chunk of any context
window, and a direct dollar cost on each invocation.

This reference catalogs the levers Spacecraft Software CLIs offer to control token
cost: `--fields` field selection, `--format jsonl` streaming, MCP lazy
schema loading, null-field omission, and compact JSON serialization.

## Table of contents

- §1 — The token cost lens
- §2 — `--fields` for field selection
- §3 — `--format jsonl` for streaming
- §4 — Null-field omission
- §5 — Compact JSON in non-TTY mode
- §6 — MCP lazy schema loading
- §7 — Pagination with `next_token`
- §8 — Anti-patterns

---

## §1 — The token cost lens

Quick conversion ratios (GPT-4 / Claude tokenizer approximations):

| Bytes | Tokens (approx) |
|-------|-----------------|
| 1 KB  | 250             |
| 4 KB  | 1,000           |
| 16 KB | 4,000           |
| 64 KB | 16,000          |

A 200K context window holds ~800 KB of total text. Reserving 100 KB for
agent system prompts, conversation history, and tool definitions leaves
~700 KB for tool output. A list command returning 500 records of 1 KB
each consumes 500 KB — 70% of the available window for ONE invocation.

The Spacecraft Software agent-economy goal: **a typical CLI invocation should cost
< 5 KB of output** unless the agent explicitly requests more. The levers
in this document help achieve that.

---

## §2 — `--fields` for field selection

The `--fields` global flag (mandated by `spacecraft-cli-standard` §3)
restricts the JSON envelope's `data` array to listed fields:

```bash
# Full record (~1 KB per cmdlet)
ferrocast cmdlet list --json
# {"metadata": {...}, "data": [{"name": "Get-Process", "module": "...",
#  "synopsis": "...", "examples": [...], "parameters": [...], ...}]}

# Trimmed to two fields (~80 bytes per cmdlet)
ferrocast cmdlet list --json --fields name,module
# {"metadata": {...}, "data": [{"name": "Get-Process", "module": "Microsoft.PowerShell.Management"}]}
```

### Implementation pattern

```rust
#[derive(Serialize, JsonSchema)]
struct Cmdlet {
    name: String,
    module: String,
    synopsis: String,
    parameters: Vec<Parameter>,
    examples: Vec<Example>,
}

fn project_fields<T: Serialize>(records: Vec<T>, fields: Option<&[String]>) -> serde_json::Value {
    let value = serde_json::to_value(records).unwrap();
    let Some(field_list) = fields else { return value; };
    project_value(value, field_list)
}

fn project_value(v: serde_json::Value, fields: &[String]) -> serde_json::Value {
    use serde_json::Value;
    match v {
        Value::Array(items) => Value::Array(
            items.into_iter().map(|item| project_value(item, fields)).collect()
        ),
        Value::Object(map) => {
            let mut new_map = serde_json::Map::new();
            for f in fields {
                if let Some(val) = map.get(f) {
                    new_map.insert(f.clone(), val.clone());
                }
            }
            Value::Object(new_map)
        }
        other => other,
    }
}
```

The `--fields` projection happens AFTER serialization so it works
uniformly across all data types without per-struct support.

### Discoverability

Fields available for projection are listed in the schema output. The
agent reads `<tool> schema cmdlet list` to discover field names, then
constructs `--fields` accordingly. This closes the loop: schema-driven
field selection without hallucinated field names.

### Always-included fields

Three fields are ALWAYS included regardless of `--fields`:

- `metadata.tool` — identifies the source tool
- `metadata.command` — what was invoked
- `metadata.timestamp` — when (ISO 8601 UTC)

These are essential for the agent to confirm it's looking at the right
data and are tiny (< 100 bytes total).

---

## §3 — `--format jsonl` for streaming

For commands that may return many records, `jsonl` (newline-delimited
JSON) lets the agent process records as they arrive:

```bash
ferrocast cmdlet list --format jsonl
# {"name": "Get-Process", "module": "..."}
# {"name": "Get-Service", "module": "..."}
# {"name": "Get-EventLog", "module": "..."}
# ...
```

### When to prefer jsonl over json

| Condition | Format |
|-----------|--------|
| <50 records expected | `json` |
| >50 records or unknown count | `jsonl` |
| Agent doing partial-result early-exit | `jsonl` |
| Result will be saved to disk | `json` (smaller for grep/jq) |
| Processing in a Nushell `each {}` block | `jsonl` |
| Processing as a single PowerShell array | `json` |

### jsonl envelope rules

In jsonl mode, the metadata wrapper is dropped — each line IS the data
record. To carry metadata, emit a single header line first with type
discrimination:

```jsonl
{"_type": "metadata", "tool": "ferrocast", "command": "ferrocast cmdlet list", "timestamp": "2026-04-10T14:30:00Z"}
{"_type": "record", "name": "Get-Process", "module": "..."}
{"_type": "record", "name": "Get-Service", "module": "..."}
{"_type": "summary", "count": 142}
```

Or, simpler and more common: skip the wrapper entirely and emit raw
records. The agent learns to ignore metadata in jsonl mode. Most
Spacecraft Software CLIs follow the simpler pattern.

---

## §4 — Null-field omission

Default Rust serde_json serialization includes `null` for None values:

```json
{
  "name": "Get-Process",
  "module": "Microsoft.PowerShell.Management",
  "synopsis": null,
  "deprecated_since": null,
  "replaced_by": null
}
```

Three null fields = ~75 wasted bytes per record. Across 500 records,
that's 37 KB of pure null noise.

The fix is universal in Spacecraft Software CLIs:

```rust
#[derive(Serialize)]
struct Cmdlet {
    name: String,
    module: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    synopsis: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    deprecated_since: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    replaced_by: Option<String>,
}
```

Or, project-wide via `serde` container attribute:

```rust
#[derive(Serialize)]
#[serde(default)]
struct Cmdlet {
    // All Option<T> fields automatically omitted when None
}
```

### Empty collection omission

Similarly, empty Vecs and HashMaps:

```rust
#[derive(Serialize)]
struct Cmdlet {
    name: String,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    examples: Vec<Example>,
    #[serde(skip_serializing_if = "HashMap::is_empty")]
    aliases: HashMap<String, String>,
}
```

A Cmdlet with no examples emits `{"name": "Get-Process"}`, not
`{"name": "Get-Process", "examples": []}`.

---

## §5 — Compact JSON in non-TTY mode

When stdout is a TTY (human mode), pretty-printed JSON aids visual
scanning:

```json
{
  "metadata": {
    "tool": "ferrocast",
    "version": "0.1.0"
  },
  "data": [
    {
      "name": "Get-Process",
      "module": "Microsoft.PowerShell.Management"
    }
  ]
}
```

When stdout is NOT a TTY (agent or pipe), compact JSON saves bytes:

```json
{"metadata":{"tool":"ferrocast","version":"0.1.0"},"data":[{"name":"Get-Process","module":"Microsoft.PowerShell.Management"}]}
```

The pretty version is ~30% larger due to whitespace. Spacecraft Software CLIs
compute this once at startup based on `OutputMode`:

```rust
fn serialize_response<T: Serialize>(response: &Response<T>, mode: &OutputMode) -> String {
    if mode.is_tty() && mode.format == OutputFormat::Json {
        serde_json::to_string_pretty(response).unwrap()
    } else {
        serde_json::to_string(response).unwrap()
    }
}
```

The user can override with `--format json` (forces compact) or
`--format json --pretty` (forces pretty). Don't add `--pretty` until
asked — it's rarely needed.

---

## §6 — MCP lazy schema loading

The naive MCP `tools/list` response sends every tool's full schema:

```json
{
  "tools": [
    { "name": "ferrocast_cmdlet_list", "description": "...", "inputSchema": { 1500-byte schema }},
    { "name": "ferrocast_cmdlet_get", "description": "...", "inputSchema": { 1200-byte schema }},
    { "name": "ferrocast_module_list", "description": "...", "inputSchema": { 800-byte schema }},
    ... 30 more tools ...
  ]
}
```

Total: ~50 KB consumed in context just to advertise tools the agent may
never call.

The Spacecraft Software lazy pattern advertises minimal info:

```json
{
  "tools": [
    { "name": "ferrocast_cmdlet_list", "description": "List available cmdlets" },
    { "name": "ferrocast_cmdlet_get", "description": "Get cmdlet details by name" },
    { "name": "ferrocast_module_list", "description": "List loaded modules" }
  ]
}
```

Total: ~3 KB. Full schemas load via `tools/get` when the agent decides
to invoke a tool:

```json
// Request
{ "method": "tools/get", "params": { "name": "ferrocast_cmdlet_list" } }

// Response
{
  "name": "ferrocast_cmdlet_list",
  "description": "List available cmdlets",
  "inputSchema": { ... full schema ... }
}
```

### Implementation hint

Use the `rmcp` crate (Rust MCP) or hand-roll the JSON-RPC; either way,
the server's `tools/list` handler returns the minimal envelope and the
`tools/get` handler returns the full schema for one tool. Cache the full
schemas in memory — they don't change between calls.

The reduction: from ~50 KB advertised to ~3 KB advertised, saving 47 KB
(~12,000 tokens) per MCP session. Anthropic's `ant`, Cursor, and Claude
Code all implement variants of this pattern.

---

## §7 — Pagination with `next_token`

Large result sets must paginate. The metadata wrapper carries pagination
info:

```json
{
  "metadata": {
    "pagination": {
      "page": 1,
      "per_page": 50,
      "total": 142,
      "next_token": "eyJvZmZzZXQiOjUwfQ"
    }
  },
  "data": [ ... 50 records ... ]
}
```

The agent passes `--page-token <next_token>` (or `--page 2`) to retrieve
the next chunk. The token is opaque — agents MUST NOT parse it; the
server interprets it.

### Default page size

| Profile | Default `per_page` |
|---------|--------------------|
| `AI_AGENT=1` | 50 |
| `AGENT=1` | 50 |
| `CI=true` | 100 |
| Human (TTY) | 25 |

Agent profile uses 50 because most agent context budgets accommodate
~50 KB output per invocation comfortably. CI uses 100 because logs can
hold larger payloads. Human TTY uses 25 because terminal scrollback is
limited.

The user can override with `--per-page <n>` up to a server-defined
maximum (typically 500).

---

## §8 — Anti-patterns

### Anti-pattern: pretty-printing everything

Default to compact JSON when stdout is non-TTY. Pretty output is ~30%
larger and serves no agent need. If a developer wants pretty output for
debugging, they can pipe through `jq .`:

```bash
ferrocast cmdlet list --json | jq .
```

### Anti-pattern: nesting deeply

Deep JSON nesting wastes tokens on bracket overhead. Flatten where
possible:

**Wrong (deep):**
```json
{
  "data": [{
    "metadata": {
      "version": {
        "release": {
          "name": "Get-Process"
        }
      }
    }
  }]
}
```

**Right (flat):**
```json
{
  "data": [{
    "release_name": "Get-Process"
  }]
}
```

PowerShell's `ConvertFrom-Json` also defaults to depth 2 — flat shapes
work better cross-shell.

### Anti-pattern: verbose field names

`registered_command_line_argument_count` consumes ~12 tokens. `arg_count`
consumes ~2. Use snake_case but keep names tight. Don't sacrifice
clarity, but don't pad either.

### Anti-pattern: redundant data

Sending the same data multiple times in the same response — e.g., once
in `data[].name` and once in a `data[].metadata.name` — doubles the cost.
Eliminate redundancy. The agent has the schema; it can derive computed
fields.

### Anti-pattern: returning raw HTML or pre-rendered tables

Some legacy CLIs emit ASCII tables or HTML in their JSON output as a
"convenience." Don't. Agents parse JSON, not tables. The human-mode
table is rendered in human mode; the JSON-mode output is pure data.

---

*End of token-economy.md*
