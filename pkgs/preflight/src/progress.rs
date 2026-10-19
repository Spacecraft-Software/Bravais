// SPDX-License-Identifier: GPL-3.0-or-later
//
// Live progress on stderr: a spinner for the steps that run silently, and a
// watcher that turns the detached Flatpak update's log into a progress bar.
//
// Everything here draws only when `Out::live` is set -- a human at a terminal,
// not an agent, not CI, not a pipe (CLI Standard §5; Agentic CLI §4). Every
// other caller gets exactly the output it got before: the step lines and, with
// `--json`, one payload on stdout. A spinner in a log file is a megabyte of
// carriage returns, and in an agent's context it is noise it pays for.
//
// Why parse Flatpak's log rather than ask Flatpak: the update runs detached
// in its own session (see `steps::flatpak_start`), so its only output channel
// is the log. With stdout not a terminal, Flatpak's CLI drops its redrawn
// table and prints plain lines instead (`flatpak-cli-transaction.c`,
// `progress_changed_cb`): `Updating 2/5…` when an operation starts, then
// `Updating 2/5… ████▌      23%  1.2 MB/s  00:30` every update interval.
// Older releases wrote the same text separated by `\r`, so both separators
// are accepted. Those two shapes are all this module reads.

use std::fs::File;
use std::io::{IsTerminal, Read, Seek, SeekFrom, Write};
use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::{Duration, Instant};

use serde::Serialize;

use crate::output::Out;

/// Redraw interval. Fast enough to read as motion, slow enough that the
/// redraw itself is free next to the work it decorates.
const TICK: Duration = Duration::from_millis(100);

/// How often the Flatpak log is re-read while watching. Flatpak itself
/// reports at most every 300 ms, so polling faster would only redraw the
/// same numbers.
const LOG_POLL: Duration = Duration::from_millis(500);

/// Polling interval when nobody is watching (an agent's `flatpak watch`):
/// nothing is drawn, so the only cost worth saving is wakeups.
const QUIET_POLL: Duration = Duration::from_secs(2);

/// Bytes read from the end of the log per poll. A three-hour update writes
/// tens of thousands of progress lines; only the last few matter.
const TAIL_BYTES: u64 = 16 * 1024;

const BAR_WIDTH: usize = 24;

const UNICODE_FRAMES: &[&str] = &["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
const ASCII_FRAMES: &[&str] = &["|", "/", "-", "\\"];

/// Whether this run may draw live progress, and with which glyphs.
///
/// Called once from `Out::resolve`. Both streams must be terminals: stderr
/// is where the drawing goes, and a redirected stdout means a script is
/// collecting the result.
pub fn detect(human: bool, agent: bool) -> (bool, bool) {
    let live = human
        && !agent
        && std::io::stderr().is_terminal()
        && std::io::stdout().is_terminal()
        && std::env::var("TERM").as_deref() != Ok("dumb");
    // The Linux console font has no braille and no partial blocks, and a
    // non-UTF-8 locale would print them as mojibake. A rescue TTY is exactly
    // where a rebuild is run when the desktop is broken, so it has to work.
    let utf8 = ["LC_ALL", "LC_CTYPE", "LANG"]
        .iter()
        .find_map(|v| std::env::var(v).ok().filter(|s| !s.is_empty()))
        .is_some_and(|l| {
            let l = l.to_ascii_lowercase();
            l.contains("utf-8") || l.contains("utf8")
        });
    let ascii = !utf8 || std::env::var("TERM").as_deref() == Ok("linux");
    (live, ascii)
}

fn frame(out: Out, i: usize) -> &'static str {
    let frames = if out.ascii {
        ASCII_FRAMES
    } else {
        UNICODE_FRAMES
    };
    frames[i % frames.len()]
}

fn columns() -> usize {
    rustix::termios::tcgetwinsize(std::io::stderr())
        .ok()
        .map(|w| usize::from(w.ws_col))
        .filter(|&c| c > 0)
        .unwrap_or(80)
}

/// Replace the current stderr line with `text`, cut to the terminal width.
/// Cutting matters: a line that wraps can no longer be erased with `\r`, and
/// the spinner then scrolls the screen instead of turning in place.
fn draw(text: &str) {
    let width = columns().saturating_sub(1);
    let cut: String = text.chars().take(width).collect();
    let mut err = std::io::stderr().lock();
    let _ = write!(err, "\r\x1b[2K{cut}");
    let _ = err.flush();
}

fn clear() {
    let mut err = std::io::stderr().lock();
    let _ = write!(err, "\r\x1b[2K");
    let _ = err.flush();
}

/// A plain line for the human at the terminal, shown only in live mode. Not
/// `Out::say`: these are instructions about the display, not step results,
/// and they must not reach an agent's diagnostic stream.
pub fn note(out: Out, msg: &str) {
    if out.live {
        let mut err = std::io::stderr().lock();
        let _ = writeln!(err, "{msg}");
    }
}

/// `1m05s` / `12s` -- compact, because it shares a line with a bar.
pub fn elapsed(d: Duration) -> String {
    let s = d.as_secs();
    if s >= 3600 {
        format!("{}h{:02}m", s / 3600, (s % 3600) / 60)
    } else if s >= 60 {
        format!("{}m{:02}s", s / 60, s % 60)
    } else {
        format!("{s}s")
    }
}

/// Run `f` with a spinner turning beside `label` until it returns.
///
/// For steps that capture their child's output and are therefore silent
/// (the disk accounting, the Antigravity and mcpctl probes). Never wrap a
/// step that prints -- its lines would be overwritten -- and never one that
/// streams a child's output (`nixos-rebuild` draws its own progress).
///
/// `f` runs on the calling thread; only the drawing is on a scoped thread,
/// so `f` needs no `Send` bound and nothing outlives the call.
pub fn spin<T>(out: Out, label: &str, f: impl FnOnce() -> T) -> T {
    if !out.live {
        return f();
    }
    let done = AtomicBool::new(false);
    std::thread::scope(|s| {
        let drawer = s.spawn(|| {
            let start = Instant::now();
            let mut i = 0;
            while !done.load(Ordering::Relaxed) {
                draw(&format!(
                    "{} {label}  {}",
                    frame(out, i),
                    elapsed(start.elapsed())
                ));
                i += 1;
                std::thread::park_timeout(TICK);
            }
            clear();
        });
        let v = f();
        done.store(true, Ordering::Relaxed);
        drawer.thread().unpark();
        let _ = drawer.join();
        v
    })
}

/// What the Flatpak log says, as of its last line.
#[derive(Debug, Default, Clone, PartialEq, Eq, Serialize)]
pub struct FlatpakProgress {
    /// The operation in progress, 1-based, and how many there are. Both
    /// absent when there is a single operation (`Updating…`) or none yet.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub op: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ops: Option<u32>,
    /// The current operation's download, 0-100.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub op_percent: Option<u8>,
    /// The whole transaction, 0-100, counting every operation as an equal
    /// share. Flatpak reports no transaction total, and a byte-weighted one
    /// would need the sizes it only prints in its terminal-only table.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub percent: Option<u8>,
    /// Flatpak's own rate and time-remaining text, e.g. `1.2 MB/s  00:30`.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub rate: Option<String>,
    /// The last non-empty log line, for when there is no progress yet
    /// (`Looking for updates…`) or the run ended with a message.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub line: Option<String>,
}

/// `2/5…` (or `2/5...`, or a bare `2/5`) as `(2, 5)`.
fn counter(line: &str) -> Option<(u32, u32)> {
    line.split_whitespace().find_map(|tok| {
        let tok = tok.trim_end_matches(['…', '.']);
        let (a, b) = tok.split_once('/')?;
        let (a, b) = (a.parse::<u32>().ok()?, b.parse::<u32>().ok()?);
        (b > 0 && (1..=b).contains(&a)).then_some((a, b))
    })
}

/// The `NN%` token and whatever follows it on the line (the rate).
fn percent(line: &str) -> Option<(u8, Option<String>)> {
    let mut rest = line;
    while let Some(i) = rest.find('%') {
        let head = &rest[..i];
        let digits = head.len() - head.trim_end_matches(|c: char| c.is_ascii_digit()).len();
        if digits > 0 {
            if let Ok(p) = head[head.len() - digits..].parse::<u8>() {
                if p <= 100 {
                    let tail = rest[i + 1..].trim();
                    let rate = (!tail.is_empty()).then(|| tail.to_owned());
                    return Some((p, rate));
                }
            }
        }
        rest = &rest[i + 1..];
    }
    None
}

/// Drop ANSI escape sequences. The plain-output path writes none, but a log
/// written by an older run under `script` or a pty would.
fn strip_ansi(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut chars = s.chars();
    while let Some(c) = chars.next() {
        if c == '\x1b' {
            // CSI: ESC [ params final-byte(@..~)
            if chars.next() == Some('[') {
                for c in chars.by_ref() {
                    if ('@'..='~').contains(&c) {
                        break;
                    }
                }
            }
        } else {
            out.push(c);
        }
    }
    out
}

/// Read the progress out of the tail of a Flatpak log.
pub fn parse(tail: &str) -> FlatpakProgress {
    let clean = strip_ansi(tail);
    let lines: Vec<&str> = clean
        .split(['\r', '\n'])
        .map(str::trim)
        .filter(|l| !l.is_empty())
        .collect();
    let mut p = FlatpakProgress {
        line: lines.last().map(|l| (*l).to_owned()),
        ..FlatpakProgress::default()
    };

    // Newest first: the first line with a percentage or a counter decides.
    // A counter line with no percentage is an operation that has just
    // started, so its download stands at zero -- not at the previous
    // operation's 100%.
    for line in lines.iter().rev() {
        let pct = percent(line);
        let ctr = counter(line);
        if pct.is_none() && ctr.is_none() {
            continue;
        }
        if let Some((a, b)) = ctr {
            p.op = Some(a);
            p.ops = Some(b);
        }
        match pct {
            Some((v, rate)) => {
                p.op_percent = Some(v);
                p.rate = rate;
            }
            None => p.op_percent = Some(0),
        }
        break;
    }

    p.percent = match (p.op, p.ops, p.op_percent) {
        (Some(a), Some(b), Some(v)) => {
            let done = (u64::from(a) - 1) * 100 + u64::from(v);
            u8::try_from(done / u64::from(b)).ok()
        }
        (None, None, v) => v,
        _ => None,
    };
    p
}

/// The last [`TAIL_BYTES`] of `path`, or `None` if it cannot be read.
pub fn read_tail(path: &Path) -> Option<String> {
    let mut f = File::open(path).ok()?;
    let len = f.metadata().ok()?.len();
    f.seek(SeekFrom::Start(len.saturating_sub(TAIL_BYTES)))
        .ok()?;
    let mut buf = Vec::new();
    f.read_to_end(&mut buf).ok()?;
    // Seeking can land inside a multi-byte character; lossy decoding turns
    // that one fragment into U+FFFD instead of discarding the whole tail.
    Some(String::from_utf8_lossy(&buf).into_owned())
}

fn bar(out: Out, pct: u8) -> String {
    let (full, empty) = if out.ascii {
        ('#', '-')
    } else {
        ('█', '░')
    };
    let n = usize::from(pct.min(100)) * BAR_WIDTH / 100;
    let mut s = String::with_capacity(BAR_WIDTH * 3);
    s.extend(std::iter::repeat_n(full, n));
    s.extend(std::iter::repeat_n(empty, BAR_WIDTH - n));
    s
}

/// One frame of the Flatpak display.
fn render(out: Out, tick: usize, prog: &FlatpakProgress, took: Duration) -> String {
    let spin = frame(out, tick);
    let took = elapsed(took);
    let Some(pct) = prog.percent else {
        let line = prog.line.as_deref().unwrap_or("starting…");
        return format!("{spin} flatpak: {line}  ({took})");
    };
    let ops = match (prog.op, prog.ops) {
        (Some(op), Some(of)) => format!(" {op}/{of}"),
        _ => String::new(),
    };
    let rate = prog
        .rate
        .as_deref()
        .map_or(String::new(), |r| format!("  {r}"));
    format!(
        "{spin} flatpak{ops}  {} {pct:>3}%{rate}  ({took})",
        bar(out, pct)
    )
}

/// Follow the log at `log` until `running()` returns false, drawing the
/// display when `out.live`. Returns the progress as of the last read.
///
/// Without `live` nothing is drawn and the log is polled slowly: that is the
/// shape an agent gets from `preflight flatpak watch`, a call that blocks
/// until the update ends and then reports.
pub fn watch_flatpak(out: Out, log: &Path, running: &mut dyn FnMut() -> bool) -> FlatpakProgress {
    let start = Instant::now();
    let mut last = FlatpakProgress::default();
    let mut next_read = Instant::now();
    let mut i = 0;
    while running() {
        if Instant::now() >= next_read {
            if let Some(tail) = read_tail(log) {
                last = parse(&tail);
            }
            next_read = Instant::now() + LOG_POLL;
        }
        if out.live {
            draw(&render(out, i, &last, start.elapsed()));
            i += 1;
            std::thread::sleep(TICK);
        } else {
            std::thread::sleep(QUIET_POLL);
        }
    }
    if out.live {
        clear();
    }
    // One last read: the closing lines (`Changes complete.`, or an error)
    // are written in the moment before the process exits.
    read_tail(log).map_or(last, |t| parse(&t))
}

/// PID of a running `flatpak update`, found by scanning `/proc`.
///
/// For `preflight flatpak status|watch`, which may run long after the
/// `preflight` (or Nushell `flatpak-update`) that started the update has
/// exited, so there is no child handle to ask. Matches on argv rather than
/// the process name: on NixOS the binary is `.flatpak-wrapped`, and the
/// always-on `flatpak-session-helper` / `-portal` / `-system-helper`
/// daemons share the prefix but never carry an `update` argument.
pub fn running_update() -> Option<u32> {
    let me = std::process::id();
    std::fs::read_dir("/proc").ok()?.flatten().find_map(|e| {
        let pid: u32 = e.file_name().to_str()?.parse().ok()?;
        if pid == me {
            return None;
        }
        // A zombie's cmdline is empty, so a finished update drops out here.
        let raw = std::fs::read(e.path().join("cmdline")).ok()?;
        let mut argv = raw.split(|&b| b == 0).filter(|a| !a.is_empty());
        let prog = argv.next()?;
        let base = prog.rsplit(|&b| b == b'/').next().unwrap_or(prog);
        let is_flatpak = base == b"flatpak" || base == b".flatpak-wrapped";
        (is_flatpak && argv.any(|a| a == b"update")).then_some(pid)
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_the_operation_and_its_download() {
        let log = "Looking for updates…\n\nUpdating 2/5…\nUpdating 2/5… ████▌                23%  1.2 MB/s  00:30\n";
        let p = parse(log);
        assert_eq!((p.op, p.ops, p.op_percent), (Some(2), Some(5), Some(23)));
        assert_eq!(p.rate.as_deref(), Some("1.2 MB/s  00:30"));
        // One finished operation plus 23% of the second, out of five.
        assert_eq!(p.percent, Some(24));
    }

    #[test]
    fn a_new_operation_starts_at_zero() {
        let log = "Updating 2/5… ████████████████████ 100%  1.2 MB/s\nUpdating 3/5…\n";
        let p = parse(log);
        assert_eq!(
            (p.op, p.op_percent, p.percent),
            (Some(3), Some(0), Some(40))
        );
        assert_eq!(p.rate, None);
    }

    #[test]
    fn carriage_return_separated_logs_are_read_too() {
        let log = "Updating 1/2…\rUpdating 1/2… ██   10%\rUpdating 1/2… ████  50%  3.0 MB/s  00:05";
        let p = parse(log);
        assert_eq!((p.op_percent, p.percent), (Some(50), Some(25)));
    }

    #[test]
    fn a_single_operation_has_no_counter() {
        let p = parse("Updating…\nUpdating… ████████       42%  800.0 kB/s  01:10\n");
        assert_eq!((p.op, p.ops, p.percent), (None, None, Some(42)));
    }

    #[test]
    fn no_progress_yet_keeps_the_last_line() {
        let p = parse("Looking for updates…\n");
        assert_eq!(p.percent, None);
        assert_eq!(p.line.as_deref(), Some("Looking for updates…"));
        assert_eq!(parse("Nothing to do.\n").percent, None);
    }

    #[test]
    fn ansi_sequences_do_not_confuse_the_parser() {
        let p = parse("Updating 1/1… \x1b[2m████\x1b[22m  77%");
        assert_eq!(p.op_percent, Some(77));
    }

    #[test]
    fn counters_must_be_in_range() {
        assert_eq!(counter("x 0/5…"), None);
        assert_eq!(counter("x 6/5…"), None);
        assert_eq!(counter("Updating 5/5..."), Some((5, 5)));
        assert_eq!(percent("150% nope"), None);
    }

    #[test]
    fn the_bar_is_a_fixed_width() {
        let out = Out::for_tests(true);
        assert_eq!(bar(out, 0), "-".repeat(BAR_WIDTH));
        assert_eq!(bar(out, 100), "#".repeat(BAR_WIDTH));
        assert_eq!(
            bar(out, 50).chars().filter(|&c| c == '#').count(),
            BAR_WIDTH / 2
        );
    }

    #[test]
    fn elapsed_is_compact() {
        assert_eq!(elapsed(Duration::from_secs(5)), "5s");
        assert_eq!(elapsed(Duration::from_secs(65)), "1m05s");
        assert_eq!(elapsed(Duration::from_secs(3700)), "1h01m");
    }
}
