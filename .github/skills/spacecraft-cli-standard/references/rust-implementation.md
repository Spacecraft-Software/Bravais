# Rust Implementation Patterns

**Scope.** Concrete Rust scaffolds for every piece of the Spacecraft Software CLI
Standard. Copy-pasteable code for the envelope, error type, output mode
detection, clap wiring, path validation, TUI bootstrap, MCP server, and
the test harness. Paired with `rust-guidelines` (Microsoft Pragmatic Rust
Guidelines) — consult both.

---

## §1 — Recommended Crate Stack

Pin these as your starting point. Every crate below is MSL-priority
(memory-safe, preferably Rust, Spacecraft Software-compatible).

### Core

| Purpose | Crate | Notes |
|---------|-------|-------|
| Argument parsing | `clap` (derive) | With `schemars` integration for schema generation |
| JSON Schema derivation | `schemars` | Derives from the same struct that drives clap |
| JSON (de)serialization | `serde` + `serde_json` | Canonical |
| YAML output | `serde_yaml` | For `--format yaml` |
| CSV output | `csv` | RFC 4180 |
| TOML config | `toml` | If the tool uses a config file |
| Timestamps | `jiff` | Modern Rust date/time library with explicit tz handling; ISO 8601-native. (Alternative: `chrono` with `time` features if `jiff` is unsuitable.) |
| Colored terminal output | `owo-colors` or `anstyle` | Both honor NO_COLOR/FORCE_COLOR natively |

### TUI

| Purpose | Crate |
|---------|-------|
| TUI widgets | `ratatui` |
| Terminal backend | `crossterm` |

### MCP

| Purpose | Crate |
|---------|-------|
| MCP server SDK | Current Spacecraft Software-recommended MCP Rust SDK (consult `rust-guidelines` references for the specific crate name at time of writing). Alternative: hand-roll over `jsonrpc-core` for stdio transport. |

### Testing

| Purpose | Crate |
|---------|-------|
| CLI invocation | `assert_cmd` |
| Output assertions | `predicates` |
| PTY for TTY-detection tests | `portable-pty` |
| JSON Schema validation | `jsonschema` |
| Snapshot testing | `insta` |
| Isolated workdirs | `tempfile` |

---

## §2 — The `Response<T>` Envelope

Single generic type. Every sub-command returns this.

```rust
// src/output/envelope.rs
use serde::Serialize;

#[derive(Debug, Serialize)]
pub struct Response<T: Serialize> {
    pub metadata: Metadata,
    pub data: T,
}

#[derive(Debug, Serialize)]
pub struct Metadata {
    pub tool: &'static str,
    pub version: &'static str,
    pub command: String,
    pub timestamp: String, // ISO 8601 UTC; see §4 for construction
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pagination: Option<Pagination>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tool_agent: Option<String>,
    #[serde(skip_serializing_if = "std::ops::Not::not")]
    pub dry_run: bool,
}

#[derive(Debug, Serialize)]
pub struct Pagination {
    pub page: u32,
    pub per_page: u32,
    pub total: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub next_token: Option<String>,
}

impl<T: Serialize> Response<T> {
    pub fn new(command: String, data: T) -> Self {
        Self {
            metadata: Metadata {
                tool: env!("CARGO_PKG_NAME"),
                version: env!("CARGO_PKG_VERSION"),
                command,
                timestamp: crate::time::now_iso8601(),
                pagination: None,
                tool_agent: detect_tool_agent(),
                dry_run: false,
            },
            data,
        }
    }

    pub fn with_dry_run(mut self) -> Self {
        self.metadata.dry_run = true;
        self
    }

    pub fn with_pagination(mut self, p: Pagination) -> Self {
        self.metadata.pagination = Some(p);
        self
    }
}

fn detect_tool_agent() -> Option<String> {
    for var in ["CLAUDECODE", "CURSOR_AGENT", "GEMINI_CLI"] {
        if std::env::var(var).is_ok() {
            return Some(var.to_ascii_lowercase().replace('_', "-"));
        }
    }
    None
}
```

---

## §3 — The `AppError` Type

Single error struct. Mirrors the structured error schema exactly.

```rust
// src/error.rs
use serde::Serialize;

#[derive(Debug, Serialize)]
pub struct AppError {
    pub code: ErrorCode,
    pub exit_code: i32,
    pub message: String,
    pub hint: String,
    pub timestamp: String,
    pub command: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub docs_url: Option<String>,
    #[serde(flatten)]
    pub extensions: serde_json::Map<String, serde_json::Value>,
}

#[derive(Debug, Serialize, Copy, Clone)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ErrorCode {
    NotFound,
    PermissionDenied,
    InvalidArgument,
    MissingArgument,
    Conflict,
    RateLimited,
    Timeout,
    NetworkError,
    DependencyMissing,
    InternalError,
    FeatureUnavailable,
    // Tool-specific codes declared in the tool's own enum extension
}

impl AppError {
    pub fn emit_to_stderr(&self) {
        #[derive(Serialize)]
        struct Wrapper<'a> { error: &'a AppError }
        // Single-line JSON — PowerShell fragments multi-line stderr.
        let line = serde_json::to_string(&Wrapper { error: self })
            .expect("AppError serializes");
        eprintln!("{line}");
    }

    pub fn emit_human(&self) {
        use owo_colors::OwoColorize;
        eprintln!("{}: {}", "error".red().bold(), self.message.red());
        eprintln!("       {}: {}", "hint".color(owo_colors::Rgb(217, 142, 50)), self.hint);
    }
}

/// Entry point for every sub-command. Emits error in the correct form.
pub fn report(err: AppError, mode: crate::output::OutputMode) -> i32 {
    if mode.is_machine() {
        err.emit_to_stderr();
    } else {
        err.emit_human();
    }
    err.exit_code
}
```

---

## §4 — ISO 8601 UTC Timestamps

Use `jiff` (preferred) or `chrono`. Never `SystemTime` without conversion.

```rust
// src/time.rs

/// Current time as ISO 8601 in UTC with Z suffix.
pub fn now_iso8601() -> String {
    // Using jiff:
    jiff::Timestamp::now().to_string()
    // jiff::Timestamp::to_string emits RFC 3339 / ISO 8601 with Z suffix.

    // Chrono equivalent:
    // chrono::Utc::now().format("%Y-%m-%dT%H:%M:%S%.3fZ").to_string()
}

/// ISO 8601 duration string (e.g., "PT1H30M") from seconds.
pub fn duration_iso8601(seconds: u64) -> String {
    jiff::SignedDuration::from_secs(seconds as i64).to_string()
}
```

**Never** construct timestamps by hand or with `%Y-%m-%d %H:%M:%S` (space
separator is not ISO 8601). Always RFC 3339 / ISO 8601 with `T` and `Z`.

---

## §5 — Output Mode Detection

The cascade from SKILL.md §5, in one function.

```rust
// src/output/mode.rs
use std::io::IsTerminal;

#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum OutputMode {
    HumanWithColor,
    HumanNoColor,
    Json,
    Jsonl,
    Yaml,
    Csv,
    Explore, // TUI
}

impl OutputMode {
    pub fn is_machine(self) -> bool {
        matches!(self, Self::Json | Self::Jsonl | Self::Yaml | Self::Csv)
    }
}

pub struct Cli {
    pub format: Option<Format>, // --format / --json flag
    pub color: ColorChoice,     // --color / --no-color
}

#[derive(Debug, Copy, Clone)]
pub enum Format { Json, Jsonl, Yaml, Csv, Explore }

#[derive(Debug, Copy, Clone)]
pub enum ColorChoice { Auto, Always, Never }

pub fn resolve_mode(cli: &Cli) -> OutputMode {
    // 1. Explicit flag.
    if let Some(fmt) = cli.format {
        return match fmt {
            Format::Json => OutputMode::Json,
            Format::Jsonl => OutputMode::Jsonl,
            Format::Yaml => OutputMode::Yaml,
            Format::Csv => OutputMode::Csv,
            Format::Explore => resolve_explore(cli),
        };
    }

    // 2. Agent env vars.
    if is_agent_env() { return OutputMode::Json; }
    if std::env::var("CI").is_ok_and(|v| v == "true" || v == "1") {
        return OutputMode::Json;
    }

    // 3/4. TTY detection.
    if std::io::stdout().is_terminal() {
        if should_use_color(cli) {
            OutputMode::HumanWithColor
        } else {
            OutputMode::HumanNoColor
        }
    } else {
        OutputMode::Json
    }
}

fn resolve_explore(cli: &Cli) -> OutputMode {
    // TUI fallbacks: non-TTY, agent env, dumb term.
    if !std::io::stdout().is_terminal() || is_agent_env() || is_dumb_term() {
        warn_tui_fallback();
        return OutputMode::Json;
    }
    let _ = cli; // TUI honors NO_COLOR internally
    OutputMode::Explore
}

fn is_agent_env() -> bool {
    for v in ["AI_AGENT", "AGENT"] {
        if let Ok(val) = std::env::var(v) {
            if !val.is_empty() && val != "0" && val != "false" {
                return true;
            }
        }
    }
    false
}

fn is_dumb_term() -> bool {
    std::env::var("TERM").as_deref() == Ok("dumb")
}

fn should_use_color(cli: &Cli) -> bool {
    // Precedence: --no-color / --color flag, then env, then TTY.
    match cli.color {
        ColorChoice::Never => return false,
        ColorChoice::Always => return true,
        ColorChoice::Auto => {}
    }
    if std::env::var_os("FORCE_COLOR").is_some_and(|v| !v.is_empty()) { return true; }
    if std::env::var_os("NO_COLOR").is_some_and(|v| !v.is_empty()) { return false; }
    if std::env::var("CLICOLOR").as_deref() == Ok("0") { return false; }
    if is_dumb_term() { return false; }
    std::io::stdout().is_terminal()
}

fn warn_tui_fallback() {
    let warn = serde_json::json!({
        "warning": {
            "code": "TUI_FALLBACK",
            "message": "Interactive explore mode unavailable; falling back to --format json",
            "reason": "stdout is not a TTY, agent env set, or TERM=dumb",
            "timestamp": crate::time::now_iso8601(),
        }
    });
    eprintln!("{warn}");
}
```

---

## §6 — Path and String Validation

```rust
// src/validation.rs
use std::path::{Path, PathBuf};

/// Canonicalize + check against allowed paths. Returns PermissionDenied on escape.
pub fn validate_path(input: &Path, allowed_roots: &[PathBuf]) -> Result<PathBuf, crate::AppError> {
    // Use `absolute` for paths that may not yet exist, `canonicalize` when it must.
    let abs = std::path::absolute(input).map_err(|e| crate::AppError {
        code: crate::ErrorCode::InvalidArgument,
        exit_code: 2,
        message: format!("invalid path '{}': {e}", input.display()),
        hint: "supply an absolute path or one relative to the working directory".into(),
        timestamp: crate::time::now_iso8601(),
        command: std::env::args().collect::<Vec<_>>().join(" "),
        docs_url: None,
        extensions: serde_json::Map::new(),
    })?;
    if allowed_roots.iter().any(|root| abs.starts_with(root)) {
        Ok(abs)
    } else {
        Err(crate::AppError {
            code: crate::ErrorCode::PermissionDenied,
            exit_code: 4,
            message: format!("path '{}' is outside the allowed-paths set", abs.display()),
            hint: format!(
                "allowed roots: {}",
                allowed_roots.iter().map(|p| p.display().to_string()).collect::<Vec<_>>().join(", ")
            ),
            timestamp: crate::time::now_iso8601(),
            command: std::env::args().collect::<Vec<_>>().join(" "),
            docs_url: None,
            extensions: serde_json::Map::new(),
        })
    }
}

/// Reject control characters (except tab, LF, CR in free-text fields).
pub fn validate_string_field(s: &str, allow_tab_lf_cr: bool) -> Result<(), crate::AppError> {
    for (i, b) in s.bytes().enumerate() {
        let is_control = matches!(b, 0x00..=0x08 | 0x0B..=0x0C | 0x0E..=0x1F);
        let is_whitespace_ok = allow_tab_lf_cr && matches!(b, 0x09 | 0x0A | 0x0D);
        if is_control && !is_whitespace_ok {
            return Err(crate::AppError {
                code: crate::ErrorCode::InvalidArgument,
                exit_code: 2,
                message: format!("control character 0x{b:02X} at byte offset {i} in argument"),
                hint: "remove control characters from the argument value".into(),
                timestamp: crate::time::now_iso8601(),
                command: std::env::args().collect::<Vec<_>>().join(" "),
                docs_url: None,
                extensions: serde_json::Map::new(),
            });
        }
    }
    Ok(())
}
```

---

## §7 — TUI Bootstrap (ratatui + crossterm)

Gated behind the `tui` feature flag.

```rust
// src/tui/mod.rs
#![cfg(feature = "tui")]

use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{Terminal, backend::CrosstermBackend};
use std::io::{self, IsTerminal, Stdout};

/// Install panic hook that restores terminal state before the default handler runs.
pub fn install_panic_hook() {
    let original = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |info| {
        let _ = disable_raw_mode();
        let _ = execute!(io::stderr(), LeaveAlternateScreen);
        original(info);
    }));
}

pub fn run_explore<T: serde::Serialize>(data: &[T]) -> io::Result<Option<String>> {
    // MUST-check: never enter raw mode on non-TTY.
    if !io::stdout().is_terminal() {
        return Ok(None);
    }
    install_panic_hook();

    enable_raw_mode()?;
    let mut stderr = io::stderr();
    execute!(stderr, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stderr);
    let mut terminal = Terminal::new(backend)?;

    let result = event_loop(&mut terminal, data);

    // Clean shutdown — always restore.
    disable_raw_mode()?;
    execute!(io::stderr(), LeaveAlternateScreen)?;

    result
}

fn event_loop<T: serde::Serialize>(
    _terminal: &mut Terminal<CrosstermBackend<Stdout>>,
    _data: &[T],
) -> io::Result<Option<String>> {
    loop {
        // terminal.draw(|f| { ... render palette-themed UI ... })?;
        if let Event::Key(k) = event::read()? {
            if k.kind != KeyEventKind::Press { continue; }
            // Dual CUA + Vim keybindings — both live simultaneously.
            match k.code {
                KeyCode::Esc | KeyCode::Char('q') => return Ok(None),
                KeyCode::Up | KeyCode::Char('k') => { /* move up */ }
                KeyCode::Down | KeyCode::Char('j') => { /* move down */ }
                KeyCode::Left | KeyCode::Char('h') => { /* move left */ }
                KeyCode::Right | KeyCode::Char('l') => { /* move right */ }
                KeyCode::Char('/') => { /* search */ }
                KeyCode::Char('s') => { /* sort */ }
                KeyCode::Char('e') => { /* export */ }
                _ => {}
            }
        }
    }
}
```

---

## §8 — Windows Console Setup

Set UTF-8 code page at startup on Windows. Do not rely on the user's
locale.

```rust
// src/platform.rs

#[cfg(windows)]
pub fn init_console() {
    use windows_sys::Win32::System::Console::SetConsoleOutputCP;
    // 65001 = UTF-8
    unsafe { SetConsoleOutputCP(65001) };
    // Enable virtual terminal processing for ANSI colors — most modern terminals
    // have this on by default; explicit enablement covers legacy ConHost.
    use windows_sys::Win32::System::Console::{
        GetStdHandle, GetConsoleMode, SetConsoleMode,
        STD_OUTPUT_HANDLE, ENABLE_VIRTUAL_TERMINAL_PROCESSING,
    };
    unsafe {
        let handle = GetStdHandle(STD_OUTPUT_HANDLE);
        let mut mode = 0;
        if GetConsoleMode(handle, &mut mode) != 0 {
            let _ = SetConsoleMode(handle, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
        }
    }
}

#[cfg(not(windows))]
pub fn init_console() {}
```

Call `init_console()` at the top of `main`.

---

## §9 — MCP Server Skeleton

This is a shape rather than a literal drop-in — use the current
Spacecraft Software-recommended MCP Rust SDK for the transport layer. The key is
that the handler dispatches to the **same** internal functions the CLI
uses.

```rust
// src/mcp.rs
// Derive MCP tool definitions from the same schema source as `<tool> schema`.
// Register names + descriptions only; defer full schemas to tools/get.

pub fn run_stdio() -> Result<(), crate::AppError> {
    let registry = build_tool_registry();
    // Advertise: (name, one-line description) only.
    let advertised: Vec<_> = registry.iter()
        .map(|t| (t.name.clone(), t.short_description.clone()))
        .collect();

    // Serve JSON-RPC over stdio using the chosen MCP SDK.
    // On tools/list → return `advertised`.
    // On tools/get <name> → return the full schema for that tool only.
    // On tools/call <name> <args> → dispatch to the same internal handler
    //   the CLI uses. Map AppError to JSON-RPC error per mcp-surface.md §7.

    todo!("wire the chosen MCP SDK here")
}

struct Tool {
    name: String,             // "caliper_trace_run" (underscores)
    short_description: String,
    full_schema: serde_json::Value,
    handler: Box<dyn Fn(serde_json::Value) -> Result<serde_json::Value, crate::AppError> + Send + Sync>,
}

fn build_tool_registry() -> Vec<Tool> {
    // One source of truth: the same clap + schemars setup that produces
    // `<tool> schema` output produces these entries.
    Vec::new()
}
```

---

## §10 — Test Harness Snippets

```rust
// tests/cli_blocker.rs
use assert_cmd::Command;
use predicates::prelude::*;
use jsonschema::JSONSchema;

#[test]
fn json_output_has_iso8601_utc_timestamp() {
    let out = Command::cargo_bin("caliper").unwrap()
        .args(["trace", "list", "--json"])
        .assert()
        .success()
        .get_output()
        .stdout
        .clone();
    let v: serde_json::Value = serde_json::from_slice(&out).unwrap();
    let ts = v["metadata"]["timestamp"].as_str().unwrap();
    let re = regex::Regex::new(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$").unwrap();
    assert!(re.is_match(ts), "timestamp not ISO 8601 UTC: {ts}");
}

#[test]
fn utf8_no_bom() {
    let out = Command::cargo_bin("caliper").unwrap()
        .args(["describe"])
        .assert()
        .success()
        .get_output()
        .stdout
        .clone();
    assert!(!out.starts_with(&[0xEF, 0xBB, 0xBF]), "output has UTF-8 BOM");
    // Also validates that the bytes are valid UTF-8:
    std::str::from_utf8(&out).expect("output is valid UTF-8");
}

#[test]
fn ai_agent_env_forces_json() {
    Command::cargo_bin("caliper").unwrap()
        .env("AI_AGENT", "1")
        .args(["trace", "list"])
        .assert()
        .stdout(predicate::str::contains("\"metadata\""))
        .stdout(predicate::str::contains("\"data\""));
}

#[test]
fn non_zero_exit_emits_structured_error_on_stderr() {
    let output = Command::cargo_bin("caliper").unwrap()
        .args(["trace", "get", "nonexistent", "--json"])
        .assert()
        .code(3)
        .get_output()
        .stderr
        .clone();
    let v: serde_json::Value = serde_json::from_slice(&output).unwrap();
    assert_eq!(v["error"]["code"], "NOT_FOUND");
    assert_eq!(v["error"]["exit_code"], 3);
    assert!(v["error"]["hint"].is_string());
}

#[test]
fn schema_output_validates_against_draft_2020_12_meta_schema() {
    let out = Command::cargo_bin("caliper").unwrap()
        .args(["schema"])
        .assert()
        .success()
        .get_output()
        .stdout
        .clone();
    let schema: serde_json::Value = serde_json::from_slice(&out).unwrap();
    // Validate that the schema is itself a valid JSON Schema.
    let _compiled = JSONSchema::compile(&schema).expect("output is a valid JSON Schema");
}
```

---

## §11 — Common Pitfalls (Rust-Specific)

- **`println!` in sub-command handlers.** Handlers should return a `Response<T>`; a single output module serializes. Forbid `println!` outside `src/output/` via CI grep.
- **`.unwrap()` / `.expect()` in release paths.** Panics bypass the structured error schema. Use `?` with `AppError`.
- **Heap-expensive clone of big command strings.** Cache `std::env::args().collect::<Vec<_>>().join(" ")` once per invocation; don't rebuild it per error.
- **`chrono::Local::now()`.** Never. ISO 8601 UTC only. Use `jiff::Timestamp::now()` or `chrono::Utc::now()`.
- **`std::time::SystemTime` formatted as `Debug`.** Nondeterministic and not ISO 8601. Convert explicitly.
- **`serde_json::to_string_pretty` on stderr errors.** Breaks PowerShell consumption. Use compact `to_string`.
- **Feature-gated `#[cfg(feature = "tui")]` missing on the entry points.** The build succeeds without `tui` but the `--format explore` handler is dead-linked. Add a `#[cfg(not(feature = "tui"))]` fallback that emits `FEATURE_UNAVAILABLE`.

---

*See also: every other file in this directory for the requirements these
patterns satisfy. Consult `rust-guidelines` for MSL and Microsoft
Pragmatic Rust Guidelines rules that layer on top.*
