// SPDX-License-Identifier: GPL-3.0-or-later
//
// steelbore-cosmic-unmax — un-maximize windows that maximize themselves on
// open under the COSMIC compositor.
//
// Why this exists: COSMIC has no setting for this. `CosmicCompConfig`
// (cosmic-comp 1.0.13) carries autotile, active_hint, focus_follows_cursor,
// edge_snap_threshold, input, xkb, workspaces, zoom and appearance — and
// nothing about maximization. The behaviour is not COSMIC choosing to
// maximize: the client asks and the compositor obeys. cosmic-comp sets
// `pending.maximized = true` from the client's xdg-toplevel `set_maximized`
// (src/wayland/handlers/xdg_shell/mod.rs) and honours it at map time
// (`if should_be_maximized { self.maximize_request(...) }`, src/shell/mod.rs).
// There is no window rule to refuse it.
//
// This is the COSMIC counterpart to steelbore-niri-unmax, which solves the
// same problem on niri. The two are siblings rather than one program with a
// backend switch, because the transports have nothing in common: niri exposes
// a JSON IPC socket, whereas COSMIC exposes Wayland protocols. Detection
// differs too, and in COSMIC's favour — niri has to infer maximization
// geometrically (full output width, minus gaps), while
// `zcosmic_toplevel_handle_v1.state` reports it explicitly.
//
// Only windows that just appeared are touched, so a maximize the user performs
// later is never reverted. Fullscreen is deliberately left alone: media
// players are expected to launch fullscreen, and unmaximizing one would be
// actively wrong.
//
// Design note (Standard §3.2): the workload is inherently serial — one
// low-rate Wayland event stream (a few window opens per minute) consumed in
// order. This is a single-threaded blocking event loop; concurrency would add
// synchronization overhead and failure modes for no throughput gain.
//
// `mimalloc` (M-MIMALLOC-APPS) is intentionally omitted: the daemon idles on
// an event loop with no allocation hot path, so the dependency is unjustified.
//
// Accessibility (Standard §18): N/A-with-rationale — no interactive surface.
// Output is linear, append-only plain text on stderr (journald adds
// timestamps), no color and no animation, which already satisfies §18.2.1.
//
// Rust guideline compliant 2026-05-18

mod protocol;

use std::collections::HashMap;
use std::time::{Duration, Instant};

use anyhow::{bail, Context as _, Result};
use wayland_client::backend::ObjectId;
use wayland_client::globals::{registry_queue_init, GlobalList, GlobalListContents};
use wayland_client::protocol::wl_registry::WlRegistry;
use wayland_client::{Connection, Dispatch, Proxy as _, QueueHandle};
use wayland_protocols::ext::foreign_toplevel_list::v1::client::{
    ext_foreign_toplevel_handle_v1::ExtForeignToplevelHandleV1,
    ext_foreign_toplevel_list_v1::{self, ExtForeignToplevelListV1},
};

use protocol::info::{
    zcosmic_toplevel_handle_v1::{self, ZcosmicToplevelHandleV1},
    zcosmic_toplevel_info_v1::ZcosmicToplevelInfoV1,
};
use protocol::management::zcosmic_toplevel_manager_v1::ZcosmicToplevelManagerV1;

const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Act only on toplevels younger than this.
///
/// A client that maps and *then* asks to be maximized is the case this daemon
/// exists for, and that second request lands within a second on the clients
/// measured under niri (Chrome, 2026-07-25). Three seconds covers a slow
/// start. Raising it widens the window in which a user's own manual maximize
/// of a fresh window would be reverted once; lowering it risks missing a slow
/// client.
const DEFAULT_GRACE: Duration = Duration::from_secs(3);

/// `zcosmic_toplevel_info_v1` version to request.
///
/// Version 2 is the floor, not a preference: `get_cosmic_toplevel` — the only
/// way to obtain a `zcosmic_toplevel_handle_v1` for an
/// `ext_foreign_toplevel_handle_v1` — was added in 2, and the v1-only
/// `toplevel` event is documented as never emitted to clients binding 2+.
/// cosmic-comp 1.0.13 advertises 3.
const INFO_VERSION: u32 = 2;

/// `zcosmic_toplevel_manager_v1` version to request. `unset_maximized` exists
/// from version 1; nothing here needs the later workspace requests.
const MANAGER_VERSION: u32 = 1;

/// `ext_foreign_toplevel_list_v1` version to request. Version 1 already emits
/// the `toplevel` event this daemon keys on.
const LIST_VERSION: u32 = 1;

/// `zcosmic_toplevel_handle_v1.state` enum discriminants, as they appear on
/// the wire. Taken from cosmic-toplevel-info-unstable-v1.xml; the daemon reads
/// the raw array rather than a generated enum so an unknown future state is
/// ignored instead of aborting the parse.
const STATE_MAXIMIZED: u32 = 0;
const STATE_FULLSCREEN: u32 = 3;

/// What we remember about one toplevel.
#[derive(Debug)]
struct Tracked {
    /// When the cosmic handle was created, which is as close to "when the
    /// window appeared" as this protocol lets us observe.
    first_seen: Instant,
    /// Whether this toplevel is finished with, for either of two reasons:
    /// the daemon has already unmaximized it once, or it existed before the
    /// daemon started.
    ///
    /// Acting at most once keeps the daemon from fighting the user: if they
    /// deliberately maximize a window that is still inside the grace window,
    /// the second maximize stands.
    settled: bool,
}

#[derive(Debug)]
struct App {
    manager: ZcosmicToplevelManagerV1,
    tracked: HashMap<ObjectId, Tracked>,
    grace: Duration,
}

impl App {
    /// Mark every toplevel currently known as settled.
    ///
    /// Called once, after the initial enumeration has been drained. Without
    /// this the daemon would treat every window that was ALREADY OPEN as
    /// having just appeared — because `first_seen` is when the cosmic handle
    /// was created, and for pre-existing windows that is daemon startup, not
    /// window open. A window the user maximized hours ago would then be
    /// unmaximized moments after this daemon starts. Found by running the
    /// daemon against a live COSMIC session; it went unnoticed at first only
    /// because none of the six open windows happened to be maximized.
    fn settle_existing(&mut self) {
        let n = self.tracked.len();
        for entry in self.tracked.values_mut() {
            entry.settled = true;
        }
        eprintln!("steelbore-cosmic-unmax: {n} pre-existing window(s) left alone");
    }
}

/// Decode a Wayland `array` of `uint` into state discriminants.
///
/// Wayland arrays arrive as an opaque byte buffer; an array of `uint` is
/// native-endian 32-bit words. A trailing partial word cannot occur in a
/// well-formed message, so `chunks_exact` simply ignores one rather than
/// guessing at its value.
fn decode_states(bytes: &[u8]) -> Vec<u32> {
    bytes
        .chunks_exact(4)
        .map(|c| u32::from_ne_bytes([c[0], c[1], c[2], c[3]]))
        .collect()
}

impl App {
    /// Handle one `state` event for a tracked toplevel.
    fn on_state(&mut self, handle: &ZcosmicToplevelHandleV1, states: &[u32]) {
        let id = handle.id();
        let Some(entry) = self.tracked.get_mut(&id) else {
            return;
        };

        if entry.settled {
            return;
        }
        if !states.contains(&STATE_MAXIMIZED) {
            return;
        }
        // A fullscreen window is also reported maximized. Unmaximizing it
        // would drop a media player out of fullscreen, which is never what the
        // user asked for.
        if states.contains(&STATE_FULLSCREEN) {
            return;
        }
        if entry.first_seen.elapsed() > self.grace {
            // Older than the grace window: this is the user's own maximize.
            return;
        }

        self.manager.unset_maximized(handle);
        entry.settled = true;
        eprintln!("steelbore-cosmic-unmax: unmaximized a window that opened maximized");
    }
}

impl Dispatch<WlRegistry, GlobalListContents> for App {
    fn event(
        _state: &mut Self,
        _proxy: &WlRegistry,
        _event: <WlRegistry as wayland_client::Proxy>::Event,
        _data: &GlobalListContents,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
    ) {
        // Globals appearing or vanishing mid-session do not affect this
        // daemon: everything it needs is bound once at startup, and a
        // compositor that withdraws them is on its way out anyway.
    }
}

impl Dispatch<ExtForeignToplevelListV1, ZcosmicToplevelInfoV1> for App {
    fn event(
        state: &mut Self,
        _proxy: &ExtForeignToplevelListV1,
        event: <ExtForeignToplevelListV1 as wayland_client::Proxy>::Event,
        info: &ZcosmicToplevelInfoV1,
        _conn: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        if let ext_foreign_toplevel_list_v1::Event::Toplevel { toplevel } = event {
            // Upgrade the ext handle to a cosmic one. The cosmic handle is
            // what carries `state`, and what the manager's requests take.
            // Creating it is also the moment we start the grace clock.
            let cosmic = info.get_cosmic_toplevel(&toplevel, qh, ());
            state.tracked.insert(
                cosmic.id(),
                Tracked {
                    first_seen: Instant::now(),
                    settled: false,
                },
            );
        }
    }

    wayland_client::event_created_child!(App, ExtForeignToplevelListV1, [
        ext_foreign_toplevel_list_v1::EVT_TOPLEVEL_OPCODE => (ExtForeignToplevelHandleV1, ()),
    ]);
}

impl Dispatch<ExtForeignToplevelHandleV1, ()> for App {
    fn event(
        _state: &mut Self,
        _proxy: &ExtForeignToplevelHandleV1,
        _event: <ExtForeignToplevelHandleV1 as wayland_client::Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
    ) {
        // title/app_id/identifier/closed are all irrelevant here: the decision
        // is made entirely from the cosmic handle's `state` event.
    }
}

impl Dispatch<ZcosmicToplevelInfoV1, ()> for App {
    fn event(
        _state: &mut Self,
        _proxy: &ZcosmicToplevelInfoV1,
        _event: <ZcosmicToplevelInfoV1 as wayland_client::Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
    ) {
        // `done` marks a batch of handle changes as atomic. This daemon acts
        // per-toplevel and never compares two toplevels, so batching adds
        // nothing.
    }
}

impl Dispatch<ZcosmicToplevelHandleV1, ()> for App {
    fn event(
        state: &mut Self,
        proxy: &ZcosmicToplevelHandleV1,
        event: <ZcosmicToplevelHandleV1 as wayland_client::Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
    ) {
        match event {
            zcosmic_toplevel_handle_v1::Event::State { state: states } => {
                let decoded = decode_states(&states);
                state.on_state(proxy, &decoded);
            }
            zcosmic_toplevel_handle_v1::Event::Closed => {
                // Stop tracking so the map cannot grow for the life of the
                // session.
                state.tracked.remove(&proxy.id());
            }
            _ => {}
        }
    }
}

impl Dispatch<ZcosmicToplevelManagerV1, ()> for App {
    fn event(
        _state: &mut Self,
        _proxy: &ZcosmicToplevelManagerV1,
        _event: <ZcosmicToplevelManagerV1 as wayland_client::Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
    ) {
        // `capabilities` advertises which optional requests exist.
        // `unset_maximized` is not optional — it is present from version 1 —
        // so there is nothing to gate on.
    }
}

fn usage() {
    println!(
        "steelbore-cosmic-unmax {VERSION}
Un-maximize windows that maximize themselves on open, under COSMIC.

Usage: steelbore-cosmic-unmax [OPTIONS]

Options:
  --grace-ms <MS>  How long after a window appears its maximization counts as
                   self-inflicted rather than the user's. Default: {default}.
  -h, --help       Show this help
  -V, --version    Show the version

Runs until the compositor goes away. Exits 0 with a notice when the COSMIC
toplevel protocols are absent, so it is harmless to spawn from a session that
turns out not to be COSMIC.",
        default = DEFAULT_GRACE.as_millis()
    );
}

fn parse_args() -> Result<Option<Duration>> {
    let mut grace = DEFAULT_GRACE;
    let mut args = std::env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "-h" | "--help" => {
                usage();
                return Ok(None);
            }
            "-V" | "--version" => {
                println!("steelbore-cosmic-unmax {VERSION}");
                return Ok(None);
            }
            "--grace-ms" => {
                let raw = args
                    .next()
                    .context("--grace-ms requires a value in milliseconds")?;
                let ms: u64 = raw
                    .parse()
                    .with_context(|| format!("--grace-ms: not a number: {raw}"))?;
                grace = Duration::from_millis(ms);
            }
            other => bail!("unknown argument '{other}' — try --help"),
        }
    }
    Ok(Some(grace))
}

/// Bind the three globals, or explain which one is missing.
fn bind_globals(
    globals: &GlobalList,
    qh: &QueueHandle<App>,
) -> Result<(
    ZcosmicToplevelManagerV1,
    ZcosmicToplevelInfoV1,
    ExtForeignToplevelListV1,
)> {
    let manager: ZcosmicToplevelManagerV1 = globals
        .bind(qh, MANAGER_VERSION..=MANAGER_VERSION, ())
        .context("zcosmic_toplevel_manager_v1")?;
    let info: ZcosmicToplevelInfoV1 = globals
        .bind(qh, INFO_VERSION..=INFO_VERSION, ())
        .context("zcosmic_toplevel_info_v1")?;
    let list: ExtForeignToplevelListV1 = globals
        .bind(qh, LIST_VERSION..=LIST_VERSION, info.clone())
        .context("ext_foreign_toplevel_list_v1")?;
    Ok((manager, info, list))
}

fn main() -> Result<()> {
    let Some(grace) = parse_args()? else {
        return Ok(());
    };

    let conn = Connection::connect_to_env()
        .context("no Wayland display — this daemon must run inside a Wayland session")?;
    let (globals, mut queue) = registry_queue_init::<App>(&conn)?;
    let qh = queue.handle();

    // Absent globals mean "not COSMIC", which is a normal outcome for a
    // session-startup spawn, not a failure worth a non-zero exit and a
    // restart loop.
    let (manager, _info, _list) = match bind_globals(&globals, &qh) {
        Ok(bound) => bound,
        Err(err) => {
            eprintln!(
                "steelbore-cosmic-unmax: {err:#} not advertised — not a COSMIC session, nothing to do"
            );
            return Ok(());
        }
    };

    let mut app = App {
        manager,
        tracked: HashMap::new(),
        grace,
    };

    // Drain the initial enumeration before arming. ext_foreign_toplevel_list
    // replays every existing toplevel immediately after bind; one roundtrip is
    // the boundary between "was already open" and "opened while we watched".
    queue
        .roundtrip(&mut app)
        .context("initial Wayland roundtrip failed")?;
    app.settle_existing();

    eprintln!(
        "steelbore-cosmic-unmax {VERSION}: watching (grace {} ms)",
        grace.as_millis()
    );

    loop {
        queue
            .blocking_dispatch(&mut app)
            .context("Wayland connection lost")?;
    }
}
