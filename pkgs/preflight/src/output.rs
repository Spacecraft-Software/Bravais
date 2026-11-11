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
/// The project URL: lib/identity.nix `urls.home`, injected by build.rs.
pub const WEBSITE: &str = env!("STEELBORE_OS_URL");

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
pub enum Exit {
    Success = 0,
    Failure = 1,
    Usage = 2,
    NotFound = 3,
    Permission = 4,
    /// The working tree disagrees with what the run needs (dirty, diverged).
    Conflict = 5,
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
    /// Interactive full-screen TUI mode (CLI Standard §5)
    Explore,
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
#[expect(
    clippy::struct_excessive_bools,
    reason = "each boolean captures an orthogonal output policy resolved once at startup"
)]
#[derive(Debug, Clone, Copy)]
pub struct Out {
    pub format: Format,
    pub color: bool,
    /// Severity floor: messages below this are dropped.
    pub floor: Level,
    /// Draw spinners and progress bars on stderr (`progress::detect`): a
    /// human at a terminal only, never an agent, CI or a pipe.
    pub live: bool,
    /// Draw them in ASCII: the Linux console, or a non-UTF-8 locale.
    pub ascii: bool,
    /// A human is at the terminal and no agent, CI or pipe is involved. True
    /// even in accessible mode, where nothing animates but the run is still
    /// followed to its end (the Flatpak update) and announced step by step.
    pub attended: bool,
    /// Full-screen task view (`--tui`). Implies `live`.
    pub tui: bool,
    /// Standard §18 accessible mode: append-only output, no spinner, no
    /// redraw, no alternate screen.
    pub accessible: bool,
}

/// How accessible mode was decided (Standard §18.1). Reported under
/// `--verbose` so the user can tell *why* the mode is on or off.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum A11ySource {
    Flag,
    Env,
    Hint,
    Default,
}

impl A11ySource {
    pub const fn name(self) -> &'static str {
        match self {
            Self::Flag => "--accessible / --no-accessible",
            Self::Env => "SPACECRAFT_A11Y",
            Self::Hint => "environment hint (NO_COLOR or TERM=dumb)",
            Self::Default => "default (off)",
        }
    }
}

/// Standard §18.1 precedence: flag > environment > hints > default-off. An
/// explicit `false` at any level wins over every lower one. There is no
/// configuration file in preflight, so that source of the contract is absent.
pub fn resolve_a11y(flag: Option<bool>, env: Option<bool>, hint: bool) -> (bool, A11ySource) {
    match (flag, env) {
        (Some(v), _) => (v, A11ySource::Flag),
        (_, Some(v)) => (v, A11ySource::Env),
        _ if hint => (true, A11ySource::Hint),
        // Silence is never consent to change the default presentation.
        _ => (false, A11ySource::Default),
    }
}

/// `SPACECRAFT_A11Y=1|0` (also `true`/`false`); anything else is unset.
pub fn a11y_env() -> Option<bool> {
    match std::env::var("SPACECRAFT_A11Y").ok()?.trim() {
        "1" | "true" => Some(true),
        "0" | "false" => Some(false),
        _ => None,
    }
}

/// Only unambiguous signals. Never inferred from `$LANG`, terminal size or
/// the mere absence of a TTY.
pub fn a11y_hint() -> bool {
    std::env::var_os("NO_COLOR").is_some() || std::env::var("TERM").as_deref() == Ok("dumb")
}

/// What the caller asked of the display, beyond the output format.
#[derive(Debug, Clone, Copy, Default)]
pub struct UiRequest {
    /// `--tui`: the full-screen task view, asked for explicitly.
    pub tui: bool,
    /// `--cli`: line output with the bottom status bar, never the TUI.
    pub cli: bool,
    /// This command opens the TUI by default at an attended terminal (the
    /// rebuild run does; the subcommands are one-shot reports and do not).
    pub default_tui: bool,
    /// `--accessible` (`Some(true)`) / `--no-accessible` (`Some(false)`).
    pub accessible: Option<bool>,
}

impl Out {
    /// The CLI Standard §5 detection cascade, first match wins.
    ///
    /// Note the agent check is PRESENCE-based. A live Claude Code session
    /// exports `AI_AGENT=claude-code_2-1-218_agent`, so a detector comparing
    /// against `"1"` fails to recognise the very harness it is running under --
    /// the exact regression §10.1 calls out.
    pub fn resolve(
        format: Option<Format>,
        color: ColorWhen,
        verbose: bool,
        quiet: bool,
        ui: UiRequest,
    ) -> Self {
        let agent = is_agent_env();
        let tty = std::io::stdout().is_terminal();
        let asked_tui = ui.tui || format == Some(Format::Explore);
        // No format and no `--cli` is the default; `--format human` is the
        // long spelling of `--cli`.
        let want_tui = asked_tui || (ui.default_tui && !ui.cli && format.is_none());

        let format = match format {
            Some(Format::Explore) | None => {
                if agent || !tty {
                    Format::Json
                } else {
                    Format::Human
                }
            }
            Some(f) => f,
        };

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

        let (attended, ascii) = crate::progress::detect(format == Format::Human, agent);
        let (accessible, a11y_source) = resolve_a11y(ui.accessible, a11y_env(), a11y_hint());
        // The full-screen view also needs a keyboard to read, and is never
        // offered to accessible mode: a screen reader reads the character
        // grid, so a redrawn grid is a speech loop (Standard §18.2.3).
        let tui = want_tui && attended && !accessible && std::io::stdin().is_terminal();
        let live = attended && !accessible;

        let out = Self {
            format,
            color,
            floor,
            live,
            ascii,
            attended,
            tui,
            accessible,
        };
        // Only a request the user made is worth a warning: the default falls
        // back to line output silently, as it always has off a terminal.
        if asked_tui && !tui {
            out.say(
                Level::Warn,
                "interactive TUI mode unavailable in this environment; falling back to standard output (try: preflight --json)",
            );
        }
        if verbose {
            out.say(
                Level::Info,
                &format!(
                    "accessibility: {} ({})",
                    if accessible { "enabled" } else { "disabled" },
                    a11y_source.name()
                ),
            );
        }
        out
    }

    /// A non-live human policy for unit tests.
    #[cfg(test)]
    pub const fn for_tests(ascii: bool) -> Self {
        Self {
            format: Format::Human,
            color: false,
            floor: Level::Ok,
            live: false,
            ascii,
            attended: false,
            tui: false,
            accessible: false,
        }
    }

    /// Emit a diagnostic. Always stderr -- stdout is data only, always
    /// (non-negotiable #7), so a report stays pipeable even while narrating.
    pub fn say(self, level: Level, msg: &str) {
        if level < self.floor {
            return;
        }
        if self.format == Format::Json {
            let obj = serde_json::json!({
                "diagnostic": {
                    "level": format!("{level:?}").to_lowercase(),
                    "message": msg,
                    "timestamp": now_utc(),
                }
            });
            let _ = writeln!(std::io::stderr().lock(), "{obj}");
            return;
        }
        let line = if self.color {
            format!("{}{}\x1b[0m {msg}", level.ansi(), level.tag())
        } else {
            format!("{} {msg}", level.tag())
        };
        // A live display owns the bottom of the screen (or all of it), so
        // the line goes through it rather than around it.
        if crate::ui::emit(level, &line, &format!("{} {msg}", level.tag())) {
            return;
        }
        let _ = writeln!(std::io::stderr().lock(), "{line}");
    }

    /// A multi-line block (the disk report) for the human at the terminal,
    /// routed like [`Out::say`] so a live display is not written over.
    pub fn block(self, text: &str) {
        if self.format == Format::Json {
            return;
        }
        if crate::ui::emit_block(text) {
            return;
        }
        eprint!("{text}");
    }

    /// Progress in accessible mode: a plain `[INFO]` line, always shown (the
    /// severity floor would hide it), and only for a human at a terminal --
    /// every other caller gets exactly the output it got before.
    pub fn announce(self, msg: &str) {
        if self.accessible && self.attended && self.format == Format::Human {
            let _ = writeln!(std::io::stderr().lock(), "{} {msg}", Level::Info.tag());
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
            Format::Human | Format::Explore => {
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
