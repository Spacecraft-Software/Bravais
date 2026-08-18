// SPDX-License-Identifier: GPL-3.0-or-later
//
// steelbore-beacon — publish audio, microphone, backlight and lock-key state as
// JSON lines, one per change, for the Steelbore status bar to consume.
//
// Why this exists: the ThinkPad drives volume, mic mute, brightness and the lock
// keys from function keys that give no on-screen feedback. The bar can show that
// state, but only if something tells it. Polling would work and is what every
// other indicator in the bar does — but a poll fast enough to feel immediate
// after a keypress is also fast enough to wake the CPU pointlessly all day, and
// a poll slow enough to be cheap makes the bar visibly lag the key. Every one of
// these four sources has a real event source, so this daemon blocks on them and
// the bar updates the moment the state actually changes.
//
// Output contract: one JSON object per line on stdout, flushed, emitted on every
// change including the first. Consumed by eww's `deflisten`, which reads exactly
// this shape. Fields are documented on [`State`].
//
// Design note (Standard §3.2): three sources block in three different syscalls —
// the PulseAudio mainloop, `read(2)` on an evdev device, and `poll(2)` on a sysfs
// attribute — and none of them can be waited on through the others. Concurrency
// here is therefore structural rather than a throughput optimization: one thread
// per source, each blocked essentially all the time, funnelling into an `mpsc`
// channel that the main thread serializes into output. A single-threaded design
// would mean either integrating three foreign FD sets into one hand-rolled poll
// loop or reintroducing the polling this daemon exists to avoid. There is no
// shared mutable state and no lock, so there is no contention to measure.
//
// `mimalloc` (M-MIMALLOC-APPS) is intentionally omitted: there is no allocation
// hot path — the daemon idles in a blocking wait and formats one short line per
// state change — so the extra dependency and native build surface are not
// justified. Same reasoning as `steelbore-audio-led`.
//
// Rust guideline compliant 2026-05-18

use std::fs;
use std::io::{Read as _, Seek as _, SeekFrom, Write as _};
use std::path::{Path, PathBuf};
use std::rc::Rc;
use std::sync::mpsc::{self, Sender};
use std::thread;

use anyhow::{anyhow, bail, Context as _, Result};
use evdev::{Device, EventSummary, EventType, LedCode};
use libpulse_binding::callbacks::ListResult;
use libpulse_binding::context::introspect::Introspector;
use libpulse_binding::context::subscribe::{Facility, InterestMaskSet};
use libpulse_binding::context::{Context, FlagSet, State as ContextState};
use libpulse_binding::mainloop::standard::{IterateResult, Mainloop};
use libpulse_binding::volume::Volume;
use rustix::event::{poll, PollFd, PollFlags};

/// libpulse application name, shown in `pactl list clients`.
const APP_NAME: &str = "steelbore-beacon";

/// Display backlight class directory.
///
/// Hardcoded to the Intel panel rather than globbed: this daemon ships with a
/// single-GPU laptop configuration, and picking "the first entry in
/// `/sys/class/backlight`" would silently select the keyboard backlight or a
/// discrete GPU's panel on a machine that has more than one. A machine without
/// this exact path reports brightness as unavailable rather than guessing.
const BACKLIGHT: &str = "/sys/class/backlight/intel_backlight";

/// Percentage reported when the backlight cannot be read at all.
///
/// Chosen over `0` so a missing backlight is visually distinct from a panel
/// genuinely dimmed to its floor; the bar renders it the same either way, but a
/// reader tailing the JSON can tell the two apart.
const BRIGHTNESS_UNAVAILABLE: u8 = 100;

/// Complete published state. Every field is rendered into one JSON line.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
#[expect(
    clippy::struct_excessive_bools,
    reason = "flat mirror of the published JSON object; grouping the flags into \
              sub-structs would change the wire format the bar reads"
)]
struct State {
    /// Default sink volume, percent of `PA_VOLUME_NORM`. May exceed 100.
    volume: u32,
    /// Default sink mute.
    muted: bool,
    /// Default source volume, percent of `PA_VOLUME_NORM`.
    mic: u32,
    /// Default source mute.
    mic_muted: bool,
    /// Display backlight, percent of `max_brightness`.
    brightness: u8,
    /// Caps Lock indicator.
    caps: bool,
    /// Num Lock indicator.
    num: bool,
}

impl State {
    /// Render as a single JSON object.
    ///
    /// Hand-formatted rather than via `serde_json`: every field is a `bool` or an
    /// unsigned integer, so there is no string to escape and no way for this to
    /// emit invalid JSON. A serialization dependency would be pure cost.
    fn to_json(self) -> String {
        format!(
            concat!(
                r#"{{"volume":{},"muted":{},"mic":{},"mic_muted":{},"#,
                r#""brightness":{},"caps":{},"num":{}}}"#
            ),
            self.volume, self.muted, self.mic, self.mic_muted, self.brightness, self.caps, self.num
        )
    }
}

/// One source's contribution to [`State`].
#[derive(Clone, Copy, Debug)]
enum Update {
    /// Default sink: volume percent and mute.
    Sink(u32, bool),
    /// Default source: volume percent and mute.
    Source(u32, bool),
    /// Backlight percent.
    Brightness(u8),
    /// Lock keys: Caps Lock and Num Lock.
    Leds { caps: bool, num: bool },
}

fn main() -> Result<()> {
    let (tx, rx) = mpsc::channel();

    // Seed everything that can be read synchronously, so the first line carries
    // real values rather than defaults that flicker a moment later.
    let mut state = State {
        brightness: read_brightness().unwrap_or(BRIGHTNESS_UNAVAILABLE),
        ..State::default()
    };

    let led_devices = led_capable_devices();
    if led_devices.is_empty() {
        eprintln!("{APP_NAME}: no LED-capable input device found; lock keys will not update");
    }
    if let Some((caps, num)) = led_devices.first().and_then(|p| read_leds(p)) {
        state.caps = caps;
        state.num = num;
    }

    emit(&state)?;

    spawn_audio(tx.clone());
    spawn_backlight(tx.clone());
    for path in led_devices {
        spawn_leds(path, tx.clone());
    }

    // Dropping the last sender ends this loop. Every producer holds a clone and
    // only drops it by dying, so `recv` returning `Err` means every source is
    // gone and there is nothing left to report — exit non-zero so a supervisor
    // restarts us rather than leaving a bar wired to a dead pipe.
    drop(tx);
    for update in rx {
        let next = apply(state, update);
        // Sources re-report unconditionally; suppressing no-op lines keeps the
        // bar from re-rendering on every unrelated PulseAudio event.
        if next != state {
            state = next;
            emit(&state)?;
        }
    }

    bail!("every state source ended")
}

/// Fold one [`Update`] into [`State`].
fn apply(state: State, update: Update) -> State {
    match update {
        Update::Sink(volume, muted) => State {
            volume,
            muted,
            ..state
        },
        Update::Source(mic, mic_muted) => State {
            mic,
            mic_muted,
            ..state
        },
        Update::Brightness(brightness) => State {
            brightness,
            ..state
        },
        Update::Leds { caps, num } => State { caps, num, ..state },
    }
}

/// Write one JSON line to stdout and flush it.
///
/// Flushing per line is the contract: `deflisten` reads line-by-line, so a
/// buffered line is an update the bar never sees.
fn emit(state: &State) -> Result<()> {
    let mut out = std::io::stdout().lock();
    writeln!(out, "{}", state.to_json()).context("failed to write to stdout")?;
    out.flush().context("failed to flush stdout")
}

// ── Audio ───────────────────────────────────────────────────────────────────

/// Watch the default sink and source, reporting volume and mute on every change.
///
/// Runs a standard (not threaded) libpulse mainloop on its own thread: the
/// mainloop and context are `!Send`, so they are created inside the thread and
/// never cross it. Only the `Sender` is moved in.
fn spawn_audio(tx: Sender<Update>) {
    thread::Builder::new()
        .name("audio".to_owned())
        .spawn(move || {
            if let Err(err) = run_audio(&tx) {
                eprintln!("{APP_NAME}: audio watcher stopped: {err}");
            }
        })
        .expect("failed to spawn the audio thread");
}

fn run_audio(tx: &Sender<Update>) -> Result<()> {
    let mut mainloop =
        Mainloop::new().ok_or_else(|| anyhow!("failed to create the pulse mainloop"))?;
    let mut context = Context::new(&mainloop, APP_NAME)
        .ok_or_else(|| anyhow!("failed to create the pulse context"))?;
    context
        .connect(None, FlagSet::NOFLAGS, None)
        .context("failed to connect to the audio server")?;

    wait_until_ready(&mut mainloop, &context)?;

    // The introspector holds its own ref-counted handle to the context, so it can
    // be cloned into the 'static subscribe callback and its nested callbacks.
    let introspect = Rc::new(context.introspect());
    refresh(&introspect, tx.clone());

    let on_event = Rc::clone(&introspect);
    let on_event_tx = tx.clone();
    context.set_subscribe_callback(Some(Box::new(move |facility, _operation, _index| {
        if matches!(
            facility,
            Some(Facility::Sink | Facility::Source | Facility::Server)
        ) {
            refresh(&on_event, on_event_tx.clone());
        }
    })));
    context.subscribe(
        InterestMaskSet::SINK | InterestMaskSet::SOURCE | InterestMaskSet::SERVER,
        |_success| {},
    );

    loop {
        match mainloop.iterate(true) {
            IterateResult::Success(_) => {}
            IterateResult::Quit(_) => bail!("pulse mainloop quit"),
            IterateResult::Err(err) => return Err(anyhow!("pulse mainloop error: {err}")),
        }
    }
}

/// Iterate the mainloop until the context is connected, or fail if it cannot be.
fn wait_until_ready(mainloop: &mut Mainloop, context: &Context) -> Result<()> {
    loop {
        match mainloop.iterate(true) {
            IterateResult::Success(_) => {}
            IterateResult::Quit(_) => bail!("pulse mainloop quit before the context was ready"),
            IterateResult::Err(err) => {
                return Err(anyhow!("pulse mainloop error during connect: {err}"))
            }
        }
        match context.get_state() {
            ContextState::Ready => return Ok(()),
            ContextState::Failed => bail!("connection to the audio server failed"),
            ContextState::Terminated => bail!("connection to the audio server terminated"),
            _ => {}
        }
    }
}

/// Query the current default sink/source and report both.
///
/// The default device can itself change (a headset is plugged in), which is why
/// this resolves the name through `get_server_info` every time rather than
/// caching an index.
fn refresh(introspect: &Rc<Introspector>, tx: Sender<Update>) {
    let for_sink = Rc::clone(introspect);
    let for_source = Rc::clone(introspect);
    let sink_tx = tx.clone();
    introspect.get_server_info(move |info| {
        if let Some(sink) = &info.default_sink_name {
            let tx = sink_tx.clone();
            for_sink.get_sink_info_by_name(sink.as_ref(), move |result| {
                if let ListResult::Item(sink) = result {
                    let _ = tx.send(Update::Sink(percent(sink.volume.avg()), sink.mute));
                }
            });
        }
        if let Some(source) = &info.default_source_name {
            let tx = tx.clone();
            for_source.get_source_info_by_name(source.as_ref(), move |result| {
                if let ListResult::Item(source) = result {
                    let _ = tx.send(Update::Source(percent(source.volume.avg()), source.mute));
                }
            });
        }
    });
}

/// Convert an audio-server volume to a rounded percentage of `PA_VOLUME_NORM`.
///
/// Integer arithmetic throughout — widening to `u64` keeps `value * 100` exact
/// for every `u32` input, so this needs no float and no lossy cast back.
///
/// Not clamped to 100: the audio server permits amplification above normal, and
/// reporting 100 for a sink boosted to 150 would misrepresent it.
fn percent(volume: Volume) -> u32 {
    let normal = u64::from(Volume::NORMAL.0);
    if normal == 0 {
        return 0;
    }
    let value = u64::from(volume.0);
    // + normal/2 rounds to nearest rather than truncating toward zero.
    u32::try_from((value * 100 + normal / 2) / normal).unwrap_or(u32::MAX)
}

// ── Backlight ───────────────────────────────────────────────────────────────

/// Watch the display backlight.
///
/// The backlight class calls `sysfs_notify` on `actual_brightness`, so `poll(2)`
/// with `POLLPRI` wakes on every change — whether it came from a function key,
/// `brightnessctl`, or the kernel's own ambient adjustment. `brightness` is
/// deliberately not the watched attribute: it reports what was *requested*,
/// while `actual_brightness` reports what the panel is actually at.
fn spawn_backlight(tx: Sender<Update>) {
    thread::Builder::new()
        .name("backlight".to_owned())
        .spawn(move || {
            if let Err(err) = run_backlight(&tx) {
                eprintln!("{APP_NAME}: backlight watcher stopped: {err}");
            }
        })
        .expect("failed to spawn the backlight thread");
}

fn run_backlight(tx: &Sender<Update>) -> Result<()> {
    let path = Path::new(BACKLIGHT).join("actual_brightness");
    let mut file =
        fs::File::open(&path).with_context(|| format!("failed to open {}", path.display()))?;

    loop {
        // A sysfs attribute must be read to completion before it will notify
        // again; skipping this read makes poll return immediately, forever.
        let mut buf = String::new();
        file.seek(SeekFrom::Start(0))
            .context("failed to rewind the backlight attribute")?;
        file.read_to_string(&mut buf)
            .context("failed to read the backlight attribute")?;

        if let Some(pct) = read_brightness() {
            let _ = tx.send(Update::Brightness(pct));
        }

        let mut fds = [PollFd::new(&file, PollFlags::PRI | PollFlags::ERR)];
        // `None` blocks indefinitely — there is nothing to time out on.
        poll(&mut fds, None).context("failed to poll the backlight attribute")?;
    }
}

/// Read the backlight as a percentage of its maximum, or `None` if unreadable.
///
/// Integer arithmetic for the same reason as [`percent`]: both operands come
/// from sysfs as integers, so converting to float and back would only introduce
/// a lossy cast.
fn read_brightness() -> Option<u8> {
    let dir = Path::new(BACKLIGHT);
    let current = read_number(&dir.join("actual_brightness"))?;
    let max = read_number(&dir.join("max_brightness"))?;
    if max == 0 {
        return None;
    }
    let pct = (current * 100 + max / 2) / max;
    Some(u8::try_from(pct.min(100)).unwrap_or(100))
}

/// Read a sysfs attribute holding a single unsigned decimal number.
fn read_number(path: &Path) -> Option<u64> {
    fs::read_to_string(path).ok()?.trim().parse().ok()
}

// ── Lock keys ───────────────────────────────────────────────────────────────

/// Every input device that reports LED state.
///
/// Enumerated once at startup. A keyboard hotplugged later is not picked up —
/// tracking that would mean watching udev for a case the built-in keyboard
/// already covers, and the lock state it reports is the same state any attached
/// keyboard toggles.
fn led_capable_devices() -> Vec<PathBuf> {
    evdev::enumerate()
        .filter(|(_, device)| {
            device.supported_events().contains(EventType::LED)
                && device
                    .supported_leds()
                    .is_some_and(|leds| leds.contains(LedCode::LED_CAPSL))
        })
        .map(|(path, _)| path)
        .collect()
}

/// Read the current Caps Lock / Num Lock state from one device.
fn read_leds(path: &Path) -> Option<(bool, bool)> {
    let device = Device::open(path).ok()?;
    let leds = device.get_led_state().ok()?;
    Some((
        leds.contains(LedCode::LED_CAPSL),
        leds.contains(LedCode::LED_NUML),
    ))
}

/// Watch one input device for Caps Lock / Num Lock changes.
///
/// The kernel emits `EV_LED` whenever the lock state changes, no matter which
/// process asked for it, so this is correct under X11 and Wayland alike — unlike
/// `xset q`, which reports Xwayland's idea of the keyboard rather than the
/// compositor's.
fn spawn_leds(path: PathBuf, tx: Sender<Update>) {
    thread::Builder::new()
        .name("leds".to_owned())
        .spawn(move || {
            if let Err(err) = run_leds(&path, &tx) {
                eprintln!(
                    "{APP_NAME}: lock-key watcher for {} stopped: {err}",
                    path.display()
                );
            }
        })
        .expect("failed to spawn the lock-key thread");
}

fn run_leds(path: &Path, tx: &Sender<Update>) -> Result<()> {
    let mut device =
        Device::open(path).with_context(|| format!("failed to open {}", path.display()))?;
    let mut caps = false;
    let mut num = false;
    if let Some((c, n)) = read_leds(path) {
        caps = c;
        num = n;
    }

    loop {
        // Blocks until the kernel has events for this device.
        for event in device
            .fetch_events()
            .with_context(|| format!("failed to read events from {}", path.display()))?
        {
            if let EventSummary::Led(_, code, value) = event.destructure() {
                let on = value != 0;
                match code {
                    LedCode::LED_CAPSL => caps = on,
                    LedCode::LED_NUML => num = on,
                    _ => continue,
                }
                let _ = tx.send(Update::Leds { caps, num });
            }
        }
    }
}
