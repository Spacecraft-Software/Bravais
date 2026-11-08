// SPDX-License-Identifier: GPL-3.0-or-later
//
// Persistent live display and full-screen TUI for `preflight`.
//
// Two surfaces share the same task-list model so the step schedule, ticks,
// progress percentages, and sub-step activity lines are defined once:
//
// 1. Persistent live status bar (default when `Out::live` is true and `--tui`
//    is not set): keeps a bottom status line alive across the entire rebuild
//    with the overall task progress bar (`████░░ 45% [5/11]`), current step
//    spinner, elapsed timer, and the latest sub-step activity (e.g. `building
//    .#ollama …` or nixos-rebuild's `[2/14 built, 12.4 MiB DL]`). When a
//    diagnostic or child output line arrives, the status bar is cleared with
//    `\r\x1b[2K`, the line is printed above it, and the bar immediately redraws
//    on the bottom line.
// 2. Full-screen ratatui TUI (`--tui` or `--format explore`): enters the
//    alternate screen buffer on stderr and renders:
//      - Top banner: Steelbore OS host, overall gauge, step counter, elapsed
//        timer, and an unmistakable alert banner whenever an authorization step
//        is waiting on a sudo password or fingerprint scan.
//      - Left / top task list (responsive to terminal width): every scheduled
//        step with its status icon (`✓` / `[OK]` done, `⠹` / `*` running,
//        `·` pending, `–` skipped, `✗` / `[!]` failed), duration, and detail.
//      - Main log & activity pane: live scrollable output from the running
//        step, sub-step progress (`building .#ollama …`, nix build phases,
//        Flatpak download progress), and preflight/postflight disk reports.
//      - Bottom keybinding bar: dual CUA + Vim navigation (`↑/↓` or `j/k`,
//        `PgUp/PgDn` or `Ctrl+B/Ctrl+F`, `Home/End` or `g/G`, `Tab` to switch
//        focus, `q`/`Esc`/`Ctrl+C` to abort).
//    When an authorization command (`sudo`, `gitway-add`) needs the real
//    terminal for a password prompt or PAM conversation, `suspend_for_interactive`
//    cleanly leaves the alternate screen and raw mode for the duration of that
//    command (or after `sudo -n true` fails) and resumes the TUI immediately
//    afterwards.

// Rust guideline compliant 2026-05-18

use std::collections::VecDeque;
use std::io::{BufReader, IsTerminal, Read, Write};
use std::process::{Command, ExitStatus, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};

use crossterm::event::{self, Event, KeyCode, KeyEventKind, KeyModifiers};
use crossterm::terminal::{
    disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen,
};
use crossterm::ExecutableCommand;
use ratatui::backend::CrosstermBackend;
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Gauge, List, ListItem, Paragraph, Wrap};
use ratatui::Terminal;

use crate::output::{Level, Out};
use crate::progress;
use crate::steps::{Options, Outcome};
use crate::term;

/// Redraw cadence for the persistent status bar and TUI event loop.
const UI_TICK: Duration = Duration::from_millis(100);

/// Maximum log lines retained in the TUI scrollback buffer.
const MAX_LOG_LINES: usize = 2000;

/// Status of one task in the rebuild schedule.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TaskStatus {
    Pending,
    Running,
    Done(Outcome),
}

/// One scheduled step in the rebuild checklist.
#[derive(Debug, Clone)]
pub struct TaskEntry {
    pub name: &'static str,
    pub status: TaskStatus,
    pub detail: Option<String>,
    pub started: Option<Instant>,
    pub elapsed: Option<Duration>,
}

/// Shared state between the rebuild runner thread and the UI drawer.
#[expect(
    clippy::struct_excessive_bools,
    reason = "UI state tracks independent toggles for scroll tailing, pane focus, suspension and abort"
)]
#[derive(Debug)]
struct State {
    out: Out,
    started: Instant,
    tick: usize,
    tasks: Vec<TaskEntry>,
    current_step: Option<&'static str>,
    activity: Option<String>,
    sub_progress: Option<u8>,
    auth_waiting: Option<String>,
    logs: VecDeque<String>,
    scroll: usize,
    follow_tail: bool,
    selected_task: usize,
    focus_tasks: bool,
    suspended: bool,
    abort_requested: bool,
}

static ACTIVE: AtomicBool = AtomicBool::new(false);
/// The alternate screen and raw mode are on (the `--tui` view, not suspended).
static TUI_ON: AtomicBool = AtomicBool::new(false);
static STOP_DRAWER: AtomicBool = AtomicBool::new(false);
static STATE: OnceLock<Mutex<Option<State>>> = OnceLock::new();

fn state_lock() -> &'static Mutex<Option<State>> {
    STATE.get_or_init(|| Mutex::new(None))
}

/// Guard that stops the background UI drawer and restores the terminal on drop.
#[derive(Debug)]
pub struct Session {
    drawer: Option<std::thread::JoinHandle<()>>,
    tui: bool,
}

impl Drop for Session {
    fn drop(&mut self) {
        STOP_DRAWER.store(true, Ordering::Release);
        if let Some(h) = self.drawer.take() {
            h.thread().unpark();
            let _ = h.join();
        }
        ACTIVE.store(false, Ordering::Release);
        let failed = state_lock().lock().ok().and_then(|g| {
            g.as_ref().map(|st| {
                let (_, _, pct) = overall_counts(st);
                st.tasks
                    .iter()
                    .any(|t| t.status == TaskStatus::Done(Outcome::Failed))
                    .then_some(pct)
            })
        });
        if let Some(Some(pct)) = failed {
            // Show red for a moment before clearing: the indicator must not
            // outlive the run (skill §2.3), but a failure should be seen.
            term::taskbar(term::Taskbar::Error(pct));
            std::thread::sleep(Duration::from_millis(800));
        }
        term::taskbar_clear();
        if self.tui {
            restore_terminal();
        } else {
            progress::clear();
        }
        if let Ok(mut guard) = state_lock().lock() {
            *guard = None;
        }
    }
}

/// Whether the persistent live bar or full-screen TUI is currently active.
pub fn active() -> bool {
    ACTIVE.load(Ordering::Acquire)
}

/// Build the initial task schedule from `opts` so the user sees all planned
/// steps upfront with a real completion ratio.
fn planned_tasks(opts: Options<'_>) -> Vec<TaskEntry> {
    let mut names: Vec<&'static str> = Vec::with_capacity(14);
    if opts.sync || !opts.no_update {
        names.push("gitway-add");
    }
    names.push("git-sync");
    names.push("flake-update");
    if !opts.no_update && !opts.skills_only {
        names.push("antigravity");
    }
    names.push("garbage-collect");
    if !opts.no_gc && !opts.dry && !opts.skills_only {
        names.push("journal-vacuum");
    }
    if opts.update_vendored {
        names.push("update-vendored");
    }
    names.push("nixos-rebuild");
    if !opts.dry && !opts.skills_only {
        names.push("mirror-etc-nixos");
        names.push("mcpctl");
    }
    names.push("deps-commit");
    if opts.check_appimages && !opts.skills_only {
        names.push("appimage-check");
        if opts.update_appimages && !opts.dry {
            names.push("appimage-update");
        }
    }
    if opts.update_flatpaks {
        names.push("flatpak-update");
    }
    names
        .into_iter()
        .map(|name| TaskEntry {
            name,
            status: TaskStatus::Pending,
            detail: None,
            started: None,
            elapsed: None,
        })
        .collect()
}

/// Start the UI session for a rebuild run. Returns `None` when the run is
/// neither live nor TUI (e.g. `--json`, piped, CI, or `--accessible`).
pub fn start(out: Out, opts: Options<'_>) -> Option<Session> {
    if !out.live && !out.tui {
        return None;
    }

    let st = State {
        out,
        started: Instant::now(),
        tick: 0,
        tasks: planned_tasks(opts),
        current_step: None,
        activity: None,
        sub_progress: None,
        auth_waiting: None,
        logs: VecDeque::with_capacity(256),
        scroll: 0,
        follow_tail: true,
        selected_task: 0,
        focus_tasks: true,
        suspended: false,
        abort_requested: false,
    };

    if let Ok(mut guard) = state_lock().lock() {
        *guard = Some(st);
    }

    STOP_DRAWER.store(false, Ordering::Release);
    ACTIVE.store(true, Ordering::Release);

    let tui = out.tui;
    install_panic_hook();
    if tui {
        enter_terminal();
    }

    let drawer = std::thread::Builder::new()
        .name("preflight-ui".into())
        .spawn(move || {
            if tui {
                tui_loop();
            } else {
                bar_loop();
            }
        })
        .ok();

    Some(Session { drawer, tui })
}

/// Restore before the panic message prints, so it lands on a sane terminal:
/// keyboard flags popped, progress cleared, and -- in the TUI -- the
/// alternate screen left.
fn install_panic_hook() {
    static HOOK_ONCE: OnceLock<()> = OnceLock::new();
    HOOK_ONCE.get_or_init(|| {
        let prev = std::panic::take_hook();
        std::panic::set_hook(Box::new(move |info| {
            term::restore();
            if TUI_ON.load(Ordering::Acquire) {
                restore_terminal();
            }
            prev(info);
        }));
    });
}

/// Raw mode, then the alternate screen, then the kitty keyboard flags -- the
/// flags last because each screen keeps its own stack (keyboard rule 1).
fn enter_terminal() {
    let _ = enable_raw_mode();
    let _ = std::io::stderr().execute(EnterAlternateScreen);
    term::keyboard_push();
    TUI_ON.store(true, Ordering::Release);
}

/// The reverse of [`enter_terminal`]: pop the flags while still on the
/// alternate screen, then leave it, then leave raw mode.
fn restore_terminal() {
    TUI_ON.store(false, Ordering::Release);
    term::keyboard_pop();
    let _ = std::io::stderr().execute(LeaveAlternateScreen);
    let _ = disable_raw_mode();
}

/// First half of the SIGINT / SIGTERM / SIGHUP teardown: stop the drawer and
/// give it one tick to leave its loop, so it cannot draw a frame (or re-send
/// the progress indicator) after the terminal has been restored.
pub fn quiesce_for_signal() {
    if active() {
        STOP_DRAWER.store(true, Ordering::Release);
        std::thread::sleep(UI_TICK + Duration::from_millis(50));
    }
}

/// Second half, run by `term`'s signal thread after it has popped the
/// keyboard flags and cleared the progress indicator.
pub fn restore_after_signal() {
    if TUI_ON.load(Ordering::Acquire) {
        restore_terminal();
        // The drawer's `Terminal` may not have been dropped (and so not have
        // shown the cursor) before the process dies of the signal.
        let _ = std::io::stderr().execute(crossterm::cursor::Show);
    } else if active() {
        progress::clear();
    }
}

/// Mark `name` as the currently running step. Inserts it into the task list if
/// it was not part of the static schedule (e.g. a dynamic AI tool step or
/// on-demand `disk-reclaim`).
pub fn begin_step(out: Out, name: &'static str, detail: Option<&str>) {
    out.announce(&match detail {
        Some(d) => format!("starting {name} ({d}) …"),
        None => format!("starting {name} …"),
    });
    if !active() {
        return;
    }
    if let Ok(mut guard) = state_lock().lock() {
        if let Some(st) = guard.as_mut() {
            let now = Instant::now();
            let idx = if let Some(i) = st.tasks.iter().position(|t| t.name == name) {
                st.tasks[i].status = TaskStatus::Running;
                st.tasks[i].started = Some(now);
                if let Some(d) = detail {
                    st.tasks[i].detail = Some(d.to_owned());
                }
                i
            } else {
                let pos = st
                    .current_step
                    .and_then(|cur| st.tasks.iter().position(|t| t.name == cur))
                    .map_or(st.tasks.len(), |i| i + 1);
                st.tasks.insert(
                    pos,
                    TaskEntry {
                        name,
                        status: TaskStatus::Running,
                        detail: detail.map(ToOwned::to_owned),
                        started: Some(now),
                        elapsed: None,
                    },
                );
                pos
            };
            st.current_step = Some(name);
            st.activity = detail.map(ToOwned::to_owned);
            st.sub_progress = None;
            if st.follow_tail {
                st.selected_task = idx;
            }
        }
    }
}

/// Record the completion of step `name` in the task list.
pub fn finish_step(name: &'static str, outcome: Outcome, detail: Option<&str>) {
    if !active() {
        return;
    }
    if let Ok(mut guard) = state_lock().lock() {
        if let Some(st) = guard.as_mut() {
            let canonical = match name {
                "mcpctl-deploy" | "mcpctl-drift" => "mcpctl",
                other => other,
            };
            if let Some(t) = st
                .tasks
                .iter_mut()
                .find(|t| t.name == name || t.name == canonical)
            {
                t.name = name;
                t.status = TaskStatus::Done(outcome);
                t.elapsed = t.started.map(|s| s.elapsed());
                if let Some(d) = detail {
                    t.detail = Some(d.to_owned());
                }
            } else {
                st.tasks.push(TaskEntry {
                    name,
                    status: TaskStatus::Done(outcome),
                    detail: detail.map(ToOwned::to_owned),
                    started: None,
                    elapsed: None,
                });
            }
            if st.current_step == Some(name) || st.current_step == Some(canonical) {
                st.current_step = None;
                st.activity = None;
                st.sub_progress = None;
            }
        }
    }
}

/// Run `f` while displaying `label` as the current sub-step activity.
pub fn with_label<T>(label: &str, f: impl FnOnce() -> T) -> T {
    set_progress(None, Some(label.to_owned()));
    let v = f();
    set_progress(None, None);
    v
}

/// Update the sub-step percentage and/or activity text on the live display.
pub fn set_progress(pct: Option<u8>, activity: Option<String>) {
    if !active() {
        return;
    }
    if let Ok(mut guard) = state_lock().lock() {
        if let Some(st) = guard.as_mut() {
            st.sub_progress = pct;
            st.activity = activity;
        }
    }
}

/// Set or clear the authorization-waiting banner (`notify::AuthWatch`).
pub fn set_auth_waiting(msg: Option<String>) {
    if !active() {
        return;
    }
    if let Ok(mut guard) = state_lock().lock() {
        if let Some(st) = guard.as_mut() {
            st.auth_waiting = msg;
        }
    }
}

/// Route a diagnostic line from `Out::say` through the active display so it
/// never collides with the bottom status bar or corrupts the TUI grid.
pub fn emit(_level: Level, colored: &str, plain: &str) -> bool {
    if !active() {
        return false;
    }
    let Ok(mut guard) = state_lock().lock() else {
        return false;
    };
    let Some(st) = guard.as_mut() else {
        return false;
    };
    if st.out.tui {
        push_log(st, plain);
        if st.suspended {
            let mut err = std::io::stderr().lock();
            let _ = writeln!(err, "{colored}");
        }
        true
    } else {
        let mut err = std::io::stderr().lock();
        let _ = writeln!(err, "\r\x1b[2K{colored}");
        let bar = render_bar_line(st);
        drop(guard);
        progress::draw(&bar);
        true
    }
}

/// Route a multi-line text block (such as the disk report) through the active
/// display.
pub fn emit_block(text: &str) -> bool {
    if !active() {
        return false;
    }
    let Ok(mut guard) = state_lock().lock() else {
        return false;
    };
    let Some(st) = guard.as_mut() else {
        return false;
    };
    if st.out.tui {
        for line in text.lines() {
            push_log(st, line);
        }
        if st.suspended {
            let mut err = std::io::stderr().lock();
            let _ = write!(err, "{text}");
        }
        true
    } else {
        let mut err = std::io::stderr().lock();
        let _ = write!(err, "\r\x1b[2K{text}");
        let bar = render_bar_line(st);
        drop(guard);
        progress::draw(&bar);
        true
    }
}

fn push_log(st: &mut State, line: &str) {
    let clean = strip_osc_and_csi(line);
    if clean.trim().is_empty() && st.logs.back().is_some_and(String::is_empty) {
        return;
    }
    if st.logs.len() >= MAX_LOG_LINES {
        st.logs.pop_front();
    }
    st.logs.push_back(clean);
    if st.follow_tail {
        st.scroll = st.logs.len();
    }
}

/// Temporarily suspend the live bar or TUI while an interactive command
/// (`sudo`, `gitway-add`) talks directly to the user's terminal.
pub fn suspend_for<T>(f: impl FnOnce() -> T) -> T {
    if !active() {
        return f();
    }
    let is_tui = state_lock()
        .lock()
        .ok()
        .and_then(|mut g| {
            let st = g.as_mut()?;
            st.suspended = true;
            Some(st.out.tui)
        })
        .unwrap_or(false);

    if is_tui {
        restore_terminal();
    } else {
        progress::clear();
    }

    let out = f();

    if is_tui {
        enter_terminal();
    }
    if let Ok(mut g) = state_lock().lock() {
        if let Some(st) = g.as_mut() {
            st.suspended = false;
        }
    }
    out
}

/// Run a child command while keeping the persistent status bar or TUI alive:
///
/// - When `interactive_auth` is true (`sudo`, `gitway-add`) and credentials are
///   not already cached (`sudo -n true` fails), we suspend the TUI / clear the
///   status bar while `sudo -v` (or the command itself) authenticates on the
///   real terminal, with `AuthWatch` firing notifications if it waits on the
///   user.
/// - Once authenticated (or for any non-auth command), when the UI is active we
///   pipe the child's stdout and stderr line-by-line into the log pane / above
///   the persistent status bar, extracting live sub-step progress (`building
///   .#ollama …`, nix `[3/15 built]`, download rates) onto the activity bar.
pub fn run_logged(
    cmd: &mut Command,
    auth_label: Option<(&str, &str)>,
    notify_enabled: bool,
    limit: Option<Duration>,
) -> std::io::Result<ExitStatus> {
    if !active() {
        let _watch = auth_label
            .map(|(step, detail)| crate::notify::AuthWatch::start(step, detail, notify_enabled));
        return match limit {
            None => cmd.status(),
            Some(max) => wait_with_limit(cmd.spawn()?, max),
        };
    }

    // If this command requires interactive credentials (`sudo` or `gitway-add`),
    // ensure any terminal prompt has direct access to `/dev/tty`.
    if let Some((step, detail)) = auth_label {
        if step == "sudo" {
            if !sudo_cached() && std::io::stdin().is_terminal() {
                let auth_ok = suspend_for(|| {
                    let _watch = crate::notify::AuthWatch::start(step, detail, notify_enabled);
                    Command::new("sudo")
                        .arg("-v")
                        .status()
                        .is_ok_and(|s| s.success())
                });
                if !auth_ok {
                    // Fall through to let the command itself fail with its own status.
                }
            }
        } else {
            // Other privilege helpers and `gitway-add` use their own prompt
            // mechanisms. Run the actual command with the display suspended;
            // do not insert an extra authentication or timestamp refresh.
            return suspend_for(|| {
                let _watch = crate::notify::AuthWatch::start(step, detail, notify_enabled);
                match limit {
                    None => cmd.status(),
                    Some(max) => wait_with_limit(cmd.spawn()?, max),
                }
            });
        }
    }

    let _watch = auth_label
        .map(|(step, detail)| crate::notify::AuthWatch::start(step, detail, notify_enabled));

    cmd.stdout(Stdio::piped()).stderr(Stdio::piped());
    let mut child = cmd.spawn()?;
    let out_pipe = child.stdout.take();
    let err_pipe = child.stderr.take();

    std::thread::scope(|s| {
        if let Some(p) = out_pipe {
            s.spawn(move || forward_stream(p));
        }
        if let Some(p) = err_pipe {
            s.spawn(move || forward_stream(p));
        }
        match limit {
            None => child.wait(),
            Some(max) => wait_with_limit(child, max),
        }
    })
}

fn sudo_cached() -> bool {
    Command::new("sudo")
        .args(["-n", "true"])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .is_ok_and(|s| s.success())
}

fn wait_with_limit(mut child: std::process::Child, limit: Duration) -> std::io::Result<ExitStatus> {
    let start = Instant::now();
    loop {
        if let Some(status) = child.try_wait()? {
            return Ok(status);
        }
        if start.elapsed() >= limit {
            let _ = child.kill();
            return child.wait();
        }
        if abort_requested() {
            let _ = child.kill();
            return child.wait();
        }
        std::thread::sleep(Duration::from_millis(100));
    }
}

fn abort_requested() -> bool {
    state_lock()
        .lock()
        .ok()
        .and_then(|g| g.as_ref().map(|st| st.abort_requested))
        .unwrap_or(false)
}

/// Read lines (split on `\n` or `\r`) from a child stream, updating the live
/// activity indicator and printing non-ephemeral lines above the status bar
/// (or into the TUI log pane).
fn forward_stream(pipe: impl Read) {
    let mut reader = BufReader::new(pipe);
    let mut buf = Vec::with_capacity(256);
    loop {
        buf.clear();
        let mut byte = [0u8; 1];
        let mut ended_with_cr = false;
        loop {
            match reader.read(&mut byte) {
                Ok(0) => break,
                Ok(_) => {
                    if byte[0] == b'\n' {
                        break;
                    }
                    if byte[0] == b'\r' {
                        ended_with_cr = true;
                        break;
                    }
                    buf.push(byte[0]);
                }
                Err(ref e) if e.kind() == std::io::ErrorKind::Interrupted => {}
                Err(_) => break,
            }
        }
        if buf.is_empty() && !ended_with_cr {
            break;
        }
        let raw = String::from_utf8_lossy(&buf);
        let clean = strip_osc_and_csi(&raw);
        let trimmed = clean.trim();
        if trimmed.is_empty() {
            continue;
        }

        update_activity_from_line(trimmed);

        // Ephemeral carriage-return redraws update the activity bar without
        // flooding the scrollback log.
        if ended_with_cr {
            continue;
        }

        let Ok(mut guard) = state_lock().lock() else {
            continue;
        };
        let Some(st) = guard.as_mut() else {
            continue;
        };
        if st.out.tui {
            push_log(st, trimmed);
        } else if !st.suspended {
            let mut err = std::io::stderr().lock();
            let _ = writeln!(err, "\r\x1b[2K{raw}");
            let bar = render_bar_line(st);
            drop(guard);
            progress::draw(&bar);
        }
    }
}

fn update_activity_from_line(line: &str) {
    let pct = extract_fraction_percent(line);
    let Ok(mut guard) = state_lock().lock() else {
        return;
    };
    let Some(st) = guard.as_mut() else {
        return;
    };
    if let Some(p) = pct {
        st.sub_progress = Some(p);
    }
    let short: String = line.chars().take(72).collect();
    st.activity = Some(short);
}

/// Parse `[3/15 ...]` or `24%` from a child output line when present.
fn extract_fraction_percent(line: &str) -> Option<u8> {
    if let Some(open) = line.find('[') {
        let rest = &line[open + 1..];
        let token = rest.split([']', ' ', ',']).next()?;
        if let Some((a, b)) = token.split_once('/') {
            let done: u64 = a.parse().ok()?;
            let total: u64 = b.parse().ok()?;
            if total > 0 && done <= total {
                return u8::try_from((done * 100) / total).ok();
            }
        }
    }
    None
}

fn strip_osc_and_csi(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut chars = s.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '\x1b' {
            match chars.peek().copied() {
                Some('[') => {
                    let _ = chars.next();
                    for ch in chars.by_ref() {
                        if ('@'..='~').contains(&ch) {
                            break;
                        }
                    }
                }
                Some(']') => {
                    let _ = chars.next();
                    for ch in chars.by_ref() {
                        if ch == '\x07' {
                            break;
                        }
                    }
                }
                _ => {}
            }
        } else if c != '\r' {
            out.push(c);
        }
    }
    out
}

/// Overall task progress: `(done_count, total_count, percent_0_to_100)`.
fn overall_counts(st: &State) -> (usize, usize, u8) {
    let total = st.tasks.len().max(1);
    let done = st
        .tasks
        .iter()
        .filter(|t| matches!(t.status, TaskStatus::Done(_)))
        .count();
    let sub_share = usize::from(st.sub_progress.unwrap_or(0).min(100));
    let num = done * 100
        + if st.current_step.is_some() {
            sub_share
        } else {
            0
        };
    let pct = u8::try_from((num / total).min(100)).unwrap_or(100);
    (done, total, pct)
}

fn render_bar_line(st: &State) -> String {
    let spin = progress::spinner(st.out.ascii, st.tick);
    let (done, total, pct) = overall_counts(st);
    let bar = progress::bar_with(st.out.ascii, pct, 16);
    let took = progress::elapsed(st.started.elapsed());
    if let Some(ref auth) = st.auth_waiting {
        return format!("{spin} [{done}/{total}] {auth}  ({took})");
    }
    let step = st.current_step.unwrap_or("preflight");
    let step_elapsed = st
        .tasks
        .iter()
        .find(|t| Some(t.name) == st.current_step)
        .and_then(|t| t.started)
        .map_or_else(|| took.clone(), |s| progress::elapsed(s.elapsed()));
    match st.activity.as_deref() {
        Some(act) if !act.is_empty() && act != step => {
            format!(
                "{spin} {bar} {pct:>3}% [{done}/{total}] {step} ({step_elapsed}): {act}  [{took}]"
            )
        }
        _ => format!("{spin} {bar} {pct:>3}% [{done}/{total}] {step} ({step_elapsed})  [{took}]"),
    }
}

/// Mirror the overall gauge into the terminal's tab (OSC 9;4), shown as
/// paused while a password or fingerprint prompt waits on the user.
fn report_taskbar(st: &State) {
    let (_, _, pct) = overall_counts(st);
    term::taskbar(if st.auth_waiting.is_some() {
        term::Taskbar::Paused(pct)
    } else {
        term::Taskbar::Normal(pct)
    });
}

fn bar_loop() {
    while !STOP_DRAWER.load(Ordering::Acquire) {
        let line = state_lock().lock().ok().and_then(|mut g| {
            let st = g.as_mut()?;
            if st.suspended {
                return None;
            }
            st.tick = st.tick.wrapping_add(1);
            report_taskbar(st);
            Some(render_bar_line(st))
        });
        if let Some(l) = line {
            progress::draw(&l);
        }
        std::thread::park_timeout(UI_TICK);
    }
    progress::clear();
}

/// Steelbore Modern role-token palette for ratatui (`steelbore-color-palette`
/// §11.1, with `NO_COLOR` / mono fallback to 4-bit ANSI).
struct Palette {
    fg: Color,
    accent: Color,
    structure: Color,
    success: Color,
    error: Color,
    warning: Color,
    focus: Color,
}

impl Palette {
    fn for_out(out: Out) -> Self {
        if !out.color {
            return Self {
                fg: Color::Reset,
                accent: Color::Cyan,
                structure: Color::Blue,
                success: Color::Green,
                error: Color::Red,
                warning: Color::Yellow,
                focus: Color::Green,
            };
        }
        // Nearest 256-color indices matching output.rs and Steelbore Modern
        // role tokens on any terminal canvas.
        Self {
            fg: Color::Indexed(254),        // Platinum Mist
            accent: Color::Indexed(202),    // Plasma Orange
            structure: Color::Indexed(141), // Pulse Violet
            success: Color::Indexed(154),   // Acid Lime
            error: Color::Indexed(203),     // Mars Red
            warning: Color::Indexed(207),   // Plasma Magenta
            focus: Color::Indexed(154),     // Acid Lime (§18 focus indicator)
        }
    }
}

fn tui_loop() {
    let Ok(mut terminal) = Terminal::new(CrosstermBackend::new(std::io::stderr())) else {
        return;
    };
    let _ = terminal.clear();
    replay_typeahead();

    while !STOP_DRAWER.load(Ordering::Acquire) {
        let is_suspended = state_lock()
            .lock()
            .ok()
            .and_then(|g| g.as_ref().map(|s| s.suspended))
            .unwrap_or(false);
        if is_suspended {
            std::thread::park_timeout(UI_TICK);
            continue;
        }

        if event::poll(UI_TICK).unwrap_or(false) {
            if let Ok(Event::Key(key)) = event::read() {
                if key.kind == KeyEventKind::Press {
                    handle_key(key.code, key.modifiers);
                }
            }
        }

        if let Ok(mut guard) = state_lock().lock() {
            if let Some(st) = guard.as_mut() {
                st.tick = st.tick.wrapping_add(1);
                report_taskbar(st);
                let _ = terminal.draw(|f| draw_tui(f, st));
            }
        }
    }
}

/// Feed the keys typed while the startup probe owned the terminal to
/// [`handle_key`], so a `q` pressed in the first instant is not lost. The
/// probe ran before raw mode and the kitty flags, so these are legacy
/// encodings: plain bytes, control codes and the common `CSI` / `SS3` keys.
fn replay_typeahead() {
    for (code, mods) in legacy_keys(&term::take_typeahead()) {
        handle_key(code, mods);
    }
}

/// Decode legacy key bytes. Anything not recognised is skipped.
fn legacy_keys(bytes: &[u8]) -> Vec<(KeyCode, KeyModifiers)> {
    let mut keys = Vec::new();
    let mut i = 0;
    while i < bytes.len() {
        let b = bytes[i];
        i += 1;
        let key = match b {
            0x1b => match (bytes.get(i), bytes.get(i + 1), bytes.get(i + 2)) {
                (Some(b'[' | b'O'), Some(&f), _) if f.is_ascii_uppercase() => {
                    i += 2;
                    match f {
                        b'A' => Some(KeyCode::Up),
                        b'B' => Some(KeyCode::Down),
                        b'H' => Some(KeyCode::Home),
                        b'F' => Some(KeyCode::End),
                        _ => None,
                    }
                }
                // GNU Screen and the Linux console send Home and End as these.
                (Some(b'['), Some(&n @ (b'1' | b'4')), Some(b'~')) => {
                    i += 3;
                    Some(if n == b'1' {
                        KeyCode::Home
                    } else {
                        KeyCode::End
                    })
                }
                (Some(b'['), Some(&n @ (b'5' | b'6')), Some(b'~')) => {
                    i += 3;
                    Some(if n == b'5' {
                        KeyCode::PageUp
                    } else {
                        KeyCode::PageDown
                    })
                }
                (Some(b'['), ..) => {
                    // Some other CSI key: skip through its final byte.
                    i += 1;
                    while bytes.get(i).is_some_and(|c| !(0x40..=0x7e).contains(c)) {
                        i += 1;
                    }
                    i += 1;
                    None
                }
                // Alt+key in a terminal that sends it as ESC + key: one key
                // with ALT, as crossterm reports it live, never Esc (abort)
                // followed by the key.
                (Some(&c @ 0x20..=0x7e), ..) => {
                    i += 1;
                    keys.push((KeyCode::Char(char::from(c)), KeyModifiers::ALT));
                    None
                }
                _ => Some(KeyCode::Esc),
            },
            b'\t' => Some(KeyCode::Tab),
            b'\r' | b'\n' => Some(KeyCode::Enter),
            0x01..=0x1a => {
                keys.push((
                    KeyCode::Char(char::from(b'a' + b - 1)),
                    KeyModifiers::CONTROL,
                ));
                None
            }
            0x20..=0x7e => Some(KeyCode::Char(char::from(b))),
            _ => None,
        };
        if let Some(code) = key {
            keys.push((code, KeyModifiers::NONE));
        }
    }
    keys
}

fn handle_key(code: KeyCode, mods: KeyModifiers) {
    let Ok(mut guard) = state_lock().lock() else {
        return;
    };
    let Some(st) = guard.as_mut() else {
        return;
    };
    match code {
        KeyCode::Char('c') if mods.contains(KeyModifiers::CONTROL) => {
            st.abort_requested = true;
        }
        KeyCode::Char('q') | KeyCode::Esc => {
            st.abort_requested = true;
        }
        KeyCode::Tab => {
            st.focus_tasks = !st.focus_tasks;
        }
        KeyCode::Char('y') if !mods.contains(KeyModifiers::CONTROL) => copy_selection(st),
        KeyCode::Up | KeyCode::Char('k') => {
            if st.focus_tasks {
                st.selected_task = st.selected_task.saturating_sub(1);
            } else {
                st.follow_tail = false;
                st.scroll = st.scroll.saturating_sub(1);
            }
        }
        KeyCode::Down | KeyCode::Char('j') => {
            if st.focus_tasks {
                if st.selected_task + 1 < st.tasks.len() {
                    st.selected_task += 1;
                }
            } else if st.scroll < st.logs.len() {
                st.scroll += 1;
            } else {
                st.follow_tail = true;
            }
        }
        KeyCode::PageUp => {
            st.follow_tail = false;
            st.scroll = st.scroll.saturating_sub(10);
        }
        KeyCode::Char('b') if mods.contains(KeyModifiers::CONTROL) => {
            st.follow_tail = false;
            st.scroll = st.scroll.saturating_sub(10);
        }
        KeyCode::PageDown => {
            st.scroll = (st.scroll + 10).min(st.logs.len());
            if st.scroll >= st.logs.len() {
                st.follow_tail = true;
            }
        }
        KeyCode::Char('f') if mods.contains(KeyModifiers::CONTROL) => {
            st.scroll = (st.scroll + 10).min(st.logs.len());
            if st.scroll >= st.logs.len() {
                st.follow_tail = true;
            }
        }
        KeyCode::Home | KeyCode::Char('g') => {
            if st.focus_tasks {
                st.selected_task = 0;
            } else {
                st.follow_tail = false;
                st.scroll = 0;
            }
        }
        KeyCode::End | KeyCode::Char('G') => {
            if st.focus_tasks {
                st.selected_task = st.tasks.len().saturating_sub(1);
            } else {
                st.follow_tail = true;
                st.scroll = st.logs.len();
            }
        }
        _ => {}
    }
}

/// `y`: copy the selected task (Tasks focus) or the retained log (Output
/// focus) with OSC 52, and say in the log what happened -- the terminal never
/// acknowledges, so a user on one without OSC 52 must be told how to copy
/// by hand (references/clipboard.md rule 2).
fn copy_selection(st: &mut State) {
    let (what, text) = if st.focus_tasks {
        let Some(t) = st.tasks.get(st.selected_task) else {
            return;
        };
        let status = match t.status {
            TaskStatus::Pending => "pending",
            TaskStatus::Running => "running",
            TaskStatus::Done(Outcome::Ok) => "ok",
            TaskStatus::Done(Outcome::Skipped) => "skipped",
            TaskStatus::Done(Outcome::Failed) => "failed",
        };
        let line = match &t.detail {
            Some(d) => format!("{}: {status} ({d})", t.name),
            None => format!("{}: {status}", t.name),
        };
        (format!("task {}", t.name), line)
    } else {
        // Newest lines first into the budget, so an over-long log keeps the
        // end -- the part with the failure in it.
        let mut budget = term::CLIPBOARD_MAX;
        let mut kept: Vec<&str> = Vec::new();
        for l in st.logs.iter().rev() {
            let cost = l.len() + 1;
            if cost > budget {
                break;
            }
            budget -= cost;
            kept.push(l);
        }
        kept.reverse();
        let note = if kept.len() < st.logs.len() {
            format!("the last {} of {} log lines", kept.len(), st.logs.len())
        } else {
            format!("{} log lines", kept.len())
        };
        (note, kept.join("\n"))
    };
    let msg = match term::copy(&text) {
        term::Copied::Sent { bytes } => format!(
            "[INFO] copied {what} ({bytes} bytes) via OSC 52; if the clipboard is empty, this terminal lacks OSC 52 -- Shift+drag selects text by hand"
        ),
        term::Copied::TooLarge { bytes } => {
            format!("[WARN] {what} is {bytes} bytes, over the {} byte OSC 52 limit; not copied", term::CLIPBOARD_MAX)
        }
        term::Copied::Unavailable => {
            "[WARN] clipboard is off (--term-protocols / SPACECRAFT_TERM_PROTOCOLS); not copied".to_owned()
        }
    };
    push_log(st, &msg);
}

fn draw_tui(f: &mut ratatui::Frame<'_>, st: &State) {
    let pal = Palette::for_out(st.out);
    let area = f.area();

    let header_height = if st.auth_waiting.is_some() { 4 } else { 3 };
    let root = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(header_height),
            Constraint::Min(6),
            Constraint::Length(1),
        ])
        .split(area);

    draw_header(f, root[0], st, &pal);

    // Side-by-side task list + log pane on wide terminals (>= 90 cols), stacked
    // top-and-bottom on narrower terminals so both remain legible everywhere.
    let body = if root[1].width >= 90 {
        Layout::default()
            .direction(Direction::Horizontal)
            .constraints([Constraint::Length(38), Constraint::Min(40)])
            .split(root[1])
    } else {
        Layout::default()
            .direction(Direction::Vertical)
            .constraints([Constraint::Percentage(45), Constraint::Percentage(55)])
            .split(root[1])
    };

    draw_tasks(f, body[0], st, &pal);
    draw_logs(f, body[1], st, &pal);
    draw_footer(f, root[2], st, &pal);
}

fn draw_header(f: &mut ratatui::Frame<'_>, area: Rect, st: &State, pal: &Palette) {
    let (done, total, pct) = overall_counts(st);
    let took = progress::elapsed(st.started.elapsed());
    let spin = progress::spinner(st.out.ascii, st.tick);
    let step = st.current_step.unwrap_or("complete");
    let act = st.activity.as_deref().unwrap_or("");

    let title = if let Some(ref auth) = st.auth_waiting {
        format!(" [WARN] {auth} ")
    } else if act.is_empty() {
        format!(
            " {spin} preflight — {} — [{done}/{total}] {step} ({took}) ",
            crate::steps::HOST
        )
    } else {
        format!(" {spin} preflight — [{done}/{total}] {step}: {act} ({took}) ")
    };

    let border_color = if st.auth_waiting.is_some() {
        pal.warning
    } else {
        pal.structure
    };

    let gauge = Gauge::default()
        .block(
            Block::default()
                .title(Span::styled(
                    title,
                    Style::default()
                        .fg(if st.auth_waiting.is_some() {
                            pal.warning
                        } else {
                            pal.fg
                        })
                        .add_modifier(Modifier::BOLD),
                ))
                .borders(Borders::ALL)
                .border_style(Style::default().fg(border_color)),
        )
        .gauge_style(Style::default().fg(pal.accent))
        .percent(u16::from(pct))
        .label(format!("{pct}% ({done}/{total} steps)"));
    f.render_widget(gauge, area);
}

fn draw_tasks(f: &mut ratatui::Frame<'_>, area: Rect, st: &State, pal: &Palette) {
    let spin = progress::spinner(st.out.ascii, st.tick);
    let items: Vec<ListItem<'_>> = st
        .tasks
        .iter()
        .enumerate()
        .map(|(idx, t)| {
            let (glyph, color) = match t.status {
                TaskStatus::Pending => (if st.out.ascii { "." } else { "·" }, pal.structure),
                TaskStatus::Running => (spin, pal.accent),
                TaskStatus::Done(Outcome::Ok) => {
                    (if st.out.ascii { "[OK]" } else { "✓" }, pal.success)
                }
                TaskStatus::Done(Outcome::Skipped) => {
                    (if st.out.ascii { "[-]" } else { "–" }, pal.structure)
                }
                TaskStatus::Done(Outcome::Failed) => {
                    (if st.out.ascii { "[!]" } else { "✗" }, pal.error)
                }
            };
            let dur = match (t.status, t.elapsed, t.started) {
                (TaskStatus::Done(_), Some(d), _) => format!(" ({})", progress::elapsed(d)),
                (TaskStatus::Running, _, Some(s)) => {
                    format!(" ({})", progress::elapsed(s.elapsed()))
                }
                _ => String::new(),
            };
            let detail = t
                .detail
                .as_deref()
                .map(|d| {
                    let short: String = d.chars().take(24).collect();
                    format!(" — {short}")
                })
                .unwrap_or_default();
            let selected = st.focus_tasks && idx == st.selected_task;
            let style = if selected {
                Style::default().fg(pal.focus).add_modifier(Modifier::BOLD)
            } else {
                Style::default().fg(pal.fg)
            };
            let line = Line::from(vec![
                Span::styled(
                    format!("{glyph:<4} "),
                    Style::default().fg(color).add_modifier(Modifier::BOLD),
                ),
                Span::styled(t.name, style),
                Span::styled(dur, Style::default().fg(pal.structure)),
                Span::styled(detail, Style::default().fg(color)),
            ]);
            ListItem::new(line)
        })
        .collect();

    let border = if st.focus_tasks {
        pal.focus
    } else {
        pal.structure
    };
    let list = List::new(items).block(
        Block::default()
            .title(" Tasks ")
            .borders(Borders::ALL)
            .border_style(Style::default().fg(border)),
    );
    f.render_widget(list, area);
}

fn draw_logs(f: &mut ratatui::Frame<'_>, area: Rect, st: &State, pal: &Palette) {
    let inner_height = usize::from(area.height.saturating_sub(2)).max(1);
    let total = st.logs.len();
    let end = if st.follow_tail {
        total
    } else {
        st.scroll.min(total)
    };
    let start = end.saturating_sub(inner_height);

    let lines: Vec<Line<'_>> = st
        .logs
        .iter()
        .skip(start)
        .take(inner_height)
        .map(|l| {
            let color = if l.starts_with("[ERROR]") {
                pal.error
            } else if l.starts_with("[WARN]") {
                pal.warning
            } else if l.starts_with("[OK]") {
                pal.success
            } else {
                pal.fg
            };
            Line::from(Span::styled(l.as_str(), Style::default().fg(color)))
        })
        .collect();

    let border = if st.focus_tasks {
        pal.structure
    } else {
        pal.focus
    };
    let title = match st.activity.as_deref() {
        Some(act) if !act.is_empty() => format!(" Output — {act} "),
        _ => " Output ".to_owned(),
    };
    let p = Paragraph::new(lines)
        .block(
            Block::default()
                .title(title)
                .borders(Borders::ALL)
                .border_style(Style::default().fg(border)),
        )
        .wrap(Wrap { trim: false });
    f.render_widget(p, area);
}

fn draw_footer(f: &mut ratatui::Frame<'_>, area: Rect, st: &State, pal: &Palette) {
    let focus = if st.focus_tasks { "Tasks" } else { "Output" };
    // Longest first; the first that fits is shown, so `Copy: y` and
    // `Abort: q` survive an 80-column terminal instead of being cut off.
    let variants = [
        format!(
            " Focus: {focus} (Tab) | Scroll: ↑/↓ or j/k, PgUp/PgDn or Ctrl+B/F, Home/End or g/G | Copy: y | Abort: q / Esc / Ctrl+C"
        ),
        format!(" Focus: {focus} (Tab) | Scroll: ↑/↓ j/k PgUp/PgDn g/G | Copy: y | Abort: q / Esc"),
        format!(" {focus} (Tab) | ↑/↓ scroll | y copy | q abort"),
        " y copy | q abort".to_owned(),
    ];
    let width = usize::from(area.width);
    let text = variants
        .iter()
        .find(|v| v.chars().count() <= width)
        .unwrap_or(&variants[variants.len() - 1])
        .clone();
    let p = Paragraph::new(Span::styled(text, Style::default().fg(pal.structure)));
    f.render_widget(p, area);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn legacy_keys_decode_typeahead() {
        let k = legacy_keys(b"q\x1b[A\x1b[6~\x03\x1b\t\x1b[1;5C\x1b[1~\x1b[4~\x1bj\x1b");
        assert_eq!(
            k,
            vec![
                (KeyCode::Char('q'), KeyModifiers::NONE),
                (KeyCode::Up, KeyModifiers::NONE),
                (KeyCode::PageDown, KeyModifiers::NONE),
                (KeyCode::Char('c'), KeyModifiers::CONTROL),
                (KeyCode::Esc, KeyModifiers::NONE),
                (KeyCode::Tab, KeyModifiers::NONE),
                (KeyCode::Home, KeyModifiers::NONE),
                (KeyCode::End, KeyModifiers::NONE),
                (KeyCode::Char('j'), KeyModifiers::ALT),
                (KeyCode::Esc, KeyModifiers::NONE),
            ]
        );
    }

    #[test]
    fn fraction_percent_extracts_nix_and_vendored_counters() {
        assert_eq!(
            extract_fraction_percent("[3/12] building .#ollama …"),
            Some(25)
        );
        assert_eq!(
            extract_fraction_percent("  [12/12] checking artcraft"),
            Some(100)
        );
        assert_eq!(extract_fraction_percent("plain line without counter"), None);
    }

    #[test]
    fn strip_sequences_removes_csi_and_osc() {
        let s = "\x1b[38;5;154m[OK]\x1b[0m \x1b]2;title\x07done\r";
        assert_eq!(strip_osc_and_csi(s), "[OK] done");
    }
}
