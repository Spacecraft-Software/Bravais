// SPDX-License-Identifier: GPL-3.0-or-later
// Rust guideline compliant 2026-05-18

mod term;

use clap::{Parser, Subcommand};
use libbravais_mcp::{detect_shell, MappingTable, RewriteEngine, OS_FULL_NAME, OS_URL};
use owo_colors::OwoColorize;
use serde::Serialize;
use std::io::IsTerminal as _;

#[derive(Parser, Debug)]
#[command(
    name = "bravais-cli",
    author = "Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>",
    version = "0.1.0",
    about = "Bravais-MCP: Command-replacement and shell-aware helper",
    after_help = "Maintained by Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>\nhttps://Bravais-MCP.SpacecraftSoftware.org/"
)]
struct Cli {
    #[arg(long, global = true, help = "Output machine-readable JSON")]
    json: bool,

    #[arg(
        long,
        global = true,
        help = "Output format choice (json, text)",
        default_value = "text"
    )]
    format: String,

    #[arg(long, global = true, help = "Explicit target shell override")]
    shell: Option<String>,

    #[arg(long, global = true, help = "Filename hint for shell detection")]
    file_hint: Option<String>,

    #[arg(long, global = true, help = "Disable ANSI colour in human output")]
    no_color: bool,

    #[arg(
        long,
        global = true,
        value_name = "LIST",
        allow_hyphen_values = true,
        help = "Force terminal protocols on (+name) or off (-name), comma-separated; beats SPACECRAFT_TERM_PROTOCOLS. bravais-cli uses only `clipboard` (--copy)"
    )]
    term_protocols: Option<String>,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug, Clone)]
enum Commands {
    #[command(about = "Report detected OS and shell environment")]
    Env,

    #[command(about = "Suggest modern replacement for a legacy tool")]
    Suggest {
        #[arg(help = "The legacy tool name to replace")]
        tool: String,

        #[arg(long, help = "Copy the preferred tool name to the clipboard (OSC 52)")]
        copy: bool,
    },

    #[command(about = "List all configured command mappings")]
    List {
        #[arg(long, help = "Filter mappings by category")]
        category: Option<String>,
    },

    #[command(about = "Rewrite a command line with preferred replacements and bashism checks")]
    Rewrite {
        #[arg(help = "The command line string to rewrite")]
        command_line: String,

        #[arg(
            long,
            help = "Copy the rewritten command line to the clipboard (OSC 52)"
        )]
        copy: bool,
    },

    #[command(about = "Get full Purpose, Key flags, Examples, and Gotchas manual for a tool")]
    Reference {
        #[arg(help = "The legacy or preferred tool name")]
        tool: String,
    },

    #[command(about = "Start the stdio Model Context Protocol (MCP) server")]
    Mcp {
        #[arg(long, default_value = "stdio", help = "MCP transport protocol")]
        transport: String,
    },

    #[command(about = "Print the JSON Schema for all sub-commands")]
    Schema,
}

#[derive(Serialize)]
struct JsonEnvelope<T> {
    metadata: Metadata,
    data: T,
}

#[derive(Serialize)]
struct Metadata {
    tool: &'static str,
    version: &'static str,
    timestamp: String,
}

/// `println!` for human output: colour only when the gate allows it
/// (`term::color_stdout`); otherwise every escape sequence is removed, so a
/// pipe, an agent or `NO_COLOR` gets plain text (tui-protocols §6 audit item 1).
macro_rules! say {
    ($color:expr, $($arg:tt)*) => {{
        let line = format!($($arg)*);
        if $color {
            println!("{line}");
        } else {
            println!("{}", term::strip_escapes(&line));
        }
    }};
}

fn main() {
    let args = Cli::parse();
    // Presence-based (CLI Standard §5): AI_AGENT / AGENT set to anything, or
    // CI truthy. `is_ok()` alone also matched an empty AI_AGENT.
    let is_json = args.json || args.format == "json" || term::agent_env();
    let color = !is_json && term::color_for(std::io::stdout().is_terminal(), args.no_color);

    // Agentic CLI §7: a control character in an argument is either a mistake
    // or an injection attempt; echoing it back would put it on the terminal.
    for arg in [
        match &args.command {
            Commands::Suggest { tool, .. } | Commands::Reference { tool } => Some(tool.as_str()),
            Commands::Rewrite { command_line, .. } => Some(command_line.as_str()),
            _ => None,
        },
        args.shell.as_deref(),
        args.file_hint.as_deref(),
    ]
    .into_iter()
    .flatten()
    {
        if let Some(c) = term::forbidden_control(arg) {
            fail(
                is_json,
                "INVALID_ARGUMENT",
                &format!("argument contains control character U+{:04X}", u32::from(c)),
                "bravais-cli schema  # arguments are plain text; remove escape and control characters",
                2,
            );
        }
    }

    // Resolved only where used: `mcp` must start whatever the variable says.
    let caps = || {
        match term::Caps::resolve(args.term_protocols.as_deref()) {
        Ok(c) => c,
        Err(e) => fail(
            is_json,
            "INVALID_ARGUMENT",
            &e,
            "bravais-cli env --json  # data.terminal_protocols lists the names; e.g. --term-protocols=-all",
            2,
        ),
    }
    };

    let table = MappingTable::load_embedded();
    let engine = RewriteEngine::new(table.clone());

    let shell = detect_shell(args.shell.as_deref(), args.file_hint.as_deref());

    match args.command {
        Commands::Env => {
            let caps = caps();
            let res = serde_json::json!({
                "os": OS_FULL_NAME,
                "detected_shell": shell.to_string(),
                "documentation_anchor": OS_URL,
                "reference_manual": "https://Loran.SpacecraftSoftware.org/",
                "terminal_protocols": caps.protocols,
            });

            if is_json {
                print_json(res);
            } else {
                say!(
                    color,
                    "{}",
                    "Operating System:"
                        .bold()
                        .color(owo_colors::Rgb(75, 126, 176))
                );
                say!(color, "  {OS_FULL_NAME}");
                say!(
                    color,
                    "{}",
                    "Detected Shell:"
                        .bold()
                        .color(owo_colors::Rgb(75, 126, 176))
                );
                say!(color, "  {}", shell);
                say!(
                    color,
                    "{}",
                    "Documentation Anchor:"
                        .bold()
                        .color(owo_colors::Rgb(75, 126, 176))
                );
                say!(color, "  {OS_URL}");
                say!(
                    color,
                    "{}",
                    "Detailed Syntax & Translation:"
                        .bold()
                        .color(owo_colors::Rgb(75, 126, 176))
                );
                say!(
                    color,
                    "  Query Loran at https://Loran.SpacecraftSoftware.org/"
                );
                say!(
                    color,
                    "{}",
                    "Terminal Protocols:"
                        .bold()
                        .color(owo_colors::Rgb(75, 126, 176))
                );
                for e in &caps.protocols {
                    say!(
                        color,
                        "  {:<15} {:<4} {}",
                        e.protocol,
                        if e.enabled { "on" } else { "off" },
                        e.reason
                    );
                }
            }
        }
        Commands::Suggest { tool, copy } => {
            if let Some(entry) = table.lookup_legacy(&tool) {
                if copy {
                    copy_and_confirm(&caps(), &entry.preferred, is_json);
                }
                if is_json {
                    print_json(entry);
                } else {
                    say!(
                        color,
                        "{} is replaced by {} ({})",
                        tool.red().bold(),
                        entry.preferred.green().bold(),
                        entry.category.blue()
                    );
                    say!(color, "Notes: {}", entry.notes);
                    say!(color, "Gotchas: {}", entry.gotchas.yellow());
                    say!(
                        color,
                        "For more details, check Loran (https://Loran.SpacecraftSoftware.org/)."
                    );
                }
            } else {
                // Exit 3 in both modes; JSON mode used to exit 0 here.
                fail(
                    is_json,
                    "NOT_FOUND",
                    &format!("No mapping found for '{tool}'"),
                    "bravais-cli list --json",
                    3,
                );
            }
        }
        Commands::List { category } => {
            let entries: Vec<_> = table
                .all_entries()
                .into_iter()
                .filter(|e| category.as_ref().is_none_or(|c| &e.category == c))
                .collect();

            if is_json {
                print_json(entries);
            } else {
                say!(
                    color,
                    "{:<12} {:<12} {:<15} {}",
                    "Legacy".bold(),
                    "Preferred".bold(),
                    "Category".bold(),
                    "Notes".bold()
                );
                say!(color, "{}", "-".repeat(60));
                for entry in entries {
                    say!(
                        color,
                        "{:<12} {:<12} {:<15} {}",
                        entry.legacy.red(),
                        entry.preferred.green(),
                        entry.category.blue(),
                        entry.notes
                    );
                }
            }
        }
        Commands::Rewrite { command_line, copy } => {
            let res = engine.rewrite(&command_line, shell);
            if copy {
                copy_and_confirm(&caps(), &res.rewritten, is_json);
            }

            if is_json {
                print_json(res);
            } else {
                say!(color, "{}:", "Original".bold());
                say!(color, "  {}", res.original);
                say!(color, "{}:", "Rewritten".bold().green());
                say!(color, "  {}", res.rewritten.green());
                if !res.warnings.is_empty() {
                    say!(color, "\n{}:", "Warnings & Gotchas".bold().yellow());
                    for warning in &res.warnings {
                        say!(color, "  - {}", warning.yellow());
                    }
                }
            }
        }
        Commands::Reference { tool } => {
            let entry = table
                .lookup_legacy(&tool)
                .or_else(|| table.lookup_preferred(&tool));

            if let Some(e) = entry {
                if is_json {
                    print_json(e);
                } else {
                    say!(
                        color,
                        "{}",
                        format!("Manual: {}", e.preferred).bold().green()
                    );
                    say!(color, "Category: {}", e.category);
                    say!(color, "Notes: {}", e.notes);
                    say!(color, "Gotchas: {}", e.gotchas.yellow());
                    say!(color, "For more syntax details, check Loran (https://Loran.SpacecraftSoftware.org/).");
                }
            } else {
                // Exit 3 in both modes; JSON mode used to exit 0 here.
                fail(
                    is_json,
                    "NOT_FOUND",
                    &format!("No reference manual found for '{tool}'"),
                    "bravais-cli list --json",
                    3,
                );
            }
        }
        Commands::Mcp { transport } => {
            if transport == "stdio" {
                if let Err(e) = bravais_mcp_server::run_stdio() {
                    eprintln!("MCP Server failed: {}", e);
                    std::process::exit(1);
                }
            } else {
                fail(
                    is_json,
                    "INVALID_ARGUMENT",
                    &format!("unsupported transport '{transport}'; only 'stdio' exists"),
                    "bravais-cli mcp --transport stdio",
                    2,
                );
            }
        }
        Commands::Schema => {
            // Output JSON Schema for commands
            let schema = serde_json::json!({
                "$schema": "https://json-schema.org/draft/2020-12/schema",
                "title": "bravais-cli",
                "type": "object",
                "properties": {
                    "env": {
                        "type": "object",
                        "description": "Report detected OS and shell"
                    },
                    "suggest": {
                        "type": "object",
                        "properties": {
                            "tool": { "type": "string" },
                            "copy": { "type": "boolean", "description": "Copy the preferred tool name to the clipboard with OSC 52 (human terminal only)" }
                        },
                        "required": ["tool"]
                    },
                    "rewrite": {
                        "type": "object",
                        "properties": {
                            "command_line": { "type": "string" },
                            "copy": { "type": "boolean", "description": "Copy the rewritten command line to the clipboard with OSC 52 (human terminal only)" }
                        },
                        "required": ["command_line"]
                    }
                },
                "global_flags": {
                    "--no-color": "disable ANSI colour in human output (also NO_COLOR)",
                    "--term-protocols": "comma-separated +name / -name terminal protocol overrides (keyboard, graphics, animation, clipboard, clipboard-rich, progress, pointer, all); beats SPACECRAFT_TERM_PROTOCOLS; never enables output to an agent, CI or a pipe; bravais-cli uses only clipboard"
                },
                "exit_codes": {
                    "0": "success",
                    "1": "general failure",
                    "2": "usage error (INVALID_ARGUMENT: unknown terminal protocol; an escape or control character other than tab, LF or CR in the tool, command_line, --shell or --file-hint argument; or an unsupported mcp --transport)",
                    "3": "not found (NOT_FOUND: no mapping for the tool)"
                }
            });
            println!("{}", serde_json::to_string_pretty(&schema).unwrap());
        }
    }
}

/// ISO 8601 UTC to the second with the `Z` suffix (CLI Standard
/// non-negotiable #1); `Timestamp`'s own `Display` adds nanoseconds.
fn now_utc() -> String {
    jiff::Timestamp::now()
        .strftime("%Y-%m-%dT%H:%M:%SZ")
        .to_string()
}

/// Exit with a structured error (JSON on stderr in machine mode, a tagged
/// line otherwise). `hint` is a command to run next (agentic-cli §3).
fn fail(is_json: bool, code: &str, message: &str, hint: &str, exit_code: i32) -> ! {
    if is_json {
        let err = serde_json::json!({
            "error": {
                "code": code,
                "exit_code": exit_code,
                "message": message,
                "hint": hint,
                "timestamp": now_utc(),
                "command": "bravais-cli",
            }
        });
        eprintln!("{err}");
    } else {
        eprintln!("[ERROR] {}", term::strip_escapes(message));
        eprintln!("        try: {hint}");
    }
    std::process::exit(exit_code);
}

/// Copy with OSC 52 and say what happened on stderr. Terminals never
/// acknowledge OSC 52, so success is reported as "sent" with a way to check;
/// a copy that could not be sent is a warning, not a failure -- the result is
/// still printed on stdout.
fn copy_and_confirm(caps: &term::Caps, text: &str, is_json: bool) {
    let (severity, code, message) = match term::copy(caps, text) {
        term::Copied::Sent { bytes } => (
            "ok",
            "COPIED",
            format!("sent {bytes} bytes to the clipboard (OSC 52); a terminal without OSC 52 ignores it, so paste to check"),
        ),
        term::Copied::TooLarge { bytes } => (
            "warn",
            "CLIPBOARD_TOO_LARGE",
            format!("{bytes} bytes is over the {} byte OSC 52 limit; not copied", term::CLIPBOARD_MAX),
        ),
        term::Copied::Unavailable => (
            "warn",
            "CLIPBOARD_UNAVAILABLE",
            format!("clipboard not used: {}", caps.clipboard_reason()),
        ),
    };
    if is_json {
        let d = serde_json::json!({
            "diagnostic": {
                "severity": severity,
                "code": code,
                "message": message,
                "timestamp": now_utc(),
            }
        });
        eprintln!("{d}");
    } else {
        let tag = if severity == "ok" { "[OK]" } else { "[WARN]" };
        eprintln!("{tag} {message}");
    }
}

fn print_json<T: Serialize>(data: T) {
    let now = now_utc();
    let envelope = JsonEnvelope {
        metadata: Metadata {
            tool: "bravais-cli",
            version: "0.1.0",
            timestamp: now,
        },
        data,
    };
    println!("{}", serde_json::to_string(&envelope).unwrap());
}
