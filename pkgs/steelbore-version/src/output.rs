// SPDX-License-Identifier: GPL-3.0-or-later
//
// Output plumbing for the Spacecraft Software CLI Standard: the `metadata` +
// `data` envelope, the structured error object and the mode-detection cascade
// that chooses between human and JSON output. Adapted from pkgs/preflight's
// module of the same name, cut to what a read-only, single-shot reporter
// needs: no severity ladder beyond errors, no dry-run marker.

use std::io::{IsTerminal as _, Write as _};

use serde::Serialize;

/// The maintainer line `--version`, `describe` and the envelope carry
/// (Standard §15.2).
pub const MAINTAINER: &str = "Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>";
/// The project URL: lib/identity.nix `urls.home`, injected by build.rs.
pub const WEBSITE: &str = env!("STEELBORE_OS_URL");

/// Wire format for a successful command (CLI Standard §6).
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
    /// ISO 8601 UTC with the mandatory `Z` suffix (Standard §14.2).
    pub timestamp: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tool_agent: Option<String>,
    pub maintainer: &'static str,
    pub website: &'static str,
}

impl<T: Serialize> Response<T> {
    pub fn new(command: String, data: T) -> Self {
        Self {
            metadata: Metadata {
                tool: env!("CARGO_PKG_NAME"),
                version: env!("CARGO_PKG_VERSION"),
                command,
                timestamp: now_utc(),
                tool_agent: detect_tool_agent(),
                maintainer: MAINTAINER,
                website: WEBSITE,
            },
            data,
        }
    }
}

/// ISO 8601 UTC, second precision, `Z`-suffixed. Sub-second digits are noise
/// on a stamp that only says when a report was made.
pub fn now_utc() -> String {
    let now = jiff::Timestamp::now();
    now.round(jiff::Unit::Second).unwrap_or(now).to_string()
}

/// Which harness is driving us, if any. Reported, never used to gate behavior.
fn detect_tool_agent() -> Option<String> {
    ["CLAUDECODE", "CURSOR_AGENT", "GEMINI_CLI"]
        .into_iter()
        .find(|var| std::env::var_os(var).is_some())
        .map(|var| var.to_ascii_lowercase().replace('_', "-"))
}

/// Canonical exit codes (CLI Standard §4). This tool defines none of its own
/// in the 6-125 range.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Exit {
    Failure,
    Usage,
    NotFound,
}

impl Exit {
    pub const fn code(self) -> u8 {
        match self {
            Self::Failure => 1,
            Self::Usage => 2,
            Self::NotFound => 3,
        }
    }
}

/// Structured error object (CLI Standard §8). `hint` carries a command the
/// caller can run as-is to get unstuck.
///
/// The Standard's `timestamp`, `command` and `docs_url` are added when the
/// error is printed ([`Out::fail`]): they describe the run, not the error,
/// and leaving them out keeps every `Result<_, AppError>` small.
#[derive(Debug, Serialize)]
pub struct AppError {
    pub code: &'static str,
    pub exit_code: u8,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub hint: Option<String>,
}

impl AppError {
    pub fn new(code: &'static str, exit: Exit, message: impl Into<String>) -> Self {
        Self {
            code,
            exit_code: exit.code(),
            message: message.into(),
            hint: None,
        }
    }

    #[must_use]
    pub fn with_hint(mut self, hint: impl Into<String>) -> Self {
        self.hint = Some(hint.into());
        self
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, clap::ValueEnum)]
pub enum Format {
    Human,
    Json,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, clap::ValueEnum)]
pub enum ColorWhen {
    Auto,
    Always,
    Never,
}

/// The error tag's color: Steelbore Modern's `error` role as the nearest
/// 256-color index, the same value pkgs/preflight uses. The `[ERROR]` text
/// always accompanies it (Standard §18.2.1).
const ERROR_ANSI: &str = "\x1b[38;5;203m";

/// Resolved output policy for one run.
#[derive(Debug, Clone, Copy)]
pub struct Out {
    pub format: Format,
    pub color: bool,
}

impl Out {
    /// The CLI Standard §5 detection cascade, first match wins: explicit
    /// format, then an agent or CI environment, then whether stdout is a
    /// terminal.
    pub fn resolve(format: Option<Format>, color: ColorWhen) -> Self {
        let agent = is_agent_env();
        let tty = std::io::stdout().is_terminal();
        let format = format.unwrap_or(if agent || !tty {
            Format::Json
        } else {
            Format::Human
        });
        let color = match color {
            ColorWhen::Never => false,
            ColorWhen::Always => true,
            ColorWhen::Auto => {
                format == Format::Human
                    && std::io::stderr().is_terminal()
                    && !agent
                    && std::env::var_os("NO_COLOR").is_none()
                    && std::env::var("TERM").as_deref() != Ok("dumb")
            }
        };
        Self { format, color }
    }

    /// Emit the payload on stdout: the envelope in JSON mode, `human` as-is
    /// otherwise. Stdout carries data only (non-negotiable #7).
    pub fn emit<T: Serialize>(self, command: &str, data: &T, human: &str) -> Result<(), AppError> {
        let mut sink = std::io::stdout().lock();
        let written = match self.format {
            Format::Json => {
                let env = Response::new(command.to_owned(), data);
                let text = serde_json::to_string(&env).map_err(|e| {
                    AppError::new(
                        "serialize",
                        Exit::Failure,
                        format!("cannot serialize output: {e}"),
                    )
                })?;
                writeln!(sink, "{text}")
            }
            Format::Human => write!(sink, "{human}"),
        };
        // A closed pipe (`steelbore-version | head -c0`) is the reader's
        // choice, not our failure; anything else is reported.
        match written {
            Err(e) if e.kind() != std::io::ErrorKind::BrokenPipe => Err(AppError::new(
                "write",
                Exit::Failure,
                format!("cannot write output: {e}"),
            )),
            _ => Ok(()),
        }
    }

    /// Emit a structured error on stderr and return its exit code. Errors are
    /// the only diagnostics this tool has, so `--quiet` never hides one.
    pub fn fail(self, err: &AppError, command: &str) -> u8 {
        let mut sink = std::io::stderr().lock();
        if self.format == Format::Json {
            let obj = serde_json::json!({ "error": {
                "code": err.code,
                "exit_code": err.exit_code,
                "message": err.message,
                "hint": err.hint,
                "timestamp": now_utc(),
                "command": command,
                "docs_url": WEBSITE,
            }});
            let _ = writeln!(sink, "{obj}");
        } else {
            let tag = if self.color {
                format!("{ERROR_ANSI}[ERROR]\x1b[0m")
            } else {
                "[ERROR]".to_owned()
            };
            let _ = writeln!(sink, "{tag} {}", err.message);
            if let Some(h) = &err.hint {
                let _ = writeln!(sink, "        try: {h}");
            }
        }
        err.exit_code
    }
}

/// Presence-based agent detection (CLI Standard §5): `AI_AGENT` or `AGENT` set
/// to any non-empty value. Real harnesses export descriptive strings such as
/// `AI_AGENT=claude-code_2-1-218_agent`, so comparing against `"1"` would miss
/// them. `CI` alone carries a truthy/falsy value.
fn is_agent_env() -> bool {
    let set = |var: &str| std::env::var_os(var).is_some_and(|v| !v.is_empty());
    set("AI_AGENT")
        || set("AGENT")
        || matches!(std::env::var("CI").as_deref(), Ok(v) if !v.is_empty() && v != "0" && v != "false")
}

// Rust guideline compliant 2026-05-18
