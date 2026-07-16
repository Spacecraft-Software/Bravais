// SPDX-License-Identifier: GPL-3.0-or-later
// Rust guideline compliant 2026-05-18

use clap::{Parser, Subcommand};
use libbravais_mcp::{detect_shell, MappingTable, RewriteEngine};
use owo_colors::OwoColorize;
use serde::Serialize;

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

fn main() {
    let args = Cli::parse();
    let is_json = args.json || args.format == "json" || std::env::var("AI_AGENT").is_ok();

    let table = MappingTable::load_embedded();
    let engine = RewriteEngine::new(table.clone());

    let shell = detect_shell(args.shell.as_deref(), args.file_hint.as_deref());

    match args.command {
        Commands::Env => {
            let res = serde_json::json!({
                "os": "Steelbore OS Bravais",
                "detected_shell": shell.to_string(),
                "documentation_anchor": "https://Bravais.SpacecraftSoftware.org/",
                "reference_manual": "https://Loran.SpacecraftSoftware.org/"
            });

            if is_json {
                print_json(res);
            } else {
                println!("{}", "Operating System:".bold().color(owo_colors::Rgb(75, 126, 176)));
                println!("  Steelbore OS Bravais");
                println!("{}", "Detected Shell:".bold().color(owo_colors::Rgb(75, 126, 176)));
                println!("  {}", shell);
                println!("{}", "Documentation Anchor:".bold().color(owo_colors::Rgb(75, 126, 176)));
                println!("  https://Bravais.SpacecraftSoftware.org/");
                println!("{}", "Detailed Syntax & Translation:".bold().color(owo_colors::Rgb(75, 126, 176)));
                println!("  Query Loran at https://Loran.SpacecraftSoftware.org/");
            }
        }
        Commands::Suggest { tool } => {
            if let Some(entry) = table.lookup_legacy(&tool) {
                if is_json {
                    print_json(entry);
                } else {
                    println!(
                        "{} is replaced by {} ({})",
                        tool.red().bold(),
                        entry.preferred.green().bold(),
                        entry.category.blue()
                    );
                    println!("Notes: {}", entry.notes);
                    println!("Gotchas: {}", entry.gotchas.yellow());
                    println!("For more details, check Loran (https://Loran.SpacecraftSoftware.org/).");
                }
            } else {
                let err_msg = format!("No mapping found for '{}'", tool);
                if is_json {
                    print_json_error("NOT_FOUND", &err_msg, 3);
                } else {
                    eprintln!("{}: {}", "error".red().bold(), err_msg);
                    std::process::exit(3);
                }
            }
        }
        Commands::List { category } => {
            let entries: Vec<_> = table.all_entries().into_iter()
                .filter(|e| category.as_ref().map_or(true, |c| &e.category == c))
                .collect();

            if is_json {
                print_json(entries);
            } else {
                println!(
                    "{:<12} {:<12} {:<15} {}",
                    "Legacy".bold(),
                    "Preferred".bold(),
                    "Category".bold(),
                    "Notes".bold()
                );
                println!("{}", "-".repeat(60));
                for entry in entries {
                    println!(
                        "{:<12} {:<12} {:<15} {}",
                        entry.legacy.red(),
                        entry.preferred.green(),
                        entry.category.blue(),
                        entry.notes
                    );
                }
            }
        }
        Commands::Rewrite { command_line } => {
            let res = engine.rewrite(&command_line, shell);

            if is_json {
                print_json(res);
            } else {
                println!("{}:", "Original".bold());
                println!("  {}", res.original);
                println!("{}:", "Rewritten".bold().green());
                println!("  {}", res.rewritten.green());
                if !res.warnings.is_empty() {
                    println!("\n{}:", "Warnings & Gotchas".bold().yellow());
                    for warning in &res.warnings {
                        println!("  - {}", warning.yellow());
                    }
                }
            }
        }
        Commands::Reference { tool } => {
            let entry = table.lookup_legacy(&tool)
                .or_else(|| table.lookup_preferred(&tool));

            if let Some(e) = entry {
                if is_json {
                    print_json(e);
                } else {
                    println!("{}", format!("Manual: {}", e.preferred).bold().green());
                    println!("Category: {}", e.category);
                    println!("Notes: {}", e.notes);
                    println!("Gotchas: {}", e.gotchas.yellow());
                    println!("For more syntax details, check Loran (https://Loran.SpacecraftSoftware.org/).");
                }
            } else {
                let err_msg = format!("No reference manual found for '{}'", tool);
                if is_json {
                    print_json_error("NOT_FOUND", &err_msg, 3);
                } else {
                    eprintln!("{}: {}", "error".red().bold(), err_msg);
                    std::process::exit(3);
                }
            }
        }
        Commands::Mcp { transport } => {
            if transport == "stdio" {
                if let Err(e) = bravais_mcp_server::run_stdio() {
                    eprintln!("MCP Server failed: {}", e);
                    std::process::exit(1);
                }
            } else {
                eprintln!("Unsupported transport: {}", transport);
                std::process::exit(2);
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
                            "tool": { "type": "string" }
                        },
                        "required": ["tool"]
                    },
                    "rewrite": {
                        "type": "object",
                        "properties": {
                            "command_line": { "type": "string" }
                        },
                        "required": ["command_line"]
                    }
                }
            });
            println!("{}", serde_json::to_string_pretty(&schema).unwrap());
        }
    }
}

fn print_json<T: Serialize>(data: T) {
    let now = jiff::Timestamp::now().to_string();
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

fn print_json_error(code: &str, message: &str, exit_code: i32) {
    let now = jiff::Timestamp::now().to_string();
    let err = serde_json::json!({
        "error": {
            "code": code,
            "exit_code": exit_code,
            "message": message,
            "timestamp": now
        }
    });
    eprintln!("{}", serde_json::to_string(&err).unwrap());
}
