# MCP Server Surface

**Scope.** When a Spacecraft Software CLI tool exposes more than 10 sub-commands, it
SHOULD also ship an MCP (Model Context Protocol) server surface so
non-terminal agents, multi-tenant platforms, and enterprise control planes
can consume it without shelling out. This reference defines activation,
transport selection, the one-source-of-truth schema derivation rule, and
lazy schema loading to avoid context-window bloat.

---

## §1 — When to Implement MCP

- **>10 sub-commands:** SHOULD implement MCP. The context-window overhead of CLI invocations adds up for agents doing many operations.
- **≤10 sub-commands:** MCP is optional. `<tool> <noun> <verb> --json` suffices.
- **Any sub-command count, but enterprise/multi-tenant deployment:** SHOULD implement MCP regardless of count.

CLI remains the primary interface for local development, CI/CD, and
terminal-based AI coding agents (Claude Code, OpenAI Codex CLI, Cursor,
Gemini CLI, Aider, and others). MCP is preferred for non-terminal agents,
orchestrators, and platforms.

---

## §2 — Activation

MCP server mode is activated via:

```
<tool> mcp [--transport stdio|sse|streamable-http] [--bind <addr>]
```

### Transports

| Transport | When to use | Required |
|-----------|-------------|----------|
| `stdio` | Local MCP servers invoked by an AI coding agent as a child process (Claude Code, Cursor, Claude Desktop, Codex CLI, Aider, and most MCP clients) | **yes — MUST be the default** |
| `sse` | Server-Sent Events over HTTP. For remote MCP servers behind a reverse proxy. | optional |
| `streamable-http` | Streamable HTTP transport. For cloud/hosted MCP. | optional |

**`stdio` is the default transport.** It is the most universally supported
transport and works with zero network configuration.

### Binding

- `--bind <addr>` applies only to `sse` and `streamable-http`. Default: `127.0.0.1:8080`.
- The server MUST refuse to bind to `0.0.0.0` without an explicit flag (`--bind-any` or similar), to prevent accidental exposure.

---

## §3 — One Source of Truth: Schema Derivation

The MCP server's tool definitions MUST be derived from the **same** schema
output that `<tool> schema` emits (see `schema-introspection.md`). This is
non-negotiable.

### Why

- Hand-maintained MCP tool definitions drift from the CLI. Users report: "the MCP server says this tool takes `target_dir` but the CLI needs `target-dir`."
- The schema sub-command, MCP surface, and runtime argument parser should all share the same declarative source (in Rust, `#[derive(clap::Parser, schemars::JsonSchema)]` on the same struct).

### Rule

If a new command, flag, or type is added:
1. Update the struct (single source).
2. `<tool> schema` output updates automatically.
3. MCP tool definition updates automatically.
4. Runtime argument parser updates automatically.

Any layer that requires manual synchronization is a defect.

---

## §4 — Lazy Schema Loading

MCP has a well-known context-window overhead problem: schema bloat can
consume 35× more tokens than equivalent CLI invocations when the agent
loads every tool's full schema upfront.

**The MCP server MUST implement deferred schema loading:**

1. **On connection**, the server advertises only tool **names and
   one-line descriptions** in the initial `tools/list` response. No
   parameter schemas. No output schemas.

2. **When the agent selects a tool** (via `tools/get` or equivalent), the
   server returns the full input and output schemas at that point.

3. This follows the pattern demonstrated by Claude Code's deferred MCP
   schema injection and Cursor's tool-search approach (46.9% token
   reduction, per the Cursor engineering blog).

### Example initial advertisement

```json
{
  "tools": [
    {
      "name": "caliper_trace_run",
      "description": "Execute a tracing pipeline on an input image"
    },
    {
      "name": "caliper_trace_list",
      "description": "List recent tracing jobs"
    }
  ]
}
```

### Example deferred schema fetch

When the agent selects `caliper_trace_run`, the full schema (parameters,
output schema, exit codes, examples) is delivered in the response to
`tools/get caliper_trace_run`.

---

## §5 — Tool Naming Convention

MCP tool names are derived from the CLI sub-command path:

- CLI: `caliper trace run`
- MCP tool name: `caliper_trace_run` (underscores, no hyphens, no spaces)

This convention ensures:
- MCP tool names are valid JSON Schema identifiers.
- The mapping between CLI and MCP is mechanical.
- Agents can round-trip between the two surfaces without translation.

---

## §6 — Transport-Specific Requirements

### stdio

- **Strict JSON-RPC framing.** One JSON-RPC request or response per line, newline-delimited.
- **Nothing else on stdout.** Diagnostics and logs go to stderr. Exactly like the CLI's stdout discipline — except now stdout carries JSON-RPC frames instead of `--json` output.
- **Shutdown on stdin EOF.** The server MUST terminate cleanly when stdin closes.

### sse

- Requires HTTP library (e.g., `axum` or `warp` in Rust).
- Honor standard HTTP headers: `Accept`, `Content-Type: text/event-stream`.
- CORS: disabled by default; enable only when explicitly requested.

### streamable-http

- Same as `sse` except bidirectional streaming.
- Follows the streamable HTTP MCP transport spec.

---

## §7 — Error Handling

MCP errors map directly onto the structured error schema in
`exit-codes-errors.md`:

```json
{
  "jsonrpc": "2.0",
  "id": 42,
  "error": {
    "code": -32000,
    "message": "NOT_FOUND",
    "data": {
      "exit_code": 3,
      "message": "Repository 'foo/bar' does not exist",
      "hint": "Call caliper_repo_list to see available repositories",
      "timestamp": "2026-04-10T14:30:00Z"
    }
  }
}
```

- The JSON-RPC `error.code` uses the MCP server-error range (-32000 to -32099).
- `error.message` is the stable `error.code` enum value from the CLI's structured error.
- `error.data` carries the full Spacecraft Software structured error for agent self-correction.

---

## §8 — Recommended Rust Stack

Use an off-the-shelf MCP Rust SDK rather than implementing JSON-RPC by
hand. See `rust-implementation.md` §9 for current crate recommendations.

The implementation skeleton:

1. Parse CLI args; detect `mcp` sub-command.
2. Build the tool registry from the same schema source used by
   `<tool> schema`.
3. Advertise names + descriptions only on `tools/list`.
4. On `tools/call`, dispatch to the same internal handler the CLI uses.
5. Map the handler's return (structured response or structured error) to
   JSON-RPC.

---

## §9 — Common Mistakes (Don't)

- Hand-maintaining MCP tool definitions separately from the CLI schema. Drift is guaranteed.
- Advertising every tool's full schema on connection. Context-window bloat.
- Binding to `0.0.0.0` by default for `sse` / `streamable-http`. Security footgun.
- Mixing log output into stdout in `stdio` mode. Corrupts JSON-RPC frames.
- Using hyphens in MCP tool names. Some clients reject them.
- Implementing a parallel auth / permission system in MCP. Inherit the CLI's validation rules via the shared handler.

---

*See also: `schema-introspection.md` for the schema that MCP derives from;
`exit-codes-errors.md` for the error shape mapped into JSON-RPC;
`rust-implementation.md` §9 for MCP crate recommendations.*
