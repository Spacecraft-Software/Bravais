# LLM Tool-Calling — Schema Output for Function-Calling APIs

The `<tool> schema` sub-command (mandated by `spacecraft-cli-standard` §2
Rule 4) emits JSON Schema describing every command's input and output.
Beyond human reference, this output must be **directly droppable** into
the function-calling APIs of the major LLM providers. This reference
specifies the per-provider format requirements and the wrapping
adapters Spacecraft Software CLIs ship.

## Table of contents

- §1 — The four target formats
- §2 — Anthropic format (default — JSON Schema Draft 2020-12)
- §3 — OpenAI format
- §4 — Google Gemini format
- §5 — MCP `tools/list` format
- §6 — `--format <provider>` flag
- §7 — Per-provider gotchas
- §8 — The `examples` array discipline

---

## §1 — The four target formats

| Provider | API surface | Wrapper required? |
|----------|-------------|-------------------|
| Anthropic Messages API | `tools[].input_schema` | No — direct paste |
| OpenAI Chat Completions / Responses API | `tools[].function.parameters` | Yes — `{type, function: {name, description, parameters}}` |
| Google Gemini | `tools[].function_declarations[].parameters` | Yes — `{name, description, parameters}` |
| MCP | `tools[].inputSchema` | No — direct paste |

The Anthropic and MCP formats are identical at the schema level. The
default `<tool> schema --format json` output equals these two; the
provider-specific flags add wrappers.

---

## §2 — Anthropic format (default)

JSON Schema Draft 2020-12, no wrapper. The schema sub-command emits this
by default:

```json
{
  "name": "ferrocast_cmdlet_list",
  "description": "List available cmdlets, optionally filtered by module",
  "input_schema": {
    "type": "object",
    "properties": {
      "module": {
        "type": "string",
        "description": "Filter cmdlets to those in the named module"
      },
      "fields": {
        "type": "array",
        "items": { "type": "string" },
        "description": "Restrict output to listed fields (token economy)"
      }
    },
    "required": []
  }
}
```

Direct paste into the Anthropic API:

```python
client.messages.create(
    model="claude-opus-4-7",
    tools=[<paste schema output here>],
    messages=[...]
)
```

### Anthropic-specific rules

- `name` MUST match `^[a-zA-Z0-9_-]{1,64}$`. Use snake_case from the
  command path (`ferrocast cmdlet list` → `ferrocast_cmdlet_list`).
- `description` SHOULD be ≤ 1024 chars; lean prose, no marketing.
- `input_schema` is JSON Schema Draft 2020-12.
- Tool names within a single API request MUST be unique.

---

## §3 — OpenAI format

Wraps the schema in a `function` envelope:

```json
{
  "type": "function",
  "function": {
    "name": "ferrocast_cmdlet_list",
    "description": "List available cmdlets, optionally filtered by module",
    "parameters": {
      "type": "object",
      "properties": {
        "module": {
          "type": "string",
          "description": "Filter cmdlets to those in the named module"
        },
        "fields": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Restrict output to listed fields"
        }
      },
      "required": [],
      "additionalProperties": false
    },
    "strict": true
  }
}
```

### OpenAI-specific rules

- The outer `type: "function"` is required (vs. future `type: "code_interpreter"`).
- `parameters` is JSON Schema, but a SUBSET — see gotchas in §7.
- For `strict: true` mode (recommended): `additionalProperties: false`
  is REQUIRED on every object schema; every property MUST appear in
  `required` (no optional properties — make them nullable instead).
- `description` on every parameter is REQUIRED for strict mode.

The strict mode constraints push toward simpler schemas. For Spacecraft Software
CLIs, the `<tool> schema --format openai` output emits strict-compatible
schemas: optional parameters become nullable types, every property is in
`required`.

---

## §4 — Google Gemini format

Wraps in a `function_declarations` envelope:

```json
{
  "function_declarations": [
    {
      "name": "ferrocast_cmdlet_list",
      "description": "List available cmdlets, optionally filtered by module",
      "parameters": {
        "type": "OBJECT",
        "properties": {
          "module": {
            "type": "STRING",
            "description": "Filter cmdlets to those in the named module"
          },
          "fields": {
            "type": "ARRAY",
            "items": { "type": "STRING" },
            "description": "Restrict output to listed fields"
          }
        },
        "required": []
      }
    }
  ]
}
```

### Gemini-specific rules

- Type names are UPPERCASE (`OBJECT`, `STRING`, `ARRAY`, `INTEGER`,
  `NUMBER`, `BOOLEAN`).
- The outer key is `function_declarations` (array), not `tools`.
- `oneOf` / `anyOf` / `allOf` are NOT supported. Flatten them out before
  emission, or omit the constraint.
- `enum` IS supported on STRING types only.
- `format` keyword IS supported for limited values (`date-time`, `enum`).
- `additionalProperties` is ignored (no strict mode equivalent).

---

## §5 — MCP `tools/list` format

When the CLI's MCP server (`<tool> mcp`) advertises tools, it uses MCP's
own envelope:

```json
{
  "tools": [
    {
      "name": "ferrocast_cmdlet_list",
      "description": "List available cmdlets, optionally filtered by module",
      "inputSchema": {
        "type": "object",
        "properties": {
          "module": {
            "type": "string",
            "description": "Filter cmdlets to those in the named module"
          }
        },
        "required": []
      }
    }
  ]
}
```

`inputSchema` is JSON Schema Draft 2020-12, identical to the Anthropic
`input_schema` field except for the camelCase key name. The MCP server's
`tools/list` response uses this format; lazy-loaded `tools/get` returns
the full schema including output schema and examples.

---

## §6 — `--format <provider>` flag

The schema sub-command MUST support these format values:

| `--format` value | Output |
|------------------|--------|
| `json` (default) | Anthropic / MCP raw JSON Schema |
| `anthropic` | Same as `json` |
| `openai` | OpenAI-wrapped, strict-compatible |
| `gemini` | Gemini-wrapped, uppercase types |
| `mcp` | MCP-wrapped (`tools/list` shape) |

Examples:

```bash
ferrocast schema cmdlet list                    # Anthropic / MCP raw
ferrocast schema cmdlet list --format openai    # OpenAI strict
ferrocast schema cmdlet list --format gemini    # Gemini
ferrocast schema --format mcp                   # All commands, MCP shape
```

When invoked without `<noun> <verb>`, the schema sub-command emits the
**full tool surface** (every command) in the requested format.

---

## §7 — Per-provider gotchas

### OpenAI: strict mode requires nullable optionals

OpenAI strict mode disallows optional properties. Spacecraft Software's idiomatic
optional argument:

```rust
#[derive(Args, Serialize, JsonSchema)]
pub struct CmdletListArgs {
    /// Filter cmdlets to those in the named module
    #[arg(long)]
    pub module: Option<String>,
}
```

Generates JSON Schema:

```json
{
  "properties": {
    "module": { "type": ["string", "null"] }
  },
  "required": ["module"]
}
```

The schemars feature flag `nullable_as_one_of=false` produces this shape.

### Gemini: no oneOf / anyOf / allOf

Spacecraft Software commands that take "string OR list of strings" arguments must
flatten before Gemini emission:

**Schema with `oneOf`:**
```json
{
  "module": {
    "oneOf": [
      { "type": "string" },
      { "type": "array", "items": { "type": "string" } }
    ]
  }
}
```

**Gemini-flattened:**
```json
{
  "module": {
    "type": "ARRAY",
    "items": { "type": "STRING" },
    "description": "Module name(s); single string is also accepted"
  }
}
```

Document the flexibility in `description` since the type system can't
express it.

### MCP: inputSchema vs input_schema casing

The Anthropic Messages API uses `input_schema` (snake_case). The MCP
spec uses `inputSchema` (camelCase). Both contain identical JSON Schema.
Don't mix them — the API will silently accept the wrong key and emit a
"missing schema" error at tool-invocation time.

### All providers: `enum` validation

Spacecraft Software CLIs use `enum` for restricted-value parameters
(`--format json|jsonl|yaml|csv|explore`). All four providers honor enum
on string types. Always emit:

```json
{
  "format": {
    "type": "string",
    "enum": ["json", "jsonl", "yaml", "csv", "explore"],
    "description": "Output format"
  }
}
```

The enum tells the LLM exactly which values are valid, cutting
hallucination on parameter values.

---

## §8 — The `examples` array discipline

The schema output MUST include an `examples` array. Each example:

```json
{
  "examples": [
    {
      "description": "List all cmdlets",
      "command": "ferrocast cmdlet list --json",
      "expected_exit_code": 0
    },
    {
      "description": "List cmdlets in the 'Microsoft.PowerShell.Utility' module",
      "command": "ferrocast cmdlet list --module Microsoft.PowerShell.Utility --json",
      "expected_exit_code": 0
    }
  ]
}
```

### Example discipline rules

- **Every command** has at least 2 examples.
- **At least one example** demonstrates `--json` mode.
- **Examples must be runnable** — CI tests parse the schema and execute
  every example, asserting the documented exit code.
- **Examples avoid placeholders** — use `<repo>` only when a real value
  would leak data; otherwise use a documented stable example value.
- **Examples avoid shell pipelines** — the command string is the literal
  argv invocation, not `ferrocast cmdlet list --json | jq '.data'`. The
  agent will compose pipelines on its own.

---

## §9 — Output schema (response shape)

In addition to `input_schema`, the schema output MUST include an
`output_schema` describing the JSON envelope shape:

```json
{
  "name": "ferrocast_cmdlet_list",
  "description": "...",
  "input_schema": { ... },
  "output_schema": {
    "type": "object",
    "properties": {
      "metadata": { "$ref": "#/definitions/Metadata" },
      "data": {
        "type": "array",
        "items": { "$ref": "#/definitions/Cmdlet" }
      }
    },
    "required": ["metadata", "data"]
  },
  "definitions": {
    "Metadata": { ... },
    "Cmdlet": { ... }
  }
}
```

Anthropic's API doesn't currently consume output schemas, but agents
reading the schema introspection benefit from knowing the response
shape. This becomes especially important once the agent chains the
output through filters or pipes — knowing the field types prevents
incorrect post-processing.

---

*End of llm-tool-calling.md*
