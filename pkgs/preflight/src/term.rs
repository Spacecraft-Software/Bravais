// SPDX-License-Identifier: GPL-3.0-or-later
//
// Modern terminal protocols for `preflight` (spacecraft-tui-protocols v1.0.0).
//
// What preflight speaks, and why only these:
//
// | Protocol             | Used for                                         |
// |----------------------|--------------------------------------------------|
// | kitty keyboard       | the `--tui` view: `Esc` (abort) is unambiguous   |
// | OSC 52 (write)       | `y` in the `--tui` view copies a task or the log |
// | OSC 9;4 progress     | overall rebuild / Flatpak progress in the tab    |
//
// Graphics, animation, rich clipboard (OSC 5522) and pointer shapes (OSC 22)
// are not used: preflight shows no images and has no mouse regions. They are
// still listed in `describe` so a user can see that, not guess it.
//
// The five rules of the skill (§2) map onto this file as follows:
//
// 1. Gate -- `gated()`: nothing is sent, and nothing is probed, unless a human
//    is attended at a terminal (`Out::attended`: both streams are TTYs, no
//    `AI_AGENT` / `AGENT` / `CI`), `TERM` is set and is neither `dumb` nor
//    `linux` (the kernel console prints unknown OSC payloads as text).
// 2. Probe once -- `probe()`: one write of `CSI ? u` (only when the TUI will
//    read keys), XTVERSION and a trailing DA1, read from `/dev/tty` in raw mode
//    with `poll(2)` under a 200 ms deadline, then a drain (quiet for 20 ms,
//    100 ms at most) so a late reply never lands in the shell as typed text.
//    Never blocks, and only runs in the terminal's foreground process group.
//    Keys typed meanwhile are kept for the TUI (`take_typeahead`), and the
//    interrupt, quit and suspend keys still raise their signals.
// 3. Restore -- `restore()` pops the keyboard flags and clears the progress
//    indicator; `ui` calls it before leaving the alternate screen, the panic
//    hook calls it, and `install_signal_handlers` runs it on SIGINT, SIGTERM
//    and SIGHUP before dying of the same signal. `swap` makes each step run
//    once however many of those paths fire.
// 4. No collisions -- OSC 9;4 goes only to terminals on the allow-list
//    (`progress_terminal`), never to an unknown one, where OSC 9 is a desktop
//    notification and every update would pop a toast reading `4;1;50`.
// 5. Override -- `--term-protocols` and `SPACECRAFT_TERM_PROTOCOLS`, flag over
//    variable. An override beats detection (probe and allow-list); it never
//    beats the gate in rule 1, because no user intent makes escape sequences
//    in an agent's or a pipe's stream correct.
//
// Every sequence is written to stderr, the stream the live bar and the TUI
// already own. stdout stays data only (CLI Standard non-negotiable #7).

// Rust guideline compliant 2026-05-18

use std::fmt;
use std::fs::{File, OpenOptions};
use std::io::{Read as _, Write as _};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};

use serde::Serialize;

/// Environment variable holding the protocol override list (skill §2.5).
pub const ENV: &str = "SPACECRAFT_TERM_PROTOCOLS";

/// Whole probe exchange cap (skill §2.2). Terminals answer DA1 in well under
/// 10 ms locally; 200 ms leaves room for SSH round trips without a visible
/// delay at startup.
const PROBE_DEADLINE: Duration = Duration::from_millis(200);

/// After the fence, keep swallowing for this long with nothing arriving, so a
/// reply that raced the deadline is not left for the shell to read.
const DRAIN_QUIET: Duration = Duration::from_millis(20);

/// OSC 9;4 updates no more often than this (about 5 a second, the skill's
/// figure). State changes (paused, error, clear) are never held back.
const PROGRESS_MIN_GAP: Duration = Duration::from_millis(200);

/// Largest text OSC 52 is asked to carry. Several terminals and tmux cap the
/// whole sequence near 100 KB of base64; 74 000 bytes encodes to 98 668.
pub const CLIPBOARD_MAX: usize = 74_000;

/// First `WezTerm` build whose OSC 9;4 is progress rather than a notification
/// (`references/wezterm.md`: commits `fb02395` / `44866cc`, 2025-02-09; the
/// tab-bar display landed 2025-02-10). The 20240203 stable pops a toast.
const WEZTERM_PROGRESS_SINCE: u32 = ymd(2025, 2, 10);

/// A date as the `YYYYMMDD` number `WezTerm` versions are compared by.
const fn ymd(year: u32, month: u32, day: u32) -> u32 {
    year * 10_000 + month * 100 + day
}

/// First kitty release that shows OSC 9;4 instead of notifying: 0.39.0, per
/// kitty's maintainer in rust-lang/cargo#14615. kitty sets no version
/// variable, so this is read from XTVERSION only; without it, kitty gets none.
const KITTY_PROGRESS_SINCE: (u32, u32, u32) = (0, 39, 0);

/// iTerm2 3.6 added OSC 9;4; earlier releases treat OSC 9 as a notification.
const ITERM_PROGRESS_SINCE: (u32, u32, u32) = (3, 6, 0);

/// The protocol names of skill §2.5, in its order.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Protocol {
    Keyboard,
    Graphics,
    Animation,
    Clipboard,
    ClipboardRich,
    Progress,
    Pointer,
}

impl Protocol {
    pub const ALL: [Self; 7] = [
        Self::Keyboard,
        Self::Graphics,
        Self::Animation,
        Self::Clipboard,
        Self::ClipboardRich,
        Self::Progress,
        Self::Pointer,
    ];

    pub const fn name(self) -> &'static str {
        match self {
            Self::Keyboard => "keyboard",
            Self::Graphics => "graphics",
            Self::Animation => "animation",
            Self::Clipboard => "clipboard",
            Self::ClipboardRich => "clipboard-rich",
            Self::Progress => "progress",
            Self::Pointer => "pointer",
        }
    }

    const fn bit(self) -> u8 {
        1 << self as u8
    }

    fn from_name(s: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|p| p.name() == s)
    }
}

impl fmt::Display for Protocol {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.name())
    }
}

/// Forced-on and forced-off protocols, from one list or several layered ones.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct Overrides {
    on: u8,
    off: u8,
}

impl Overrides {
    /// Parse `+name,-name,name,all,-all`. A bare name means `+name`; later
    /// items win within the list; empty items are ignored, so `""` and a
    /// trailing comma are both fine.
    ///
    /// # Errors
    ///
    /// Returns the offending item when a name is not one of skill §2.5's.
    pub fn parse(list: &str) -> Result<Self, String> {
        let mut o = Self::default();
        for item in list.split(',').map(str::trim).filter(|s| !s.is_empty()) {
            let (force_on, name) = match item.as_bytes()[0] {
                b'+' => (true, &item[1..]),
                b'-' => (false, &item[1..]),
                _ => (true, item),
            };
            let bits = if name == "all" {
                Protocol::ALL.iter().fold(0, |acc, p| acc | p.bit())
            } else {
                Protocol::from_name(name)
                    .ok_or_else(|| format!("unknown terminal protocol '{item}'"))?
                    .bit()
            };
            if force_on {
                o.on |= bits;
                o.off &= !bits;
            } else {
                o.off |= bits;
                o.on &= !bits;
            }
        }
        Ok(o)
    }

    /// `top` applied over `self`: wherever `top` says anything, it wins.
    #[must_use]
    pub const fn under(self, top: Self) -> Self {
        let said = top.on | top.off;
        Self {
            on: (self.on & !said) | top.on,
            off: (self.off & !said) | top.off,
        }
    }

    /// `Some(true)` forced on, `Some(false)` forced off, `None` = detect.
    pub const fn get(self, p: Protocol) -> Option<bool> {
        if self.on & p.bit() != 0 {
            Some(true)
        } else if self.off & p.bit() != 0 {
            Some(false)
        } else {
            None
        }
    }
}

/// The variable layered under the flag (skill §2.5: the flag wins).
///
/// # Errors
///
/// Names the source (`--term-protocols` or the variable) and the bad item.
pub fn overrides(flag: Option<&str>) -> Result<Overrides, String> {
    let env = match std::env::var(ENV) {
        Ok(v) => Overrides::parse(&v).map_err(|e| format!("{ENV}: {e}"))?,
        Err(_) => Overrides::default(),
    };
    let top = match flag {
        Some(v) => Overrides::parse(v).map_err(|e| format!("--term-protocols: {e}"))?,
        None => Overrides::default(),
    };
    Ok(env.under(top))
}

/// One protocol's resolved state, as `describe` and `--verbose` report it.
#[derive(Debug, Clone, Serialize)]
pub struct Entry {
    pub protocol: &'static str,
    pub enabled: bool,
    pub reason: String,
}

/// What the terminal said about itself, for `describe`.
#[derive(Debug, Clone, Default, Serialize)]
pub struct Terminal {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub term: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub term_program: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub term_program_version: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub xtversion: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub multiplexer: Option<&'static str>,
    /// Whether the DA1 fence came back inside the deadline; `false` with
    /// `probed` means the terminal answered nothing at all.
    pub probed: bool,
    pub answered: bool,
}

/// The session's capabilities, fixed at startup (skill §2.2 step 4).
#[expect(
    clippy::struct_excessive_bools,
    reason = "one switch per protocol in use, plus the gate; each is independent"
)]
#[derive(Debug, Clone, Serialize)]
pub struct Caps {
    pub gated: bool,
    pub terminal: Terminal,
    pub protocols: Vec<Entry>,
    #[serde(skip)]
    keyboard: bool,
    #[serde(skip)]
    clipboard: bool,
    #[serde(skip)]
    progress: bool,
}

impl Caps {
    /// Nothing enabled, every protocol explained by `reason`.
    fn off(reason: &str, terminal: Terminal) -> Self {
        Self {
            gated: false,
            terminal,
            protocols: Protocol::ALL
                .iter()
                .map(|p| Entry {
                    protocol: p.name(),
                    enabled: false,
                    reason: reason.to_owned(),
                })
                .collect(),
            keyboard: false,
            clipboard: false,
            progress: false,
        }
    }

    /// `name: on|off (reason)`, one per line, for `--verbose`.
    pub fn summary(&self) -> String {
        self.protocols
            .iter()
            .map(|e| {
                format!(
                    "terminal protocol {}: {} ({})",
                    e.protocol,
                    if e.enabled { "on" } else { "off" },
                    e.reason
                )
            })
            .collect::<Vec<_>>()
            .join("\n")
    }
}

static CAPS: OnceLock<Caps> = OnceLock::new();

/// The capabilities `init` resolved; all-off before it runs (unit tests,
/// and any code path that runs ahead of `main`'s call).
pub fn caps() -> &'static Caps {
    CAPS.get_or_init(|| Caps::off("not initialised", Terminal::default()))
}

/// The skill §2.1 gate, minus the user override (applied per protocol).
///
/// `attended` is `Out::attended`: human format, stdout and stderr both
/// terminals, no agent or CI variable, `TERM` not `dumb`.
fn gate(attended: bool, term: Option<&str>) -> Result<(), &'static str> {
    if !attended {
        return Err("no attended terminal (agent, CI, pipe or machine format)");
    }
    match term {
        None | Some("") => Err("TERM is unset"),
        Some("dumb") => Err("TERM=dumb"),
        // The kernel console parses `ESC ]` only for its palette sequences and
        // prints the rest of any other OSC as text.
        Some("linux") => Err("TERM=linux (kernel console)"),
        Some(_) => Ok(()),
    }
}

fn multiplexer() -> Option<&'static str> {
    [("TMUX", "tmux"), ("ZELLIJ", "zellij"), ("STY", "screen")]
        .into_iter()
        .find(|(var, _)| std::env::var_os(var).is_some_and(|v| !v.is_empty()))
        .map(|(_, name)| name)
}

fn env(var: &str) -> Option<String> {
    std::env::var(var).ok().filter(|v| !v.is_empty())
}

/// Resolve and cache the capabilities for this run. Call once, after the
/// output policy is known and before any UI starts reading the terminal.
///
/// `tui` is whether the full-screen view will run; only it reads keys, so
/// only then is the keyboard protocol probed for.
pub fn init(attended: bool, tui: bool, overrides: Overrides) -> &'static Caps {
    CAPS.get_or_init(|| resolve(attended, tui, overrides))
}

fn resolve(attended: bool, tui: bool, ov: Overrides) -> Caps {
    let mut terminal = Terminal {
        term: env("TERM"),
        term_program: env("TERM_PROGRAM"),
        term_program_version: env("TERM_PROGRAM_VERSION"),
        multiplexer: multiplexer(),
        ..Terminal::default()
    };
    if let Err(why) = gate(attended, terminal.term.as_deref()) {
        return Caps::off(why, terminal);
    }

    let want_keyboard = tui && ov.get(Protocol::Keyboard) != Some(false);
    let reply = probe(want_keyboard, PROBE_DEADLINE);
    terminal.probed = reply.is_some();
    let reply = reply.unwrap_or_default();
    terminal.answered = reply.da1;
    terminal.xtversion = reply.xtversion;

    let not_used = |p: Protocol| Entry {
        protocol: p.name(),
        enabled: false,
        reason: "not used by preflight".to_owned(),
    };
    let forced = |p: Protocol, on: bool| Entry {
        protocol: p.name(),
        enabled: on,
        reason: format!(
            "forced {} by --term-protocols / {ENV}",
            if on { "on" } else { "off" }
        ),
    };

    let keyboard = match (tui, ov.get(Protocol::Keyboard)) {
        (false, _) => not_used(Protocol::Keyboard),
        (true, Some(on)) => forced(Protocol::Keyboard, on),
        (true, None) => Entry {
            protocol: "keyboard",
            enabled: reply.kitty_keyboard,
            reason: if reply.kitty_keyboard {
                "terminal answered CSI ? u".to_owned()
            } else if terminal.term_program.as_deref() == Some("WezTerm") {
                "no reply to CSI ? u (WezTerm: set config.enable_kitty_keyboard = true)".to_owned()
            } else {
                "no reply to CSI ? u; legacy keys".to_owned()
            },
        },
    };

    let clipboard = match ov.get(Protocol::Clipboard) {
        Some(on) => forced(Protocol::Clipboard, on),
        // No query exists for OSC 52 write (references/clipboard.md rule 2):
        // send it once the gate passes; the TUI confirms every copy in text.
        None => Entry {
            protocol: "clipboard",
            enabled: true,
            reason: "OSC 52 write has no query; sent on request, confirmed in the log".to_owned(),
        },
    };

    let progress = match ov.get(Protocol::Progress) {
        Some(on) => forced(Protocol::Progress, on),
        None => match progress_terminal(&terminal) {
            Ok(name) => Entry {
                protocol: "progress",
                enabled: true,
                reason: format!("{name} is on the OSC 9;4 allow-list"),
            },
            Err(why) => Entry {
                protocol: "progress",
                enabled: false,
                reason: why,
            },
        },
    };

    let protocols = Protocol::ALL
        .iter()
        .map(|&p| match p {
            Protocol::Keyboard => keyboard.clone(),
            Protocol::Clipboard => clipboard.clone(),
            Protocol::Progress => progress.clone(),
            _ => not_used(p),
        })
        .collect();

    Caps {
        gated: true,
        keyboard: keyboard.enabled,
        clipboard: clipboard.enabled,
        progress: progress.enabled,
        terminal,
        protocols,
    }
}

// --- Probe -------------------------------------------------------------------

#[derive(Debug, Default, PartialEq, Eq)]
struct Reply {
    kitty_keyboard: bool,
    xtversion: Option<String>,
    da1: bool,
}

/// After the fence, never drain for longer than this in all, however
/// steadily a terminal (or a held-down key) keeps the line busy.
const DRAIN_MAX: Duration = Duration::from_millis(100);

/// Most the probe reads. Every reply together is under 200 bytes; past this
/// the line is not answering a probe, and reading stops.
const PROBE_MAX_BYTES: usize = 4096;

/// The termios the probe saved, held while the probe has the terminal raw.
/// SIGTERM or SIGHUP mid-probe kills the process before `RawGuard` drops, so
/// the signal thread puts this back first ([`install_signal_handlers`]).
static PROBE_SAVED: Mutex<Option<rustix::termios::Termios>> = Mutex::new(None);

/// What the user typed while the probe owned the terminal: every byte read
/// that was not a reply (skill §2.2 hands these to the input path).
static TYPEAHEAD: Mutex<Vec<u8>> = Mutex::new(Vec::new());

/// Take the keys typed during the probe, for the TUI to replay as input. In
/// any other mode nothing reads keys, and they are dropped: a raw read cannot
/// be pushed back (`TIOCSTI` is disabled by default since Linux 6.2).
pub fn take_typeahead() -> Vec<u8> {
    TYPEAHEAD
        .lock()
        .map(|mut t| std::mem::take(&mut *t))
        .unwrap_or_default()
}

/// Restores the saved termios on drop, so an early return (or a panic in the
/// read loop) never leaves the user's terminal raw.
struct RawGuard<'a> {
    tty: &'a File,
    saved: rustix::termios::Termios,
}

impl Drop for RawGuard<'_> {
    fn drop(&mut self) {
        let _ = rustix::termios::tcsetattr(
            self.tty,
            rustix::termios::OptionalActions::Now,
            &self.saved,
        );
        if let Ok(mut slot) = PROBE_SAVED.lock() {
            *slot = None;
        }
    }
}

/// Put back the termios a probe in flight saved. Run by the signal thread.
fn restore_probe_termios() {
    let saved = PROBE_SAVED.lock().ok().and_then(|mut s| s.take());
    if let (Some(saved), Ok(tty)) = (saved, OpenOptions::new().write(true).open("/dev/tty")) {
        let _ = rustix::termios::tcsetattr(&tty, rustix::termios::OptionalActions::Now, &saved);
    }
}

/// `None` when the probe could not run at all (no `/dev/tty`, no termios,
/// or a background job). Any failure inside it is "nothing supported", never
/// an error: a failed probe must not stop the program (references/detection.md).
fn probe(want_keyboard: bool, deadline: Duration) -> Option<Reply> {
    use rustix::termios::{tcgetattr, tcgetpgrp, tcsetattr, OptionalActions};
    let tty = OpenOptions::new()
        .read(true)
        .write(true)
        .open("/dev/tty")
        .ok()?;
    // A background job that changes termios is stopped by SIGTTOU, and one
    // that reads the terminal by SIGTTIN; replies would go to the foreground
    // program anyway. Probe only from the foreground process group.
    if tcgetpgrp(&tty).ok()? != rustix::process::getpgrp() {
        return None;
    }
    let saved = tcgetattr(&tty).ok()?;
    let mut raw = saved.clone();
    raw.make_raw();
    if let Ok(mut slot) = PROBE_SAVED.lock() {
        *slot = Some(saved.clone());
    }
    // The guard first, so a failed switch still clears `PROBE_SAVED`.
    let guard = RawGuard {
        tty: &tty,
        saved: saved.clone(),
    };
    tcsetattr(&tty, OptionalActions::Now, &raw).ok()?;

    let mut query: Vec<u8> = Vec::with_capacity(24);
    if want_keyboard {
        query.extend_from_slice(b"\x1b[?u");
    }
    // XTVERSION: the only identity that survives SSH, and the only place
    // kitty states its version. DA1 last: every terminal answers it, in order.
    query.extend_from_slice(b"\x1b[>0q\x1b[c");
    let mut io: &File = guard.tty;
    if io.write_all(&query).and_then(|()| io.flush()).is_err() {
        return Some(Reply::default());
    }

    let mut buf = Vec::with_capacity(256);
    let mut chunk = [0u8; 512];
    let mut read_some = |buf: &mut Vec<u8>, wait: Duration| -> bool {
        if buf.len() >= PROBE_MAX_BYTES || !readable(guard.tty, wait) {
            return false;
        }
        match io.read(&mut chunk) {
            Ok(0) | Err(_) => false,
            Ok(n) => {
                buf.extend_from_slice(&chunk[..n]);
                true
            }
        }
    };
    let end = Instant::now() + deadline;
    while let Some(left) = end.checked_duration_since(Instant::now()) {
        if !read_some(&mut buf, left) || parse_replies(&buf).da1 {
            break;
        }
    }
    let reply = parse_replies(&buf);
    // Swallow anything still in flight (skill §2.2 step 3), until the line
    // has been quiet for `DRAIN_QUIET` or `DRAIN_MAX` has passed.
    let drain_end = Instant::now() + DRAIN_MAX;
    while let Some(left) = drain_end.checked_duration_since(Instant::now()) {
        if !read_some(&mut buf, left.min(DRAIN_QUIET)) {
            break;
        }
    }
    drop(guard);
    deliver_typeahead(&split_replies(&buf).1, &saved);
    Some(reply)
}

/// Act on what the user typed during the probe, now that the terminal is
/// cooked again. Raw mode turned the interrupt, quit and suspend keys into
/// bytes; they become the signals the user asked for. The rest is kept for
/// [`take_typeahead`].
fn deliver_typeahead(typed: &[u8], saved: &rustix::termios::Termios) {
    use rustix::termios::{LocalModes, SpecialCodeIndex};
    use signal_hook::consts::{SIGINT, SIGQUIT, SIGTSTP};
    let isig = saved.local_modes.contains(LocalModes::ISIG);
    let key = |idx: SpecialCodeIndex| Some(saved.special_codes[idx]).filter(|&c| c != 0);
    let signals = [
        (key(SpecialCodeIndex::VINTR), SIGINT),
        (key(SpecialCodeIndex::VQUIT), SIGQUIT),
        (key(SpecialCodeIndex::VSUSP), SIGTSTP),
    ];
    let mut kept = Vec::new();
    for &b in typed {
        match signals.iter().find(|(c, _)| isig && *c == Some(b)) {
            Some(&(_, sig)) => {
                let _ = signal_hook::low_level::raise(sig);
            }
            None => kept.push(b),
        }
    }
    if let Ok(mut t) = TYPEAHEAD.lock() {
        t.extend_from_slice(&kept);
    }
}

fn readable(tty: &File, wait: Duration) -> bool {
    use rustix::event::{poll, PollFd, PollFlags};
    let Ok(timeout) = rustix::event::Timespec::try_from(wait) else {
        return false;
    };
    let mut fds = [PollFd::new(tty, PollFlags::IN)];
    matches!(poll(&mut fds, Some(&timeout)), Ok(n) if n > 0)
}

fn parse_replies(buf: &[u8]) -> Reply {
    split_replies(buf).0
}

/// Scan everything read so far into the replies found and the bytes that
/// are not replies (keys typed meanwhile). Replies may arrive split across
/// reads, so this re-reads the whole (tiny) buffer each time rather than keep
/// state; a reply cut off by the end of the buffer counts as neither.
fn split_replies(buf: &[u8]) -> (Reply, Vec<u8>) {
    let mut r = Reply::default();
    let mut typed = Vec::new();
    let mut i = 0;
    while i < buf.len() {
        if buf[i] != 0x1b {
            typed.push(buf[i]);
            i += 1;
            continue;
        }
        let rest = &buf[i + 1..];
        // CSI ? <digits;…> u  (kitty keyboard flags)  /  … c  (DA1)
        if rest.starts_with(b"[?") {
            let mut j = i + 3;
            while j < buf.len() && (buf[j].is_ascii_digit() || buf[j] == b';') {
                j += 1;
            }
            match buf.get(j) {
                Some(b'u') => r.kitty_keyboard = true,
                Some(b'c') => r.da1 = true,
                // Cut off: the rest of it is still on the wire.
                None => return (r, typed),
                Some(_) => {}
            }
            i = j + 1;
            continue;
        }
        // DCS > | <text> ST  (XTVERSION), ST = ESC \ or BEL
        if rest.starts_with(b"P>|") {
            let body = &buf[i + 4..];
            let end = body
                .iter()
                .position(|&b| b == 0x1b || b == 0x07)
                .filter(|&e| body[e] == 0x07 || body.get(e + 1) == Some(&b'\\'));
            let Some(e) = end else {
                return (r, typed);
            };
            let text: String = String::from_utf8_lossy(&body[..e])
                .chars()
                .filter(|c| !c.is_control())
                .take(64)
                .collect();
            if !text.is_empty() {
                r.xtversion = Some(text);
            }
            i += 4 + e + usize::from(body[e] == 0x1b) + 1;
            continue;
        }
        // A lone trailing ESC is the Esc key once the line has gone quiet;
        // while reading, it only matters that it is no reply yet.
        if rest.is_empty() {
            typed.push(0x1b);
            return (r, typed);
        }
        // A prefix of either reply, cut off by the end of the buffer.
        if rest == b"[" || rest == b"P" || rest == b"P>" {
            return (r, typed);
        }
        typed.push(0x1b);
        i += 1;
    }
    (r, typed)
}

// --- OSC 9;4 allow-list ---------------------------------------------------------

/// The terminal's name when it is on the OSC 9;4 allow-list
/// (references/progress-pointer.md), or why it is not.
fn progress_terminal(t: &Terminal) -> Result<&'static str, String> {
    if let Some(mux) = t.multiplexer {
        // Skill §3: wrap in passthrough or skip. Skipping is the safe choice:
        // the outer terminal's identity is unknown from in here.
        return Err(format!("inside {mux}; OSC 9;4 is not passed through"));
    }
    if env("WT_SESSION").is_some() {
        return Ok("Windows Terminal");
    }
    if env("ConEmuPID").is_some() || env("ConEmuANSI").as_deref() == Some("ON") {
        return Ok("ConEmu");
    }
    let program = t.term_program.as_deref().unwrap_or("").to_ascii_lowercase();
    let xt = t.xtversion.as_deref().unwrap_or("");
    let xt_lower = xt.to_ascii_lowercase();
    for (needle, name) in [
        ("ghostty", "Ghostty"),
        ("vscode", "VS Code"),
        ("rio", "Rio"),
        ("contour", "contour"),
    ] {
        if program.contains(needle) || xt_lower.starts_with(needle) {
            return Ok(name);
        }
    }
    if program == "wezterm" || xt_lower.starts_with("wezterm") {
        let version = t
            .term_program_version
            .as_deref()
            .or_else(|| xt.split_once(' ').map(|(_, v)| v));
        return match version.and_then(wezterm_date) {
            Some(d) if d >= WEZTERM_PROGRESS_SINCE => Ok("WezTerm"),
            Some(d) => Err(format!(
                "WezTerm {d} predates {WEZTERM_PROGRESS_SINCE}; its OSC 9 is a notification"
            )),
            None => Err("WezTerm version unknown; OSC 9 may be a notification".to_owned()),
        };
    }
    if program == "iterm.app" {
        return match t.term_program_version.as_deref().and_then(semver) {
            Some(v) if v >= ITERM_PROGRESS_SINCE => Ok("iTerm2"),
            _ => Err("iTerm2 older than 3.6, or version unknown".to_owned()),
        };
    }
    let term = t.term.as_deref().unwrap_or("");
    if term == "xterm-kitty" || env("KITTY_WINDOW_ID").is_some() || xt_lower.starts_with("kitty") {
        // `kitty(0.39.0)`
        let v = xt
            .split_once('(')
            .and_then(|(_, rest)| rest.split_once(')'))
            .and_then(|(v, _)| semver(v));
        return match v {
            Some(v) if v >= KITTY_PROGRESS_SINCE => Ok("kitty"),
            _ => Err("kitty older than 0.39, or no XTVERSION reply".to_owned()),
        };
    }
    if term.starts_with("foot") || xt_lower.starts_with("foot") {
        return Ok("foot");
    }
    Err(format!(
        "terminal not on the OSC 9;4 allow-list ({}); force with --term-protocols=+progress",
        t.term_program
            .as_deref()
            .or(t.xtversion.as_deref())
            .or(t.term.as_deref())
            .unwrap_or("unknown")
    ))
}

/// `WezTerm` builds are dated: `20250210-123456-abcdef12` upstream, and
/// `0-unstable-2026-03-31` from nixpkgs. Returns `YYYYMMDD`.
fn wezterm_date(v: &str) -> Option<u32> {
    let head: String = v.chars().take_while(char::is_ascii_digit).collect();
    if head.len() >= 8 {
        return head[..8].parse().ok();
    }
    let (_, rest) = v.split_once("unstable-")?;
    let digits: String = rest.chars().take(10).filter(char::is_ascii_digit).collect();
    (digits.len() == 8).then(|| digits.parse().ok()).flatten()
}

/// `0.39.2` / `3.6` → `(0, 39, 2)` / `(3, 6, 0)`.
fn semver(v: &str) -> Option<(u32, u32, u32)> {
    let mut it = v.trim().split('.').map(|p| {
        p.chars()
            .take_while(char::is_ascii_digit)
            .collect::<String>()
            .parse::<u32>()
    });
    let major = it.next()?.ok()?;
    let minor = it.next().and_then(Result::ok).unwrap_or(0);
    let patch = it.next().and_then(Result::ok).unwrap_or(0);
    Some((major, minor, patch))
}

// --- Emission -------------------------------------------------------------------

/// OSC 9;4 states (references/progress-pointer.md).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Taskbar {
    /// Determinate progress, 0–100.
    Normal(u8),
    /// Waiting on the user (a password or fingerprint prompt).
    Paused(u8),
    /// The run failed.
    Error(u8),
}

impl Taskbar {
    const fn code(self) -> (u8, u8) {
        match self {
            Self::Normal(p) => (1, p),
            Self::Paused(p) => (4, p),
            Self::Error(p) => (2, p),
        }
    }
}

static KEYBOARD_PUSHED: AtomicBool = AtomicBool::new(false);
/// Set once a fatal signal is being handled: nothing may be sent after the
/// restore, or a drawer tick racing the exit would put the bar back.
static FROZEN: AtomicBool = AtomicBool::new(false);
static PROGRESS_SHOWN: AtomicBool = AtomicBool::new(false);
static LAST_PROGRESS: Mutex<Option<(Taskbar, Instant)>> = Mutex::new(None);

fn send(bytes: &[u8]) {
    if FROZEN.load(Ordering::Acquire) {
        return;
    }
    let mut err = std::io::stderr().lock();
    let _ = err.write_all(bytes);
    let _ = err.flush();
}

/// Show `state` in the terminal's tab or taskbar, when the terminal is on the
/// allow-list. Unchanged values and updates faster than 5 a second are
/// dropped; a change of state always goes out.
pub fn taskbar(state: Taskbar) {
    if !caps().progress {
        return;
    }
    let Ok(mut last) = LAST_PROGRESS.lock() else {
        return;
    };
    let now = Instant::now();
    if let Some((prev, at)) = *last {
        let same_kind = std::mem::discriminant(&prev) == std::mem::discriminant(&state);
        if prev == state || (same_kind && now.duration_since(at) < PROGRESS_MIN_GAP) {
            return;
        }
    }
    *last = Some((state, now));
    let (code, pct) = state.code();
    PROGRESS_SHOWN.store(true, Ordering::Release);
    send(format!("\x1b]9;4;{code};{}\x1b\\", pct.min(100)).as_bytes());
}

/// Remove the tab/taskbar indicator, if one is shown.
pub fn taskbar_clear() {
    if PROGRESS_SHOWN.swap(false, Ordering::AcqRel) {
        write_now(b"\x1b]9;4;0;0\x1b\\");
    }
    if let Ok(mut last) = LAST_PROGRESS.lock() {
        *last = None;
    }
}

/// Push kitty keyboard flag 1 (disambiguate escape codes) for the TUI. Call
/// after entering the alternate screen: each screen has its own stack.
pub fn keyboard_push() {
    if caps().keyboard && !KEYBOARD_PUSHED.swap(true, Ordering::AcqRel) {
        send(b"\x1b[>1u");
    }
}

/// Pop what `keyboard_push` pushed. Call before leaving the alternate screen,
/// and before handing the terminal to `sudo` or any other child.
pub fn keyboard_pop() {
    if KEYBOARD_PUSHED.swap(false, Ordering::AcqRel) {
        write_now(b"\x1b[<u");
    }
}

/// `send`, minus the freeze: the restore sequences themselves must still go
/// out after [`FROZEN`] is set.
fn write_now(bytes: &[u8]) {
    let mut err = std::io::stderr().lock();
    let _ = err.write_all(bytes);
    let _ = err.flush();
}

/// Undo every mode this module set (skill §2.3 order: keyboard, then
/// progress). Safe to run any number of times, from any exit path.
pub fn restore() {
    keyboard_pop();
    taskbar_clear();
}

/// What became of a copy request.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Copied {
    /// Sent; the terminal gives no acknowledgement, so the caller confirms.
    Sent { bytes: usize },
    /// Over [`CLIPBOARD_MAX`]; nothing was sent.
    TooLarge { bytes: usize },
    /// Gate closed or `-clipboard`; nothing was sent.
    Unavailable,
}

/// Write `text` to the system clipboard with OSC 52. Works over SSH and
/// through tmux with `set-clipboard on` (it is sent unwrapped).
pub fn copy(text: &str) -> Copied {
    if !caps().clipboard {
        return Copied::Unavailable;
    }
    if text.len() > CLIPBOARD_MAX {
        return Copied::TooLarge { bytes: text.len() };
    }
    let mut seq = String::with_capacity(text.len() / 3 * 4 + 16);
    seq.push_str("\x1b]52;c;");
    base64_into(text.as_bytes(), &mut seq);
    seq.push_str("\x1b\\");
    send(seq.as_bytes());
    Copied::Sent { bytes: text.len() }
}

/// Standard (RFC 4648 §4) base64 with padding. Twenty lines here rather than
/// a dependency for the one place preflight encodes anything.
fn base64_into(input: &[u8], out: &mut String) {
    const ALPHABET: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    for chunk in input.chunks(3) {
        let b = [
            chunk[0],
            *chunk.get(1).unwrap_or(&0),
            *chunk.get(2).unwrap_or(&0),
        ];
        let n = (u32::from(b[0]) << 16) | (u32::from(b[1]) << 8) | u32::from(b[2]);
        let sextet = |shift: u32| char::from(ALPHABET[((n >> shift) & 0x3f) as usize]);
        out.push(sextet(18));
        out.push(sextet(12));
        out.push(if chunk.len() > 1 { sextet(6) } else { '=' });
        out.push(if chunk.len() > 2 { sextet(0) } else { '=' });
    }
}

/// Restore the terminal on SIGINT, SIGTERM and SIGHUP, then die of the same
/// signal so the exit status is the one the shell expects (128 + N).
///
/// Without this, Ctrl-C during the live bar (or `kill` of a `--tui` run)
/// leaves a progress bar stuck in the tab, the kitty flags pushed, and in the
/// TUI's case raw mode on.
///
/// `quiesce` stops whatever draws (the caller's drawer thread) so nothing is
/// written after the restore; `teardown` is the caller's own restore (the
/// alternate screen, raw mode), run after this module's, in skill §2.3 order.
///
/// Call before [`init`]: the probe it runs puts the terminal in raw mode,
/// and a signal arriving then must find the handler in place. `attended` is
/// the same value `init` gets; the handler is installed exactly when the
/// gate lets `init` probe.
pub fn install_signal_handlers(attended: bool, quiesce: fn(), teardown: fn()) {
    use signal_hook::consts::{SIGHUP, SIGINT, SIGTERM};
    if gate(attended, env("TERM").as_deref()).is_err() {
        // Nothing of ours to undo, and default signal behaviour is unchanged.
        return;
    }
    let Ok(mut signals) = signal_hook::iterator::Signals::new([SIGINT, SIGTERM, SIGHUP]) else {
        return;
    };
    let _ = std::thread::Builder::new()
        .name("preflight-signals".into())
        .spawn(move || {
            if let Some(sig) = signals.forever().next() {
                // Mid-probe the terminal is raw; put it back before anything.
                restore_probe_termios();
                quiesce();
                FROZEN.store(true, Ordering::Release);
                restore();
                teardown();
                let _ = signal_hook::low_level::emulate_default_handler(sig);
                // Only reached if the default action is to ignore the signal.
                std::process::exit(128 + sig);
            }
        });
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn overrides_parse_layer_and_reject() {
        let o = Overrides::parse("-all,+progress").unwrap();
        assert_eq!(o.get(Protocol::Progress), Some(true));
        assert_eq!(o.get(Protocol::Keyboard), Some(false));
        let o = Overrides::parse("keyboard, -clipboard,").unwrap();
        assert_eq!(o.get(Protocol::Keyboard), Some(true));
        assert_eq!(o.get(Protocol::Clipboard), Some(false));
        assert_eq!(o.get(Protocol::Progress), None);
        assert!(Overrides::parse("+images").is_err());
        assert_eq!(Overrides::parse("").unwrap(), Overrides::default());

        // The flag wins over the variable, item by item.
        let env = Overrides::parse("-all").unwrap();
        let flag = Overrides::parse("+progress").unwrap();
        let both = env.under(flag);
        assert_eq!(both.get(Protocol::Progress), Some(true));
        assert_eq!(both.get(Protocol::Clipboard), Some(false));
    }

    #[test]
    fn gate_closes_for_unattended_dumb_and_console() {
        assert!(gate(false, Some("xterm-256color")).is_err());
        assert!(gate(true, None).is_err());
        assert!(gate(true, Some("dumb")).is_err());
        assert!(gate(true, Some("linux")).is_err());
        assert!(gate(true, Some("xterm-256color")).is_ok());
    }

    #[test]
    fn replies_parse_split_interleaved_and_fenced() {
        let r = parse_replies(b"\x1b[?1u\x1bP>|WezTerm 20250210-1-ab\x1b\\\x1b[?62;4;52c");
        assert_eq!(
            r,
            Reply {
                kitty_keyboard: true,
                xtversion: Some("WezTerm 20250210-1-ab".into()),
                da1: true,
            }
        );
        // Only DA1: nothing else supported.
        let r = parse_replies(b"\x1b[?6c");
        assert!(r.da1 && !r.kitty_keyboard && r.xtversion.is_none());
        // Split mid-reply: no fence yet, and no false positive.
        let r = parse_replies(b"\x1bP>|kitty(0.4");
        assert_eq!(r, Reply::default());
        // A stray keypress before the replies is skipped.
        let r = parse_replies(b"j\x1bP>|kitty(0.39.0)\x1b\\\x1b[?62c");
        assert_eq!(r.xtversion.as_deref(), Some("kitty(0.39.0)"));
        // A truncated buffer ending in ESC must not index out of bounds.
        assert_eq!(parse_replies(b"\x1b"), Reply::default());
    }

    #[test]
    fn typed_bytes_are_kept_apart_from_replies() {
        let (r, typed) = split_replies(b"q\x1b[?1uj\x1bP>|WezTerm 1\x1b\\\x1b[A\x1b[?62;4c\x03");
        assert!(r.da1 && r.kitty_keyboard);
        assert_eq!(r.xtversion.as_deref(), Some("WezTerm 1"));
        assert_eq!(typed, b"qj\x1b[A\x03");
        // A trailing lone ESC is the Esc key; a cut-off reply is neither.
        assert_eq!(split_replies(b"\x1b").1, b"\x1b");
        assert_eq!(split_replies(b"x\x1b[?6").1, b"x");
        assert_eq!(split_replies(b"x\x1bP>|kit").1, b"x");
    }

    #[test]
    fn version_parsing() {
        assert_eq!(
            wezterm_date("20240203-110809-5046fc22"),
            Some(ymd(2024, 2, 3))
        );
        assert_eq!(
            wezterm_date("0-unstable-2026-03-31"),
            Some(ymd(2026, 3, 31))
        );
        assert_eq!(wezterm_date("nightly"), None);
        assert_eq!(semver("0.39.2"), Some((0, 39, 2)));
        assert_eq!(semver("3.6"), Some((3, 6, 0)));
        assert_eq!(semver("x"), None);
    }

    fn term(program: &str, version: &str, xt: &str) -> Terminal {
        Terminal {
            term: Some("xterm-256color".into()),
            term_program: (!program.is_empty()).then(|| program.into()),
            term_program_version: (!version.is_empty()).then(|| version.into()),
            xtversion: (!xt.is_empty()).then(|| xt.into()),
            ..Terminal::default()
        }
    }

    #[test]
    fn progress_allow_list() {
        // Assumes the test runner is not itself inside Windows Terminal or
        // ConEmu, which would short-circuit every case to Ok.
        if env("WT_SESSION").is_some() || env("ConEmuPID").is_some() {
            return;
        }
        assert!(progress_terminal(&term("WezTerm", "20240203-110809-5046fc22", "")).is_err());
        assert_eq!(
            progress_terminal(&term("WezTerm", "0-unstable-2026-03-31", "")),
            Ok("WezTerm")
        );
        assert_eq!(
            progress_terminal(&term("", "", "WezTerm 20250301-000000-abc")),
            Ok("WezTerm")
        );
        assert_eq!(progress_terminal(&term("ghostty", "", "")), Ok("Ghostty"));
        assert_eq!(
            progress_terminal(&term("", "", "kitty(0.39.0)")),
            Ok("kitty")
        );
        assert!(progress_terminal(&term("", "", "kitty(0.38.1)")).is_err());
        assert!(progress_terminal(&term("iTerm.app", "3.5.4", "")).is_err());
        assert_eq!(
            progress_terminal(&term("iTerm.app", "3.6.0", "")),
            Ok("iTerm2")
        );
        assert!(progress_terminal(&term("Orca", "", "")).is_err());
        assert!(progress_terminal(&term("", "", "")).is_err());

        let mut muxed = term("ghostty", "", "");
        muxed.multiplexer = Some("tmux");
        assert!(progress_terminal(&muxed).is_err());
    }

    #[test]
    fn base64_matches_rfc4648_vectors() {
        for (input, want) in [
            ("", ""),
            ("f", "Zg=="),
            ("fo", "Zm8="),
            ("foo", "Zm9v"),
            ("foob", "Zm9vYg=="),
            ("fooba", "Zm9vYmE="),
            ("foobar", "Zm9vYmFy"),
        ] {
            let mut s = String::new();
            base64_into(input.as_bytes(), &mut s);
            assert_eq!(s, want, "input {input:?}");
        }
    }

    #[test]
    fn uninitialised_caps_send_nothing() {
        // `caps()` before `init` is all-off, so these must be no-ops; under
        // `cargo test` stderr may be a TTY, which is exactly why this matters.
        assert_eq!(copy("x"), Copied::Unavailable);
        taskbar(Taskbar::Normal(50));
        assert!(!PROGRESS_SHOWN.load(Ordering::Acquire));
    }
}
