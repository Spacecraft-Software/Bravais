// SPDX-License-Identifier: GPL-3.0-or-later
//
// steelbore-niri-unmax — un-maximize windows that open maximized-to-edges
// under the niri compositor.
//
// Why this exists: niri's `open-maximized` / `open-maximized-to-edges` window
// rules are *map-time only*. A client that maps at its tile size and then
// requests maximization a moment later (Chrome does exactly this — measured
// 2026-07-25: window maps at 756x816, then jumps to 1536x832, the full working
// area with gaps ignored) is honoured, and no `open-*` rule can refuse it.
// niri also has no rule to cap a maximized-to-edges window (`max-width` was
// tested live and does not constrain it). This daemon watches the niri event
// stream and toggles the maximized-to-edges state back off — but only for
// windows that just opened, so a maximize the user performs later is never
// touched.
//
// Detection is geometric: a maximized-to-edges tile spans the output's full
// logical width exactly, while the widest normal column stops short of it by
// twice the layout gap (1520 vs 1536 with the config's `gaps 8`). A tile that
// spans the full width AND the full height is fullscreen and is deliberately
// left alone — the niri config allows `open-fullscreen` so media players can
// launch fullscreen. PRECONDITION: this discrimination requires `layout.gaps`
// > 0 in the niri config; with zero gaps a normal full column is
// indistinguishable from maximized-to-edges and this daemon must not run.
//
// Design note (Standard §3.2): the workload is inherently serial — a single
// low-rate event stream (window opens and layout changes, a few per minute)
// consumed in order, with sub-millisecond one-shot IPC round-trips. This is a
// single-threaded blocking event loop; concurrency would add synchronization
// overhead and failure modes with zero throughput benefit. The settle timer
// needs no thread either: the socket read timeout doubles as the tick.
//
// `mimalloc` (M-MIMALLOC-APPS) is intentionally omitted: there is no
// allocation hot path (the daemon idles on an event loop), so the extra
// dependency is not justified.
//
// JSON handling is `serde_json::Value`-based rather than typed `niri-ipc`
// structs: the event schema is version-fluid across niri releases, the daemon
// consumes only a handful of fields, and permissive field extraction keeps it
// working when unrelated fields change. The wire shapes were verified against
// the live niri 26.04 IPC socket (2026-07-25).
//
// Accessibility (Standard §18): N/A-with-rationale — the daemon has no
// interactive surface. Its output is linear, append-only plain text on stderr
// (journald adds timestamps), no color, no animation, which already satisfies
// the §18.2.1 always-on rules.
//
// Rust guideline compliant 2026-05-18

use std::collections::{HashMap, HashSet};
use std::io::{BufRead, BufReader, ErrorKind, Write};
use std::net::Shutdown;
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

use anyhow::{anyhow, bail, Context as _, Result};
use serde_json::{json, Value};

/// Act only on windows younger than this. Measured: Chrome issues its
/// re-maximize within ~1 s of mapping (both fresh `--new-window` windows and
/// session-restore windows); 3 s covers slow starts. Raising it widens the
/// window in which a *user's* manual maximize of a fresh window would be
/// reverted (once); lowering it risks missing slow clients.
const DEFAULT_GRACE_MS: u64 = 3000;

/// Wait this long after detecting the maximized state before acting, then
/// re-confirm via a fresh `Windows` query. Chrome windows were observed to
/// sometimes revert on their own; the settle delay plus re-confirmation
/// prevents toggling a window that already put itself back (the action is a
/// toggle — acting on a no-longer-maximized window would *maximize* it).
const DEFAULT_SETTLE_MS: u64 = 200;

/// Socket read timeout; doubles as the settle-timer tick. Must be no larger
/// than the settle delay or acting would lag detection by a full tick.
const TICK: Duration = Duration::from_millis(100);

/// One-shot request round-trip timeout. The compositor answers in
/// microseconds; 2 s only guards against a wedged compositor.
const REQUEST_TIMEOUT: Duration = Duration::from_secs(2);

/// Mid-stream reconnect attempts before giving up. The event stream only
/// drops when the compositor goes away; a handful of retries bridges a
/// momentary hiccup without flapping for the rest of a dead session.
const RECONNECT_ATTEMPTS: u32 = 5;

/// Delay between reconnect attempts.
const RECONNECT_DELAY: Duration = Duration::from_secs(2);

/// A stream attachment that lasted at least this long counts as healthy and
/// resets the reconnect budget, so a long-lived session survives occasional
/// hiccups instead of exhausting a global counter over weeks of uptime.
const HEALTHY_RUN: Duration = Duration::from_mins(1);

/// Tolerance when comparing f64 logical sizes. Logical sizes represent whole
/// pixels; the nearest competing width (a full column, `output - 2*gaps`) is
/// 16 px away with the config's `gaps 8`, so 0.5 px cannot misclassify.
const SIZE_EPSILON: f64 = 0.5;

const VERSION: &str = env!("CARGO_PKG_VERSION");

const USAGE: &str = "\
steelbore-niri-unmax — un-maximize windows that open maximized-to-edges under niri

Usage: steelbore-niri-unmax [OPTIONS]

Options:
      --grace-ms <MS>    Act only on windows younger than this (default: 3000)
      --settle-ms <MS>   Delay between detection and action (default: 200)
      --exempt <APP_ID>  Exact app-id to leave alone (repeatable)
      --dry-run          Log what would be done without acting
      --verbose          Verbose diagnostics
  -h, --help             Print this help
  -V, --version          Print version

The niri socket is taken from $NIRI_SOCKET, falling back to
$XDG_RUNTIME_DIR/niri.*.sock. Exits 0 when no niri session is found.

Maintained by Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
https://Bravais.SpacecraftSoftware.org/";

fn main() -> Result<()> {
    let cfg = match Config::from_args(std::env::args().skip(1)) {
        Ok(Some(cfg)) => cfg,
        Ok(None) => return Ok(()), // --help / --version printed
        Err(e) => {
            eprintln!("steelbore-niri-unmax: error: {e}");
            eprintln!("{USAGE}");
            std::process::exit(2);
        }
    };

    // A socket *file* can outlive a crashed compositor (nothing cleans
    // /run/user/*/niri.*.sock), and a stale $NIRI_SOCKET can linger in the
    // systemd user environment across sessions. Probe every candidate and use
    // the first that answers; none answering means this is not a niri session
    // (the unit is started for every graphical session), and a clean zero
    // exit keeps `Restart=on-failure` from flapping under GNOME/COSMIC/Plasma.
    let mut socket = None;
    for candidate in socket_candidates() {
        match request(&candidate, &json!("Version")) {
            Ok(reply) => {
                if cfg.verbose {
                    eprintln!("steelbore-niri-unmax: attached to niri {reply}");
                }
                socket = Some(candidate);
                break;
            }
            Err(e) => {
                eprintln!(
                    "steelbore-niri-unmax: socket {} is not answering ({e:#}); skipping",
                    candidate.display()
                );
            }
        }
    }
    let Some(socket) = socket else {
        eprintln!("steelbore-niri-unmax: no answering niri socket; not a niri session, exiting");
        return Ok(());
    };

    // Single-instance guard. Two instances would both confirm-then-toggle the
    // same window — a double toggle re-maximizes it. The lock is an abstract
    // unix socket (Linux-only, kernel-cleaned on process exit — no stale lock
    // files), scoped to the niri socket path so one daemon per session is
    // allowed while duplicates in the SAME session exit cleanly.
    let _instance_lock = match claim_instance_lock(&socket) {
        Ok(lock) => lock,
        Err(e) => {
            eprintln!(
                "steelbore-niri-unmax: another instance is already watching ({e:#}); exiting"
            );
            return Ok(());
        }
    };
    eprintln!("steelbore-niri-unmax: watching {}", socket.display());

    let mut attempts = 0;
    loop {
        let attach_time = Instant::now();
        let err = match watch(&socket, &cfg) {
            Ok(never) => match never {},
            Err(e) => e,
        };
        // A run that stayed attached for a while was healthy — reset the
        // budget so a long-lived session can survive occasional hiccups
        // without eventually exhausting a global counter.
        if attach_time.elapsed() >= HEALTHY_RUN {
            attempts = 0;
        }
        if attempts < RECONNECT_ATTEMPTS {
            attempts += 1;
            eprintln!(
                "steelbore-niri-unmax: warning: event stream lost ({err:#}); \
                 reconnect attempt {attempts}/{RECONNECT_ATTEMPTS}"
            );
            std::thread::sleep(RECONNECT_DELAY);
        } else {
            // Persistent loss: the session is most likely gone. Exit
            // non-zero so systemd restarts us once more; that restart
            // finds no answering socket and exits cleanly (see above).
            return Err(err.context("event stream lost and reconnects exhausted"));
        }
    }
}

/// Binds the per-session single-instance lock. The abstract-namespace name
/// embeds the niri socket path; the kernel releases it automatically when the
/// process exits. Note: the abstract namespace is per network namespace, not
/// per user — fine on a single-user machine, and a cross-user collision only
/// makes the second user's daemon exit cleanly.
fn claim_instance_lock(niri_socket: &Path) -> Result<std::os::unix::net::UnixListener> {
    use std::os::linux::net::SocketAddrExt as _;
    let name = format!("steelbore-niri-unmax:{}", niri_socket.display());
    let addr = std::os::unix::net::SocketAddr::from_abstract_name(name.as_bytes())
        .context("building the abstract lock address")?;
    std::os::unix::net::UnixListener::bind_addr(&addr).context("binding the instance lock")
}

// ─── Configuration ──────────────────────────────────────────────────────────

/// Runtime configuration parsed from the command line.
#[derive(Debug, Clone)]
struct Config {
    grace: Duration,
    settle: Duration,
    exempt: Vec<String>,
    dry_run: bool,
    verbose: bool,
}

impl Config {
    /// Parses arguments. `Ok(None)` means `--help`/`--version` was printed
    /// and the process should exit successfully.
    fn from_args(args: impl Iterator<Item = String>) -> Result<Option<Self>> {
        let mut cfg = Self {
            grace: Duration::from_millis(DEFAULT_GRACE_MS),
            settle: Duration::from_millis(DEFAULT_SETTLE_MS),
            exempt: Vec::new(),
            dry_run: false,
            verbose: false,
        };
        let mut args = args.peekable();
        while let Some(arg) = args.next() {
            match arg.as_str() {
                "--grace-ms" => cfg.grace = Duration::from_millis(parse_ms(&arg, args.next())?),
                "--settle-ms" => cfg.settle = Duration::from_millis(parse_ms(&arg, args.next())?),
                "--exempt" => {
                    let id = args
                        .next()
                        .ok_or_else(|| anyhow!("{arg} requires an app-id argument"))?;
                    cfg.exempt.push(id);
                }
                "--dry-run" => cfg.dry_run = true,
                "--verbose" => cfg.verbose = true,
                "-h" | "--help" => {
                    println!("{USAGE}");
                    return Ok(None);
                }
                "-V" | "--version" => {
                    println!("steelbore-niri-unmax {VERSION}");
                    println!(
                        "Maintained by Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>"
                    );
                    println!("Copyright (C) 2026 Mohamed Hammad & Spacecraft Software");
                    println!("License: GPL-3.0-or-later");
                    println!("https://Bravais.SpacecraftSoftware.org/");
                    return Ok(None);
                }
                other => bail!("unknown argument: {other}"),
            }
        }
        Ok(Some(cfg))
    }
}

fn parse_ms(flag: &str, value: Option<String>) -> Result<u64> {
    let value = value.ok_or_else(|| anyhow!("{flag} requires a millisecond argument"))?;
    value
        .parse::<u64>()
        .with_context(|| format!("{flag}: not a valid millisecond count: {value:?}"))
}

// ─── Socket discovery ───────────────────────────────────────────────────────

/// Lists candidate niri IPC sockets: `$NIRI_SOCKET` first, then every
/// `niri.*.sock` in `$XDG_RUNTIME_DIR`. All candidates are returned (not just
/// the first) because a crashed compositor leaves its socket *file* behind —
/// the caller probes each until one answers, so a stale file next to a live
/// one cannot shadow it.
fn socket_candidates() -> Vec<PathBuf> {
    let mut candidates = Vec::new();
    if let Ok(path) = std::env::var("NIRI_SOCKET") {
        if !path.is_empty() {
            let path = PathBuf::from(path);
            if path.exists() {
                candidates.push(path);
            }
        }
    }
    if let Ok(runtime_dir) = std::env::var("XDG_RUNTIME_DIR") {
        if let Ok(entries) = std::fs::read_dir(runtime_dir) {
            let mut globbed: Vec<PathBuf> = entries
                .filter_map(std::result::Result::ok)
                .map(|e| e.path())
                .filter(|p| {
                    p.file_name().and_then(|n| n.to_str()).is_some_and(|n| {
                        // niri names its socket exactly `niri.<display>.sock`,
                        // lowercase — a case-insensitive match would be wrong.
                        #[expect(
                            clippy::case_sensitive_file_extension_comparisons,
                            reason = "the niri socket name is exact, not a user-supplied extension"
                        )]
                        let matches = n.starts_with("niri.") && n.ends_with(".sock");
                        matches
                    })
                })
                .filter(|p| !candidates.contains(p))
                .collect();
            globbed.sort(); // deterministic probe order
            candidates.extend(globbed);
        }
    }
    candidates
}

// ─── IPC plumbing ───────────────────────────────────────────────────────────

/// Sends one newline-delimited JSON request on a fresh connection and returns
/// the single JSON reply. Wire shape verified against niri 26.04.
fn request(socket: &Path, payload: &Value) -> Result<Value> {
    let mut stream = UnixStream::connect(socket).context("connecting to niri socket")?;
    stream.set_read_timeout(Some(REQUEST_TIMEOUT))?;
    stream.set_write_timeout(Some(REQUEST_TIMEOUT))?;
    let mut line = serde_json::to_string(payload)?;
    line.push('\n');
    stream.write_all(line.as_bytes())?;
    stream.shutdown(Shutdown::Write)?;
    let mut reply = String::new();
    BufReader::new(stream)
        .read_line(&mut reply)
        .context("reading niri reply")?;
    serde_json::from_str(reply.trim_end()).context("parsing niri reply")
}

/// Toggles the maximized-to-edges state of the given window. The caller must
/// have just confirmed the window IS maximized-to-edges — the action is a
/// toggle, so acting on a normal window would maximize it instead.
fn toggle_maximize_to_edges(socket: &Path, id: u64) -> Result<()> {
    let reply = request(
        socket,
        &json!({"Action": {"MaximizeWindowToEdges": {"id": id}}}),
    )?;
    if reply.get("Ok").is_some() {
        Ok(())
    } else {
        bail!("niri rejected the action: {reply}")
    }
}

// ─── Geometry classification ────────────────────────────────────────────────

/// How a tiled window's tile relates to its output's logical size.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum TileClass {
    /// Smaller than the output in at least one dimension short of the rules
    /// below — a normal tile (the layout gap keeps even a full column 2*gap
    /// narrower than the output).
    Normal,
    /// Spans the output's full logical width but not its full height —
    /// niri's "maximized to edges" state (gaps ignored, bar strut kept).
    MaximizedToEdges,
    /// Spans the output's full logical width AND height. Deliberately left
    /// alone: the niri config allows `open-fullscreen`.
    Fullscreen,
}

fn classify(tile_w: f64, tile_h: f64, out_w: f64, out_h: f64) -> TileClass {
    let full_width = (tile_w - out_w).abs() < SIZE_EPSILON;
    let full_height = (tile_h - out_h).abs() < SIZE_EPSILON;
    match (full_width, full_height) {
        (true, true) => TileClass::Fullscreen,
        (true, false) => TileClass::MaximizedToEdges,
        _ => TileClass::Normal,
    }
}

// ─── Tracker (pure decision core) ───────────────────────────────────────────

/// A window that opened while we were watching and is still inside its grace
/// window.
#[derive(Debug)]
struct Candidate {
    opened_at: Instant,
    app_id: String,
    title: String,
    workspace_id: Option<u64>,
    /// Set while the window is observed maximized-to-edges; cleared if it
    /// returns to a normal tile on its own before the settle delay elapses.
    pending_since: Option<Instant>,
}

/// Pure decision core: consumes parsed events plus an injected clock, decides
/// which windows are due for un-maximizing. All I/O stays in the shell around
/// it so the policy is unit-testable without a compositor.
#[derive(Debug)]
struct Tracker {
    grace: Duration,
    settle: Duration,
    exempt: Vec<String>,
    /// Windows that existed before the stream started (or across a
    /// reconnect). Never touched: we cannot know whether the user maximized
    /// them.
    preexisting: HashSet<u64>,
    candidates: HashMap<u64, Candidate>,
    /// workspace id → output name (from `WorkspacesChanged`).
    workspace_output: HashMap<u64, String>,
    /// output name → logical (width, height) (from `Outputs` queries).
    output_logical: HashMap<String, (f64, f64)>,
}

impl Tracker {
    fn new(grace: Duration, settle: Duration, exempt: Vec<String>) -> Self {
        Self {
            grace,
            settle,
            exempt,
            preexisting: HashSet::new(),
            candidates: HashMap::new(),
            workspace_output: HashMap::new(),
            output_logical: HashMap::new(),
        }
    }

    /// Feeds one event stream message. Returns `true` when the shell should
    /// refresh output geometry (workspaces changed).
    fn on_event(&mut self, event: &Value, now: Instant) -> bool {
        if let Some(state) = event.get("WindowsChanged") {
            // Full-state snapshot at stream (re)start: everything already
            // open is off-limits.
            self.candidates.clear();
            self.preexisting.clear();
            if let Some(windows) = state.get("windows").and_then(Value::as_array) {
                for w in windows {
                    if let Some(id) = w.get("id").and_then(Value::as_u64) {
                        self.preexisting.insert(id);
                    }
                }
            }
        } else if let Some(change) = event.get("WindowOpenedOrChanged") {
            if let Some(window) = change.get("window") {
                self.on_window(window, now);
            }
        } else if let Some(change) = event.get("WindowLayoutsChanged") {
            if let Some(changes) = change.get("changes").and_then(Value::as_array) {
                for pair in changes {
                    let (Some(id), Some(layout)) =
                        (pair.get(0).and_then(Value::as_u64), pair.get(1))
                    else {
                        continue;
                    };
                    self.on_layout(id, layout, now);
                }
            }
        } else if let Some(closed) = event.get("WindowClosed") {
            if let Some(id) = closed.get("id").and_then(Value::as_u64) {
                self.candidates.remove(&id);
                self.preexisting.remove(&id);
            }
        } else if let Some(ws) = event.get("WorkspacesChanged") {
            self.workspace_output.clear();
            if let Some(workspaces) = ws.get("workspaces").and_then(Value::as_array) {
                for w in workspaces {
                    let (Some(id), Some(output)) = (
                        w.get("id").and_then(Value::as_u64),
                        w.get("output").and_then(Value::as_str),
                    ) else {
                        continue;
                    };
                    self.workspace_output.insert(id, output.to_owned());
                }
            }
            return true;
        }
        false
    }

    /// Ingests the reply of an `Outputs` query.
    fn set_outputs(&mut self, reply: &Value) {
        let Some(outputs) = reply.pointer("/Ok/Outputs").and_then(Value::as_object) else {
            return;
        };
        self.output_logical.clear();
        for (name, output) in outputs {
            // `logical` is null for disabled outputs — skip those.
            let (Some(w), Some(h)) = (
                output.pointer("/logical/width").and_then(Value::as_f64),
                output.pointer("/logical/height").and_then(Value::as_f64),
            ) else {
                continue;
            };
            self.output_logical.insert(name.clone(), (w, h));
        }
    }

    fn on_window(&mut self, window: &Value, now: Instant) {
        let Some(id) = window.get("id").and_then(Value::as_u64) else {
            return;
        };
        if self.preexisting.contains(&id) {
            return;
        }
        let app_id = window
            .get("app_id")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_owned();
        let title = window
            .get("title")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_owned();
        let workspace_id = window.get("workspace_id").and_then(Value::as_u64);
        let floating = window
            .get("is_floating")
            .and_then(Value::as_bool)
            .unwrap_or(false);

        let candidate = self.candidates.entry(id).or_insert_with(|| Candidate {
            opened_at: now,
            app_id: String::new(),
            title: String::new(),
            workspace_id: None,
            pending_since: None,
        });
        // app_id and title often arrive only on a later change event.
        candidate.app_id = app_id;
        candidate.title = title;
        candidate.workspace_id = workspace_id;
        if floating {
            // Floating windows aren't tiled; their size never spans the
            // output the way the tiled maximized state does. Stop tracking.
            self.candidates.remove(&id);
            return;
        }
        if let Some(layout) = window.get("layout") {
            self.on_layout(id, layout, now);
        }
    }

    fn on_layout(&mut self, id: u64, layout: &Value, now: Instant) {
        let Some((tile_w, tile_h)) = tile_size(layout) else {
            return;
        };
        let Some(class) = self.classify_on_workspace(id, tile_w, tile_h) else {
            return;
        };
        let Some(candidate) = self.candidates.get_mut(&id) else {
            return;
        };
        if self.exempt.contains(&candidate.app_id) {
            return;
        }
        match class {
            TileClass::MaximizedToEdges => {
                let within_grace = now.duration_since(candidate.opened_at) <= self.grace;
                if within_grace && candidate.pending_since.is_none() {
                    candidate.pending_since = Some(now);
                }
            }
            TileClass::Normal => {
                // The client put itself back (observed with Chrome) — acting
                // now would MAXIMIZE it, since the action is a toggle.
                candidate.pending_since = None;
            }
            TileClass::Fullscreen => {
                // Allowed by policy (open-fullscreen is deliberately
                // permitted in the niri config); never act, and clear any
                // pending maximize so a maximize→fullscreen transition
                // doesn't get "restored" out of fullscreen.
                candidate.pending_since = None;
            }
        }
    }

    /// The output logical size a window's tile is measured against, resolved
    /// through its workspace. `None` when geometry is not yet known.
    fn output_size_for(&self, workspace_id: Option<u64>) -> Option<(f64, f64)> {
        let output = self.workspace_output.get(&workspace_id?)?;
        self.output_logical.get(output).copied()
    }

    fn classify_on_workspace(&self, id: u64, tile_w: f64, tile_h: f64) -> Option<TileClass> {
        let workspace_id = self.candidates.get(&id)?.workspace_id;
        let (out_w, out_h) = self.output_size_for(workspace_id)?;
        Some(classify(tile_w, tile_h, out_w, out_h))
    }

    /// Windows whose settle delay has elapsed, ready for confirm-and-act.
    /// Also prunes candidates whose grace expired without a pending state —
    /// they can never act, so the map stays bounded by the grace window.
    fn due(&mut self, now: Instant) -> Vec<u64> {
        let settle = self.settle;
        let grace = self.grace;
        let due: Vec<u64> = self
            .candidates
            .iter()
            .filter(|(_, c)| {
                c.pending_since
                    .is_some_and(|since| now.duration_since(since) >= settle)
            })
            .map(|(id, _)| *id)
            .collect();
        self.candidates
            .retain(|_, c| c.pending_since.is_some() || now.duration_since(c.opened_at) <= grace);
        due
    }

    /// Forgets a window after the shell has acted (or declined to act) on it.
    fn resolve(&mut self, id: u64) {
        self.candidates.remove(&id);
    }

    fn describe(&self, id: u64) -> String {
        self.candidates.get(&id).map_or_else(
            || format!("window {id}"),
            |c| format!("window {id} ({} {:?})", c.app_id, c.title),
        )
    }
}

fn tile_size(layout: &Value) -> Option<(f64, f64)> {
    let tile = layout.get("tile_size")?.as_array()?;
    Some((tile.first()?.as_f64()?, tile.get(1)?.as_f64()?))
}

// ─── Event loop (I/O shell) ─────────────────────────────────────────────────

/// Attaches to the event stream and runs until the connection drops — the
/// only way out is an error, hence [`std::convert::Infallible`].
fn watch(socket: &Path, cfg: &Config) -> Result<std::convert::Infallible> {
    let stream = UnixStream::connect(socket).context("connecting to niri socket")?;
    stream.set_read_timeout(Some(TICK))?;
    let mut writer = stream.try_clone().context("cloning socket for writing")?;
    writer
        .write_all(b"\"EventStream\"\n")
        .context("requesting the event stream")?;

    let mut reader = BufReader::new(stream);
    await_handshake(&mut reader)?;

    let mut tracker = Tracker::new(cfg.grace, cfg.settle, cfg.exempt.clone());
    refresh_geometry(socket, &mut tracker, cfg);

    let mut line = String::new();
    loop {
        match reader.read_line(&mut line) {
            Ok(0) => bail!("event stream closed by the compositor"),
            Ok(_) => {
                match serde_json::from_str::<Value>(line.trim_end()) {
                    Ok(event) => {
                        if tracker.on_event(&event, Instant::now()) {
                            refresh_geometry(socket, &mut tracker, cfg);
                        }
                    }
                    Err(e) => {
                        // A malformed line is survivable; skip it rather than
                        // dropping the whole stream (fault tolerance, §3.1).
                        eprintln!("steelbore-niri-unmax: warning: unparseable event ({e}): {line}");
                    }
                }
                line.clear();
            }
            // Read timeout: this is the settle-timer tick. The partial line
            // (if any) stays in `line` and the next read appends to it.
            Err(e) if matches!(e.kind(), ErrorKind::WouldBlock | ErrorKind::TimedOut) => {}
            Err(e) => return Err(e).context("reading the event stream"),
        }
        for id in tracker.due(Instant::now()) {
            if let Err(e) = confirm_and_act(socket, &mut tracker, cfg, id) {
                eprintln!("steelbore-niri-unmax: warning: acting on window {id} failed: {e:#}");
            }
            tracker.resolve(id);
        }
    }
}

/// Reads the `{"Ok":"Handled"}` acknowledgement of the `EventStream` request.
fn await_handshake(reader: &mut BufReader<UnixStream>) -> Result<()> {
    let deadline = Instant::now() + REQUEST_TIMEOUT;
    let mut line = String::new();
    loop {
        match reader.read_line(&mut line) {
            Ok(0) => bail!("compositor closed the stream during the handshake"),
            Ok(_) => {
                let reply: Value =
                    serde_json::from_str(line.trim_end()).context("parsing the handshake reply")?;
                if reply.get("Ok").is_some() {
                    return Ok(());
                }
                bail!("event stream refused: {reply}");
            }
            Err(e) if matches!(e.kind(), ErrorKind::WouldBlock | ErrorKind::TimedOut) => {
                if Instant::now() >= deadline {
                    bail!("timed out waiting for the event stream handshake");
                }
            }
            Err(e) => return Err(e).context("reading the handshake"),
        }
    }
}

/// Refreshes workspace→output and output→logical-size maps. Best-effort: on
/// failure the tracker simply cannot classify until the next refresh, which
/// fails safe (no action without known geometry).
fn refresh_geometry(socket: &Path, tracker: &mut Tracker, cfg: &Config) {
    match request(socket, &json!("Outputs")) {
        Ok(reply) => tracker.set_outputs(&reply),
        Err(e) => {
            eprintln!("steelbore-niri-unmax: warning: querying outputs failed: {e:#}");
        }
    }
    // Workspaces usually arrive via WorkspacesChanged, but on first attach we
    // may consume the outputs before the event lands; query once directly.
    if tracker.workspace_output.is_empty() {
        if let Ok(reply) = request(socket, &json!("Workspaces")) {
            if let Some(list) = reply.pointer("/Ok/Workspaces").and_then(Value::as_array) {
                for w in list {
                    let (Some(id), Some(output)) = (
                        w.get("id").and_then(Value::as_u64),
                        w.get("output").and_then(Value::as_str),
                    ) else {
                        continue;
                    };
                    tracker.workspace_output.insert(id, output.to_owned());
                }
            }
        }
    }
    if cfg.verbose {
        eprintln!(
            "steelbore-niri-unmax: geometry: {} output(s), {} workspace(s)",
            tracker.output_logical.len(),
            tracker.workspace_output.len()
        );
    }
}

/// Re-confirms the window is still maximized-to-edges via a fresh `Windows`
/// query, then toggles it back. The re-confirmation closes the race where the
/// client un-maximized itself between detection and action — the toggle would
/// otherwise re-maximize it.
fn confirm_and_act(socket: &Path, tracker: &mut Tracker, cfg: &Config, id: u64) -> Result<()> {
    let reply = request(socket, &json!("Windows")).context("querying windows to confirm")?;
    let windows = reply
        .pointer("/Ok/Windows")
        .and_then(Value::as_array)
        .ok_or_else(|| anyhow!("unexpected Windows reply shape"))?;
    let Some(window) = windows
        .iter()
        .find(|w| w.get("id").and_then(Value::as_u64) == Some(id))
    else {
        return Ok(()); // closed in the meantime — nothing to do
    };

    let app_id = window
        .get("app_id")
        .and_then(Value::as_str)
        .unwrap_or_default();
    if cfg.exempt.iter().any(|e| e == app_id) {
        return Ok(());
    }
    if window
        .get("is_floating")
        .and_then(Value::as_bool)
        .unwrap_or(false)
    {
        return Ok(());
    }
    let Some((tile_w, tile_h)) = window.get("layout").and_then(tile_size) else {
        return Ok(());
    };
    let workspace_id = window.get("workspace_id").and_then(Value::as_u64);
    let Some((out_w, out_h)) = tracker.output_size_for(workspace_id) else {
        if cfg.verbose {
            eprintln!("steelbore-niri-unmax: skipping window {id}: output geometry unknown");
        }
        return Ok(());
    };
    if classify(tile_w, tile_h, out_w, out_h) != TileClass::MaximizedToEdges {
        if cfg.verbose {
            eprintln!(
                "steelbore-niri-unmax: window {id} settled on its own ({tile_w}x{tile_h}); not acting"
            );
        }
        return Ok(());
    }

    let description = tracker.describe(id);
    if cfg.dry_run {
        eprintln!(
            "steelbore-niri-unmax: dry-run: would un-maximize {description} ({tile_w}x{tile_h})"
        );
        return Ok(());
    }
    toggle_maximize_to_edges(socket, id).context("toggling maximize-to-edges")?;
    eprintln!(
        "steelbore-niri-unmax: un-maximized {description}: opened maximized-to-edges \
         ({tile_w}x{tile_h} on a {out_w}x{out_h} output)"
    );
    Ok(())
}

// ─── Tests ──────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    /// Geometry from the live `ThinkPad` session the daemon was built against:
    /// eDP-1 at 1920x1080, scale 1.25 → logical 1536x864; `gaps 8`; a 32 px
    /// top bar. Normal half tile 756x816, full column 1520, maximized-to-edges
    /// 1536x832, fullscreen 1536x864.
    const OUT_W: f64 = 1536.0;
    const OUT_H: f64 = 864.0;

    fn tracker() -> Tracker {
        let mut t = Tracker::new(
            Duration::from_millis(DEFAULT_GRACE_MS),
            Duration::from_millis(DEFAULT_SETTLE_MS),
            vec!["exempt-app".to_owned()],
        );
        t.workspace_output.insert(1, "eDP-1".to_owned());
        t.output_logical.insert("eDP-1".to_owned(), (OUT_W, OUT_H));
        t
    }

    fn open_event(id: u64, app_id: &str, tile: (f64, f64), floating: bool) -> Value {
        json!({"WindowOpenedOrChanged": {"window": {
            "id": id,
            "title": "t",
            "app_id": app_id,
            "pid": 1,
            "workspace_id": 1,
            "is_focused": true,
            "is_floating": floating,
            "layout": {"tile_size": [tile.0, tile.1], "window_size": [tile.0, tile.1]},
        }}})
    }

    fn layout_event(id: u64, tile: (f64, f64)) -> Value {
        json!({"WindowLayoutsChanged": {"changes": [
            [id, {"tile_size": [tile.0, tile.1], "window_size": [tile.0, tile.1]}]
        ]}})
    }

    #[test]
    fn classify_discriminates_all_observed_shapes() {
        // Normal half tile.
        assert_eq!(classify(756.0, 816.0, OUT_W, OUT_H), TileClass::Normal);
        // Widest normal column (output - 2*gaps) must stay Normal.
        assert_eq!(classify(1520.0, 816.0, OUT_W, OUT_H), TileClass::Normal);
        // The measured Chrome maximized-to-edges tile.
        assert_eq!(
            classify(1536.0, 832.0, OUT_W, OUT_H),
            TileClass::MaximizedToEdges
        );
        // Full width AND height is fullscreen — left alone.
        assert_eq!(classify(1536.0, 864.0, OUT_W, OUT_H), TileClass::Fullscreen);
    }

    #[test]
    fn preexisting_windows_are_never_candidates() {
        let mut t = tracker();
        let now = Instant::now();
        let snapshot = json!({"WindowsChanged": {"windows": [
            {"id": 7, "app_id": "google-chrome", "workspace_id": 1, "is_floating": false,
             "layout": {"tile_size": [1536.0, 832.0]}}
        ]}});
        t.on_event(&snapshot, now);
        // Even a maximize event on it must not create a candidate.
        t.on_event(&layout_event(7, (1536.0, 832.0)), now);
        assert!(t.due(now + Duration::from_secs(10)).is_empty());
    }

    #[test]
    fn open_then_maximize_becomes_due_after_settle() {
        let mut t = tracker();
        let now = Instant::now();
        t.on_event(&open_event(20, "google-chrome", (756.0, 816.0), false), now);
        let t1 = now + Duration::from_millis(500);
        t.on_event(&layout_event(20, (1536.0, 832.0)), t1);
        // Not yet due before the settle delay…
        assert!(t.due(t1 + Duration::from_millis(50)).is_empty());
        // …due after it.
        assert_eq!(t.due(t1 + Duration::from_millis(250)), vec![20]);
    }

    #[test]
    fn window_opening_already_maximized_is_due() {
        let mut t = tracker();
        let now = Instant::now();
        t.on_event(&open_event(21, "app", (1536.0, 832.0), false), now);
        assert_eq!(t.due(now + Duration::from_millis(250)), vec![21]);
    }

    #[test]
    fn self_revert_clears_pending() {
        let mut t = tracker();
        let now = Instant::now();
        t.on_event(&open_event(20, "google-chrome", (756.0, 816.0), false), now);
        t.on_event(&layout_event(20, (1536.0, 832.0)), now);
        // Chrome puts itself back before the settle delay elapses.
        t.on_event(
            &layout_event(20, (756.0, 816.0)),
            now + Duration::from_millis(100),
        );
        assert!(t.due(now + Duration::from_secs(1)).is_empty());
    }

    #[test]
    fn maximize_after_grace_is_ignored() {
        let mut t = tracker();
        let now = Instant::now();
        t.on_event(&open_event(22, "app", (756.0, 816.0), false), now);
        let late = now + Duration::from_millis(DEFAULT_GRACE_MS + 1000);
        t.on_event(&layout_event(22, (1536.0, 832.0)), late);
        assert!(t.due(late + Duration::from_secs(1)).is_empty());
    }

    #[test]
    fn exempt_app_is_ignored() {
        let mut t = tracker();
        let now = Instant::now();
        t.on_event(&open_event(23, "exempt-app", (1536.0, 832.0), false), now);
        assert!(t.due(now + Duration::from_secs(1)).is_empty());
    }

    #[test]
    fn floating_window_is_ignored() {
        let mut t = tracker();
        let now = Instant::now();
        t.on_event(&open_event(24, "app", (1536.0, 832.0), true), now);
        assert!(t.due(now + Duration::from_secs(1)).is_empty());
    }

    #[test]
    fn fullscreen_open_is_left_alone() {
        let mut t = tracker();
        let now = Instant::now();
        t.on_event(&open_event(25, "mpv", (1536.0, 864.0), false), now);
        assert!(t.due(now + Duration::from_secs(1)).is_empty());
        // A maximize that then goes fullscreen must clear pending too.
        t.on_event(&open_event(26, "mpv2", (1536.0, 832.0), false), now);
        t.on_event(&layout_event(26, (1536.0, 864.0)), now);
        assert!(t.due(now + Duration::from_secs(1)).is_empty());
    }

    #[test]
    fn closed_window_is_forgotten() {
        let mut t = tracker();
        let now = Instant::now();
        t.on_event(&open_event(27, "app", (1536.0, 832.0), false), now);
        t.on_event(&json!({"WindowClosed": {"id": 27}}), now);
        assert!(t.due(now + Duration::from_secs(1)).is_empty());
    }

    #[test]
    fn due_fires_once_per_window() {
        let mut t = tracker();
        let now = Instant::now();
        t.on_event(&open_event(28, "app", (1536.0, 832.0), false), now);
        let later = now + Duration::from_secs(1);
        assert_eq!(t.due(later), vec![28]);
        t.resolve(28);
        assert!(t.due(later + Duration::from_secs(1)).is_empty());
    }

    #[test]
    fn workspaces_event_requests_geometry_refresh_and_maps_outputs() {
        let mut t = tracker();
        let now = Instant::now();
        let ws = json!({"WorkspacesChanged": {"workspaces": [
            {"id": 3, "idx": 2, "output": "eDP-1", "is_active": true},
            {"id": 9, "idx": 1, "output": "HDMI-A-1", "is_active": false},
        ]}});
        assert!(t.on_event(&ws, now));
        assert_eq!(
            t.workspace_output.get(&9).map(String::as_str),
            Some("HDMI-A-1")
        );
    }

    #[test]
    fn outputs_reply_shape_from_live_probe_parses() {
        let mut t = tracker();
        // Shape captured from the live niri 26.04 IPC socket (2026-07-25).
        let reply = json!({"Ok": {"Outputs": {
            "eDP-1": {"logical": {"x": 0, "y": 0, "width": 1536, "height": 864,
                       "scale": 1.25, "transform": "Normal"}},
            "DP-3": {"logical": null},
        }}});
        t.set_outputs(&reply);
        assert_eq!(t.output_logical.get("eDP-1"), Some(&(1536.0, 864.0)));
        assert!(!t.output_logical.contains_key("DP-3"));
    }

    #[test]
    fn grace_expired_candidates_are_pruned() {
        let mut t = tracker();
        let now = Instant::now();
        t.on_event(&open_event(30, "app", (756.0, 816.0), false), now);
        let late = now + Duration::from_millis(DEFAULT_GRACE_MS + 1000);
        assert!(t.due(late).is_empty());
        assert!(t.candidates.is_empty());
    }

    #[test]
    fn config_parses_flags() {
        let cfg = Config::from_args(
            [
                "--grace-ms",
                "5000",
                "--settle-ms",
                "300",
                "--exempt",
                "mpv",
                "--exempt",
                "vlc",
                "--dry-run",
                "--verbose",
            ]
            .iter()
            .map(ToString::to_string),
        )
        .expect("valid args")
        .expect("not help/version");
        assert_eq!(cfg.grace, Duration::from_secs(5));
        assert_eq!(cfg.settle, Duration::from_millis(300));
        assert_eq!(cfg.exempt, vec!["mpv".to_owned(), "vlc".to_owned()]);
        assert!(cfg.dry_run);
        assert!(cfg.verbose);
    }

    #[test]
    fn config_rejects_unknown_flags() {
        assert!(Config::from_args(["--bogus".to_owned()].into_iter()).is_err());
    }
}
