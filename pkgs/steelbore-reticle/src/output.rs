// SPDX-License-Identifier: GPL-3.0-or-later
//
// Output plumbing for the Spacecraft Software CLI Standard: the `metadata` +
// `data` envelope, the structured error object, the severity ladder, and the
// mode-detection cascade that decides between them. Same shape as
// pkgs/preflight/src/output.rs, plus `jsonl` and `--fields` for the one list
// command this tool has.

use std::io::{IsTerminal, Write};

use serde::Serialize;
use serde_json::Value;

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

pub const MAINTAINER: &str = "Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>";
/// The project URL: lib/identity.nix `urls.home`, injected by build.rs.
pub const WEBSITE: &str = env!("STEELBORE_OS_URL");

impl<T: Serialize> Response<T> {
    pub fn new(command: &str, data: T) -> Self {
        Self {
            metadata: Metadata {
                tool: env!("CARGO_PKG_NAME"),
                version: env!("CARGO_PKG_VERSION"),
                command: command.to_owned(),
                timestamp: now_utc(),
                tool_agent: detect_tool_agent(),
                maintainer: MAINTAINER,
                website: WEBSITE,
            },
            data,
        }
    }
}

/// ISO 8601 UTC, second precision, `Z`-suffixed.
pub fn now_utc() -> String {
    jiff::Timestamp::now()
        .round(jiff::Unit::Second)
        .unwrap_or_else(|_| jiff::Timestamp::now())
        .to_string()
}

/// Which harness is driving us, if any. Reported, never used to gate behavior.
fn detect_tool_agent() -> Option<String> {
    for var in ["CLAUDECODE", "CURSOR_AGENT", "GEMINI_CLI"] {
        if std::env::var_os(var).is_some() {
            return Some(var.to_ascii_lowercase().replace('_', "-"));
        }
    }
    None
}

/// Canonical exit codes (CLI Standard §4). `steelbore-reticle schema`
/// publishes this table.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(i32)]
pub enum Exit {
    Success = 0,
    Failure = 1,
    Usage = 2,
    NotFound = 3,
    Permission = 4,
}

/// Structured error object (CLI Standard §8). `hint` carries a command the
/// caller can run verbatim.
#[derive(Debug, Serialize)]
pub struct AppError {
    pub code: &'static str,
    pub exit_code: i32,
    pub message: String,
    pub hint: String,
    pub timestamp: String,
    pub command: String,
    pub docs_url: &'static str,
}

impl AppError {
    pub fn new(
        code: &'static str,
        exit: Exit,
        message: impl Into<String>,
        hint: impl Into<String>,
        command: &str,
    ) -> Self {
        Self {
            code,
            exit_code: exit as i32,
            message: message.into(),
            hint: hint.into(),
            timestamp: now_utc(),
            command: command.to_owned(),
            docs_url: WEBSITE,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, clap::ValueEnum)]
pub enum Format {
    Human,
    Json,
    Jsonl,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, clap::ValueEnum)]
pub enum ColorWhen {
    Auto,
    Always,
    Never,
}

/// Severity ladder. Color is never the sole carrier of meaning (Standard
/// §18.2.1), so every line also carries its bracketed tag.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum Level {
    Info = 0,
    Ok = 1,
    Warn = 2,
    Error = 3,
}

impl Level {
    const fn tag(self) -> &'static str {
        match self {
            Self::Info => "[INFO]",
            Self::Ok => "[OK]",
            Self::Warn => "[WARN]",
            Self::Error => "[ERROR]",
        }
    }

    const fn name(self) -> &'static str {
        match self {
            Self::Info => "info",
            Self::Ok => "ok",
            Self::Warn => "warn",
            Self::Error => "error",
        }
    }

    /// Steelbore Modern role tokens, as the nearest 256-color ANSI index:
    /// info -> structure, ok -> success, warn -> warning, error -> error.
    const fn ansi(self) -> &'static str {
        match self {
            Self::Info => "\x1b[38;5;141m",
            Self::Ok => "\x1b[38;5;154m",
            Self::Warn => "\x1b[38;5;207m",
            Self::Error => "\x1b[38;5;203m",
        }
    }
}

/// Resolved output policy for one run.
#[derive(Debug, Clone, Copy)]
pub struct Out {
    pub format: Format,
    pub color: bool,
    /// Severity floor: messages below this are dropped.
    pub floor: Level,
}

impl Out {
    /// The CLI Standard §5 detection cascade, first match wins. The agent
    /// check is PRESENCE-based: a live harness exports a descriptive string
    /// (`AI_AGENT=claude-code_…`), never just `1`.
    pub fn resolve(format: Option<Format>, color: ColorWhen, verbose: bool, quiet: bool) -> Self {
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

        // Agent mode raises the floor to warn; explicit flags beat detection.
        let floor = if quiet {
            Level::Error
        } else if verbose {
            Level::Info
        } else if agent {
            Level::Warn
        } else {
            Level::Ok
        };

        Self {
            format,
            color,
            floor,
        }
    }

    /// Emit a diagnostic. Always stderr: stdout is data only.
    pub fn say(self, level: Level, msg: &str) {
        if level < self.floor {
            return;
        }
        let mut err = std::io::stderr().lock();
        if self.format == Format::Human {
            if self.color {
                let _ = writeln!(err, "{}{}\x1b[0m {msg}", level.ansi(), level.tag());
            } else {
                let _ = writeln!(err, "{} {msg}", level.tag());
            }
        } else {
            let obj = serde_json::json!({
                "diagnostic": {
                    "level": level.name(),
                    "message": msg,
                    "timestamp": now_utc(),
                }
            });
            let _ = writeln!(err, "{obj}");
        }
    }

    /// Emit a single-record payload on stdout. `jsonl` renders the record as
    /// one line without the envelope.
    pub fn emit<T: Serialize>(self, command: &str, data: &T, human: &str) {
        let mut sink = std::io::stdout().lock();
        let line = match self.format {
            Format::Human => {
                let _ = write!(sink, "{human}");
                return;
            }
            Format::Json => serde_json::to_string(&Response::new(command, data)),
            Format::Jsonl => serde_json::to_string(data),
        };
        match line {
            Ok(s) => {
                let _ = writeln!(sink, "{s}");
            }
            Err(e) => self.say(Level::Error, &format!("cannot serialize output: {e}")),
        }
    }

    /// Emit a list payload: the envelope with a `data` array under `json`,
    /// one record per line under `jsonl`, `human` otherwise.
    pub fn emit_list(self, command: &str, records: &[Value], human: &str) {
        if self.format == Format::Jsonl {
            let mut sink = std::io::stdout().lock();
            for r in records {
                let _ = writeln!(sink, "{r}");
            }
        } else {
            self.emit(command, &records, human);
        }
    }

    /// Emit a structured error and return its exit code.
    pub fn fail(self, err: &AppError) -> i32 {
        let mut sink = std::io::stderr().lock();
        if self.format == Format::Human {
            let tag = Level::Error.tag();
            if self.color {
                let _ = writeln!(sink, "{}{tag}\x1b[0m {}", Level::Error.ansi(), err.message);
            } else {
                let _ = writeln!(sink, "{tag} {}", err.message);
            }
            let _ = writeln!(sink, "        try: {}", err.hint);
        } else {
            let obj = serde_json::json!({ "error": err });
            let _ = writeln!(sink, "{obj}");
        }
        err.exit_code
    }
}

/// Restrict each record to `fields` (CLI Standard `--fields`). Unknown names
/// are an error naming the valid ones, so a guessed field fails loudly
/// instead of silently returning empty records.
pub fn select_fields(
    records: Vec<Value>,
    fields: &[String],
    known: &[&str],
) -> Result<Vec<Value>, String> {
    if fields.is_empty() {
        return Ok(records);
    }
    if let Some(bad) = fields.iter().find(|f| !known.contains(&f.as_str())) {
        return Err(bad.clone());
    }
    Ok(records
        .into_iter()
        .map(|r| match r {
            Value::Object(map) => Value::Object(
                map.into_iter()
                    .filter(|(k, _)| fields.iter().any(|f| f == k))
                    .collect(),
            ),
            other => other,
        })
        .collect())
}

fn is_agent_env() -> bool {
    for v in ["AI_AGENT", "AGENT"] {
        if std::env::var_os(v).is_some_and(|val| !val.is_empty()) {
            return true;
        }
    }
    matches!(std::env::var("CI").as_deref(), Ok(v) if !v.is_empty() && v != "0" && v != "false")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fields_keep_only_the_named_keys() {
        let records =
            vec![serde_json::json!({"path": "/dev/input/event3", "name": "x", "kind": "pointer"})];
        let got = select_fields(records, &["path".to_owned()], &["path", "name", "kind"]);
        assert_eq!(
            got,
            Ok(vec![serde_json::json!({"path": "/dev/input/event3"})])
        );
    }

    #[test]
    fn an_unknown_field_is_named_back() {
        let got = select_fields(vec![], &["bogus".to_owned()], &["path"]);
        assert_eq!(got, Err("bogus".to_owned()));
    }

    #[test]
    fn timestamps_are_utc_with_z() {
        assert!(now_utc().ends_with('Z'));
    }
}
