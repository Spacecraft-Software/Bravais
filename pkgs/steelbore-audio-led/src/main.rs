// SPDX-License-Identifier: GPL-3.0-or-later
//
// steelbore-audio-led — mirror the default audio sink/source mute state onto the
// ThinkPad mute / mic-mute keyboard LEDs.
//
// Why this exists: the kernel `audio-mute` / `audio-micmute` LED triggers follow
// the ALSA *hardware* mute control, but PipeWire mutes the node in *software*, so
// the hardware mute (and therefore the LEDs) never change. This tiny daemon
// watches the audio server's default sink/source mute state and writes the LED
// sysfs `brightness` nodes directly, so the LEDs track the real mute state no
// matter how it was toggled (key bind, GUI, or per-application).
//
// Design note (Standard §3.2): the workload is inherently serial — react to a
// single mute event and write one byte to sysfs — so this is a single-threaded
// libpulse event loop. Concurrency would add synchronization overhead with no
// benefit. Resilience is delegated to systemd: if the audio server restarts and
// the mainloop ends, the process exits non-zero and `Restart=on-failure` brings
// it back, re-reading the initial state on start.
//
// `mimalloc` (M-MIMALLOC-APPS) is intentionally omitted: there is no allocation
// hot path (the daemon idles on an event loop and writes one byte per mute
// change), so the extra dependency and native build surface are not justified.
//
// Rust guideline compliant 2026-05-18

use std::rc::Rc;

use anyhow::Context as _;
use anyhow::{anyhow, bail, Result};
use libpulse_binding::callbacks::ListResult;
use libpulse_binding::context::introspect::Introspector;
use libpulse_binding::context::subscribe::{Facility, InterestMaskSet};
use libpulse_binding::context::{Context, FlagSet, State};
use libpulse_binding::mainloop::standard::{IterateResult, Mainloop};

/// libpulse application name, shown in `pactl list clients`.
const APP_NAME: &str = "steelbore-audio-led";

/// Speaker-mute LED. Provided by `thinkpad_acpi`; its kernel `audio-mute`
/// trigger is set to `none` by the accompanying udev rule so this daemon owns
/// the `brightness` node. `max_brightness` is 1 (on/off only).
const MUTE_LED: &str = "/sys/class/leds/platform::mute/brightness";

/// Mic-mute LED. Same arrangement as [`MUTE_LED`], driven from the default
/// source mute state (the T490s internal mic is a DMIC with no hardware capture
/// switch, so the kernel `audio-micmute` trigger never fires on its own).
const MICMUTE_LED: &str = "/sys/class/leds/platform::micmute/brightness";

fn main() -> Result<()> {
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

    // Seed the LEDs with the current state before listening for changes.
    refresh(&introspect);

    let on_event = Rc::clone(&introspect);
    context.set_subscribe_callback(Some(Box::new(move |facility, _operation, _index| {
        if matches!(
            facility,
            Some(Facility::Sink | Facility::Source | Facility::Server)
        ) {
            refresh(&on_event);
        }
    })));
    context.subscribe(
        InterestMaskSet::SINK | InterestMaskSet::SOURCE | InterestMaskSet::SERVER,
        |_success| {},
    );

    eprintln!("{APP_NAME}: watching sink/source mute state");

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
            State::Ready => return Ok(()),
            State::Failed => bail!("connection to the audio server failed"),
            State::Terminated => bail!("connection to the audio server terminated"),
            _ => {}
        }
    }
}

/// Query the current default sink/source mute state and update both LEDs.
fn refresh(introspect: &Rc<Introspector>) {
    let for_sink = Rc::clone(introspect);
    let for_source = Rc::clone(introspect);
    introspect.get_server_info(move |info| {
        if let Some(sink) = &info.default_sink_name {
            for_sink.get_sink_info_by_name(sink.as_ref(), |result| {
                if let ListResult::Item(sink) = result {
                    set_led(MUTE_LED, sink.mute);
                }
            });
        }
        if let Some(source) = &info.default_source_name {
            for_source.get_source_info_by_name(source.as_ref(), |result| {
                if let ListResult::Item(source) = result {
                    set_led(MICMUTE_LED, source.mute);
                }
            });
        }
    });
}

/// Write the LED `brightness` node: `1` when muted, `0` otherwise.
///
/// Failures are logged but never fatal — a transient sysfs write error must not
/// take the daemon down (for example, during a device-hotplug race).
fn set_led(path: &str, muted: bool) {
    let value = if muted { "1" } else { "0" };
    if let Err(err) = std::fs::write(path, value) {
        eprintln!("{APP_NAME}: failed to write {path}: {err}");
    }
}
