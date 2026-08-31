// SPDX-License-Identifier: GPL-3.0-or-later
//
// Output plumbing for the Spacecraft Software CLI Standard: the `metadata` +
// `data` envelope, the structured error object, the severity ladder, and the
// mode-detection cascade that decides between them.
//
// Kept in one module because all four are the same decision seen from different
// angles -- what the caller is, and therefore what shape output takes. Splitting
// them would mean threading `OutputMode` through three modules that each hold a
// third of the answer.

use std::io::{IsTerminal, Write};

use serde::Serialize;

/// Wire format for a successful command (CLI Standard §6).
///
/// Every subcommand returns this; none serializes bare data, so `metadata` is
/// never accidentally omitted from a new command.
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
    /// ISO 8601 UTC with the mandatory `Z` suffix (Standard §14.2). Never local
    /// time, never an offset -- those are display forms, not data.
    pub timestamp: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tool_agent: Option<String>,
    #[serde(skip_serializing_if = "std::ops::Not::not")]
    pub dry_run: bool,
    pub maintainer: &'static str,
    pub website: &'static str,
}

pub const MAINTAINER: &str = "Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>";
pub const WEBSITE: &str = "https://Bravais.SpacecraftSoftware.org/";

impl<T: Serialize> Response<T> {
    pub fn new(command: String, data: T, dry_run: bool) -> Self {
        Self {
            metadata: Metadata {
                tool: env!("CARGO_PKG_NAME"),
                version: env!("CARGO_PKG_VERSION"),
                command,
                timestamp: now_utc(),
                tool_agent: detect_tool_agent(),
                dry_run,
                maintainer: MAINTAINER,
                website: WEBSITE,
            },
            data,
        }
    }
}

/// ISO 8601 UTC, second precision, `Z`-suffixed.
///
/// `jiff::Timestamp` renders with sub-second precision and we truncate to
/// seconds: this stamps human-facing reports, and a nine-digit fraction is
/// noise in that context. Anything that needs finer granularity should carry a
/// duration alongside, not a longer timestamp.
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

/// Canonical exit codes (CLI Standard §4).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(i32)]
#[expect(
    dead_code,
    reason = "Usage and Permission are part of the exit-code contract that `preflight schema` publishes; clap emits 2 itself, and 4 is reserved for a sudo refusal this tool does not yet distinguish"
)]
pub enum Exit {
    Success = 0,
    Failure = 1,
    Usage = 2,
    NotFound = 3,
    Permission = 4,
}

/// Structured error object (CLI Standard §8, non-negotiable #8).
///
/// `hint` is the whole point: it carries a command the caller can run verbatim
/// to get unstuck, which is what makes an error actionable to an agent rather
/// than merely descriptive.
#[derive(Debug, Serialize)]
pub struct AppError {
    pub code: String,
    pub exit_code: i32,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub hint: Option<String>,
    pub timestamp: String,
    pub command: String,
    pub docs_url: &'static str,
}

impl AppError {
    pub fn new(code: &str, exit: Exit, message: impl Into<String>, command: &str) -> Self {
        Self {
            code: code.to_owned(),
            exit_code: exit as i32,
            message: message.into(),
            hint: None,
            timestamp: now_utc(),
            command: command.to_owned(),
            docs_url: WEBSITE,
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
    /// The CLI Standard §5 detection cascade, first match wins.
    ///
    /// Note the agent check is PRESENCE-based. A live Claude Code session
    /// exports `AI_AGENT=claude-code_2-1-218_agent`, so a detector comparing
    /// against `"1"` fails to recognise the very harness it is running under --
    /// the exact regression §10.1 calls out.
    pub fn resolve(format: Option<Format>, color: ColorWhen, verbose: bool, quiet: bool) -> Self {
        let agent = is_agent_env();
        let tty = std::io::stdout().is_terminal();

        let format = format.unwrap_or({
            if agent || !tty {
                Format::Json
            } else {
                Format::Human
            }
        });

        let color = match color {
            ColorWhen::Never => false,
            ColorWhen::Always => true,
            ColorWhen::Auto => {
                format == Format::Human
                    && tty
                    && !agent
                    && std::env::var_os("NO_COLOR").is_none()
                    && std::env::var("TERM").as_deref() != Ok("dumb")
            }
        };

        let floor = if quiet {
            Level::Error
        } else if verbose {
            Level::Info
        } else {
            Level::Ok
        };

        Self {
            format,
            color,
            floor,
        }
    }

    /// Emit a diagnostic. Always stderr -- stdout is data only, always
    /// (non-negotiable #7), so a report stays pipeable even while narrating.
    pub fn say(self, level: Level, msg: &str) {
        if level < self.floor {
            return;
        }
        let mut err = std::io::stderr().lock();
        if self.format == Format::Json {
            let obj = serde_json::json!({
                "diagnostic": {
                    "level": format!("{level:?}").to_lowercase(),
                    "message": msg,
                    "timestamp": now_utc(),
                }
            });
            let _ = writeln!(err, "{obj}");
        } else if self.color {
            let _ = writeln!(err, "{}{}\x1b[0m {msg}", level.ansi(), level.tag());
        } else {
            let _ = writeln!(err, "{} {msg}", level.tag());
        }
    }

    /// Emit the payload on stdout.
    pub fn emit<T: Serialize>(self, command: &str, data: &T, dry_run: bool, human: &str) {
        let mut sink = std::io::stdout().lock();
        match self.format {
            Format::Json => {
                let env = Response::new(command.to_owned(), data, dry_run);
                match serde_json::to_string(&env) {
                    Ok(s) => {
                        let _ = writeln!(sink, "{s}");
                    }
                    // Serializing our own types cannot fail in practice; report
                    // rather than panic so a rebuild is never aborted by an
                    // output bug (M-PANIC-IS-STOP: this is not a bug we can act
                    // on at runtime, but it is also not worth killing a switch).
                    Err(e) => {
                        self.say(Level::Error, &format!("cannot serialize output: {e}"));
                    }
                }
            }
            Format::Human => {
                let _ = write!(sink, "{human}");
            }
        }
    }

    /// Emit a structured error and return its exit code.
    pub fn fail(self, err: &AppError) -> i32 {
        let mut sink = std::io::stderr().lock();
        if self.format == Format::Json {
            let obj = serde_json::json!({ "error": err });
            let _ = writeln!(sink, "{obj}");
        } else {
            let tag = Level::Error.tag();
            if self.color {
                let _ = writeln!(sink, "{}{tag}\x1b[0m {}", Level::Error.ansi(), err.message);
            } else {
                let _ = writeln!(sink, "{tag} {}", err.message);
            }
            if let Some(h) = &err.hint {
                let _ = writeln!(sink, "       try: {h}");
            }
        }
        err.exit_code
    }
}

fn is_agent_env() -> bool {
    for v in ["AI_AGENT", "AGENT"] {
        if let Ok(val) = std::env::var(v) {
            if !val.is_empty() && val != "0" && val != "false" {
                return true;
            }
        }
    }
    matches!(std::env::var("CI").as_deref(), Ok(v) if !v.is_empty() && v != "0" && v != "false")
}
