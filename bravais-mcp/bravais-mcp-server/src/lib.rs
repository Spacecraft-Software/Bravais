// SPDX-License-Identifier: GPL-3.0-or-later
// Rust guideline compliant 2026-05-18

//! bravais-mcp-server — Stdio-based Model Context Protocol server.
//! Exposes environment details, command referencing, and rewriting tools.

use libbravais_mcp::{detect_shell, MappingTable, RewriteEngine};
use serde::{Deserialize, Serialize};
use std::io::{BufRead, Write};

#[derive(Debug, Deserialize)]
struct JsonRpcRequest {
    #[serde(rename = "jsonrpc")]
    _jsonrpc: String,

    method: String,
    params: Option<serde_json::Value>,
    id: Option<serde_json::Value>,
}

#[derive(Debug, Serialize)]
struct JsonRpcResponse {
    jsonrpc: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    result: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<JsonRpcError>,
    #[serde(skip_serializing_if = "Option::is_none")]
    id: Option<serde_json::Value>,
}

#[derive(Debug, Serialize)]
struct JsonRpcError {
    code: i32,
    message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    data: Option<serde_json::Value>,
}

/// Tool name for environment introspection.
///
/// MCP tool names must match `^[a-zA-Z0-9_-]{1,64}$`. Hosts namespace tools by
/// server (e.g. `mcp__bravais-cli__env`), so these stay unprefixed: a `.` or a
/// redundant `bravais-cli.` prefix would break that pattern and get the tool
/// rejected by the client.
const TOOL_ENV: &str = "env";

/// Tool name for the tool-replacement reference manual.
const TOOL_REFERENCE: &str = "reference";

/// Tool name for the shell-aware command rewriter.
const TOOL_REWRITE: &str = "rewrite";

/// Complete MCP tool definitions, each including its `inputSchema`.
///
/// This is the single source of truth for both `tools/list` and `tools/get`.
/// The MCP specification requires `tools/list` to return every tool's
/// `inputSchema` inline — the protocol has no lazy-schema negotiation, and a
/// client that receives a tool without a schema discards the whole list. Do not
/// strip schemas here to save tokens; host-side lazy loading is a harness
/// feature, not something a server can opt into.
fn tool_definitions() -> Vec<serde_json::Value> {
    vec![
        serde_json::json!({
            "name": TOOL_ENV,
            "description": "Introspect operating system and default user shell environments on Steelbore OS Bravais",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "shell": {
                        "type": "string",
                        "description": "Optional target shell override (nushell, ion, brush, bash, posix, ash, powershell)"
                    },
                    "file_hint": {
                        "type": "string",
                        "description": "Optional script file path or extension being edited"
                    }
                }
            }
        }),
        serde_json::json!({
            "name": TOOL_REFERENCE,
            "description": "Fetch detailed Purpose, Key flags, Examples, and Gotchas manual for modern tool replacements",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "tool_name": {
                        "type": "string",
                        "description": "The name of the tool (legacy or preferred) to search for references"
                    }
                },
                "required": ["tool_name"]
            }
        }),
        serde_json::json!({
            "name": TOOL_REWRITE,
            "description": "Deterministic, shell-aware command line rewriter. Translates legacy commands and flags to preferred ones",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "command": {
                        "type": "string",
                        "description": "The full command line string to parse and translate"
                    },
                    "shell": {
                        "type": "string",
                        "description": "Optional target shell override (nushell, ion, brush, bash, posix, ash, powershell)"
                    },
                    "file_hint": {
                        "type": "string",
                        "description": "Optional script file path or extension being edited"
                    }
                },
                "required": ["command"]
            }
        }),
    ]
}

/// Start the stdio MCP server loop.
pub fn run_stdio() -> Result<(), std::io::Error> {
    let stdin = std::io::stdin();
    let stdout = std::io::stdout();
    let mut stdin_lock = stdin.lock();
    let mut stdout_lock = stdout.lock();

    let table = MappingTable::load_embedded();
    let engine = RewriteEngine::new(table.clone());

    let mut line = String::new();
    while stdin_lock.read_line(&mut line)? > 0 {
        let trimmed = line.trim();
        if !trimmed.is_empty() {
            if let Ok(req) = serde_json::from_str::<JsonRpcRequest>(trimmed) {
                // `None` means the request was a notification: stay silent.
                if let Some(resp) = handle_request(req, &table, &engine) {
                    if let Ok(resp_str) = serde_json::to_string(&resp) {
                        stdout_lock.write_all(resp_str.as_bytes())?;
                        stdout_lock.write_all(b"\n")?;
                        stdout_lock.flush()?;
                    }
                }
            } else {
                // Return generic parsing error
                let resp = JsonRpcResponse {
                    jsonrpc: "2.0".to_string(),
                    result: None,
                    error: Some(JsonRpcError {
                        code: -32700,
                        message: "Parse error".to_string(),
                        data: None,
                    }),
                    id: None,
                };
                if let Ok(resp_str) = serde_json::to_string(&resp) {
                    stdout_lock.write_all(resp_str.as_bytes())?;
                    stdout_lock.write_all(b"\n")?;
                    stdout_lock.flush()?;
                }
            }
        }
        line.clear();
    }

    Ok(())
}

/// Handle one JSON-RPC request, returning the response to write back.
///
/// Returns `None` for notifications — a JSON-RPC request without an `id` — which
/// must never receive a response. `notifications/initialized` is the one the MCP
/// handshake always sends.
fn handle_request(
    req: JsonRpcRequest,
    table: &MappingTable,
    engine: &RewriteEngine,
) -> Option<JsonRpcResponse> {
    let id = req.id?;
    let id = Some(id);

    let response = match req.method.as_str() {
        "initialize" => {
            let result = serde_json::json!({
                "protocolVersion": "2024-11-05",
                "capabilities": {
                    "tools": {}
                },
                "serverInfo": {
                    "name": "bravais-cli",
                    "version": "0.1.0"
                }
            });
            JsonRpcResponse {
                jsonrpc: "2.0".to_string(),
                result: Some(result),
                error: None,
                id,
            }
        }
        "tools/list" => JsonRpcResponse {
            jsonrpc: "2.0".to_string(),
            result: Some(serde_json::json!({ "tools": tool_definitions() })),
            error: None,
            id,
        },
        "tools/get" => {
            // Retrieve the full definition for a single tool. Not an MCP method:
            // retained as a convenience for direct/manual callers. Clients get
            // every schema from `tools/list` above.
            let params = req.params.unwrap_or(serde_json::Value::Null);
            let tool_name = params.get("name").and_then(|v| v.as_str()).unwrap_or("");

            let result = tool_definitions()
                .into_iter()
                .find(|tool| tool.get("name").and_then(|v| v.as_str()) == Some(tool_name))
                .unwrap_or(serde_json::Value::Null);

            if result.is_null() {
                JsonRpcResponse {
                    jsonrpc: "2.0".to_string(),
                    result: None,
                    error: Some(JsonRpcError {
                        code: -32602,
                        message: format!("Tool not found: {}", tool_name),
                        data: None,
                    }),
                    id,
                }
            } else {
                JsonRpcResponse {
                    jsonrpc: "2.0".to_string(),
                    result: Some(result),
                    error: None,
                    id,
                }
            }
        }
        "tools/call" => {
            let params = req.params.unwrap_or(serde_json::Value::Null);
            let tool_name = params.get("name").and_then(|v| v.as_str()).unwrap_or("");
            let arguments = params.get("arguments").cloned().unwrap_or(serde_json::Value::Null);

            match tool_name {
                TOOL_ENV => {
                    let shell_override = arguments.get("shell").and_then(|v| v.as_str());
                    let file_hint = arguments.get("file_hint").and_then(|v| v.as_str());
                    let shell = detect_shell(shell_override, file_hint);

                    let content = format!(
                        "OS: Steelbore OS Bravais\nShell: {}\nDocumentation Anchor: https://Bravais.SpacecraftSoftware.org/\nDetailed shell syntax and tool help can be obtained from Loran (https://Loran.SpacecraftSoftware.org/).",
                        shell
                    );

                    let result = serde_json::json!({
                        "content": [
                            {
                                "type": "text",
                                "text": content
                            }
                        ]
                    });
                    JsonRpcResponse {
                        jsonrpc: "2.0".to_string(),
                        result: Some(result),
                        error: None,
                        id,
                    }
                }
                TOOL_REFERENCE => {
                    let search_name = arguments.get("tool_name").and_then(|v| v.as_str()).unwrap_or("");
                    let entry = table.lookup_legacy(search_name)
                        .or_else(|| table.lookup_preferred(search_name));

                    let result = if let Some(e) = entry {
                        let text = format!(
                            "Tool: {}\nLegacy Equivalent: {}\nCategory: {}\nNotes: {}\nGotchas: {}\nFor more syntax details, query Loran (https://Loran.SpacecraftSoftware.org/).",
                            e.preferred, e.legacy, e.category, e.notes, e.gotchas
                        );
                        serde_json::json!({
                            "content": [
                                {
                                    "type": "text",
                                    "text": text
                                }
                            ]
                        })
                    } else {
                        serde_json::json!({
                            "content": [
                                {
                                    "type": "text",
                                    "text": format!("No modern replacement mapping found for tool '{}'. Please check Loran (https://Loran.SpacecraftSoftware.org/) for other preferences.", search_name)
                                }
                            ]
                        })
                    };

                    JsonRpcResponse {
                        jsonrpc: "2.0".to_string(),
                        result: Some(result),
                        error: None,
                        id,
                    }
                }
                TOOL_REWRITE => {
                    let command = arguments.get("command").and_then(|v| v.as_str()).unwrap_or("");
                    let shell_override = arguments.get("shell").and_then(|v| v.as_str());
                    let file_hint = arguments.get("file_hint").and_then(|v| v.as_str());
                    let shell = detect_shell(shell_override, file_hint);

                    let res = engine.rewrite(command, shell);
                    let text = serde_json::to_string_pretty(&res).unwrap_or_default();

                    let result = serde_json::json!({
                        "content": [
                            {
                                "type": "text",
                                "text": text
                            }
                        ]
                    });

                    JsonRpcResponse {
                        jsonrpc: "2.0".to_string(),
                        result: Some(result),
                        error: None,
                        id,
                    }
                }
                _ => JsonRpcResponse {
                    jsonrpc: "2.0".to_string(),
                    result: None,
                    error: Some(JsonRpcError {
                        code: -32601,
                        message: format!("Method not found: {}", tool_name),
                        data: None,
                    }),
                    id,
                },
            }
        }
        _ => JsonRpcResponse {
            jsonrpc: "2.0".to_string(),
            result: None,
            error: Some(JsonRpcError {
                code: -32601,
                message: format!("Method not found: {}", req.method),
                data: None,
            }),
            id,
        },
    };

    Some(response)
}
