// SPDX-License-Identifier: GPL-3.0-or-later
//
// Pointing devices: which evdev nodes count as one, and how each turns its
// events into a `Frame` (motion in console cells plus button transitions).
// Devices are read, never grabbed, so a compositor on another VT sees every
// event as before.

use std::io;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

use evdev::{
    AbsoluteAxisCode, Device, EventSummary, KeyCode, PropType, RelativeAxisCode,
    SynchronizationCode,
};

/// Relative-device counts per column and per row at `--speed 1`. A console
/// cell is about twice as tall as it is wide, hence the 1:2 ratio.
const COUNTS_PER_COL: f64 = 10.0;
const COUNTS_PER_ROW: f64 = 20.0;

/// Touchpad travel in millimetres per column and per row at `--speed 1`.
const MM_PER_COL: f64 = 0.6;
const MM_PER_ROW: f64 = 1.2;

/// A touch shorter and stiller than these is a tap.
const TAP_TIME: Duration = Duration::from_millis(180);
const TAP_TRAVEL_MM: f64 = 1.5;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Button {
    Left,
    Middle,
    Right,
}

impl Button {
    fn from_key(code: KeyCode) -> Option<Self> {
        match code {
            KeyCode::BTN_LEFT => Some(Self::Left),
            KeyCode::BTN_MIDDLE => Some(Self::Middle),
            KeyCode::BTN_RIGHT => Some(Self::Right),
            _ => None,
        }
    }

    /// Button number in the kernel's mouse report (3 means release).
    pub fn report_index(self) -> u16 {
        match self {
            Self::Left => 0,
            Self::Middle => 1,
            Self::Right => 2,
        }
    }
}

/// What one device produced between two `SYN_REPORT`s: relative motion in
/// cells or an absolute position, and button transitions in order.
#[derive(Debug, Default)]
pub struct Frame {
    pub dx: f64,
    pub dy: f64,
    /// An absolute position as a fraction of the screen, `0.0..=1.0` each way.
    pub at: Option<(f64, f64)>,
    pub buttons: Vec<(Button, bool)>,
}

impl Frame {
    fn is_empty(&self) -> bool {
        self.dx == 0.0 && self.dy == 0.0 && self.at.is_none() && self.buttons.is_empty()
    }
}

/// Per-device state for an absolute pointer: a graphics tablet in mouse
/// mode, or the USB tablet a virtual machine's display attaches.
#[derive(Debug)]
pub struct Absolute {
    range_x: (i32, i32),
    range_y: (i32, i32),
    pos: (i32, i32),
}

impl Absolute {
    fn new(dev: &Device) -> Self {
        let mut range_x = (0, 1);
        let mut range_y = (0, 1);
        if let Ok(infos) = dev.get_absinfo() {
            for (axis, info) in infos {
                match axis {
                    AbsoluteAxisCode::ABS_X => range_x = (info.minimum(), info.maximum()),
                    AbsoluteAxisCode::ABS_Y => range_y = (info.minimum(), info.maximum()),
                    _ => {}
                }
            }
        }
        Self {
            range_x,
            range_y,
            pos: (range_x.0, range_y.0),
        }
    }

    fn fraction(v: i32, (min, max): (i32, i32)) -> f64 {
        let span = f64::from(max - min).max(1.0);
        (f64::from(v - min) / span).clamp(0.0, 1.0)
    }

    fn at(&self) -> (f64, f64) {
        (
            Self::fraction(self.pos.0, self.range_x),
            Self::fraction(self.pos.1, self.range_y),
        )
    }
}

/// Per-device state for a touchpad.
#[derive(Debug)]
pub struct Touchpad {
    units_per_mm: (f64, f64),
    pos: (i32, i32),
    last: Option<(i32, i32)>,
    touching: bool,
    released: bool,
    fingers: u8,
    max_fingers: u8,
    touch_start: Instant,
    travelled_mm: f64,
    clicked: bool,
    held: Option<Button>,
}

impl Touchpad {
    fn new(dev: &Device) -> Self {
        let mut units_per_mm = (0.0, 0.0);
        if let Ok(infos) = dev.get_absinfo() {
            for (axis, info) in infos {
                // A pad that reports no resolution is assumed to be about
                // 100 x 60 mm, the size of a typical laptop touchpad.
                let (fallback_mm, slot) = match axis {
                    AbsoluteAxisCode::ABS_X => (100.0, &mut units_per_mm.0),
                    AbsoluteAxisCode::ABS_Y => (60.0, &mut units_per_mm.1),
                    _ => continue,
                };
                *slot = if info.resolution() > 0 {
                    f64::from(info.resolution())
                } else {
                    f64::from(info.maximum() - info.minimum()).max(1.0) / fallback_mm
                };
            }
        }
        Self {
            units_per_mm,
            pos: (0, 0),
            last: None,
            touching: false,
            released: false,
            fingers: 0,
            max_fingers: 0,
            touch_start: Instant::now(),
            travelled_mm: 0.0,
            clicked: false,
            held: None,
        }
    }

    fn event(&mut self, event: &EventSummary, frame: &mut Frame) {
        match *event {
            EventSummary::AbsoluteAxis(_, AbsoluteAxisCode::ABS_X, v) => self.pos.0 = v,
            EventSummary::AbsoluteAxis(_, AbsoluteAxisCode::ABS_Y, v) => self.pos.1 = v,
            EventSummary::Key(_, KeyCode::BTN_TOUCH, 1) => {
                self.touching = true;
                self.last = None;
                self.max_fingers = self.fingers.max(1);
                self.touch_start = Instant::now();
                self.travelled_mm = 0.0;
                self.clicked = false;
            }
            EventSummary::Key(_, KeyCode::BTN_TOUCH, 0) => {
                self.touching = false;
                self.released = true;
            }
            EventSummary::Key(_, code, value) if finger_count(code).is_some() => {
                if value == 1 {
                    self.fingers = finger_count(code).unwrap_or(1);
                    self.max_fingers = self.max_fingers.max(self.fingers);
                }
                // The emulated single-touch position jumps when a finger is
                // added or lifted; restart the delta instead of following it.
                self.last = None;
            }
            // Clickpad: the whole pad is one button, and the number of fingers
            // on it picks which one (libinput's "clickfinger").
            EventSummary::Key(_, KeyCode::BTN_LEFT, 1) => {
                self.clicked = true;
                let button = match self.fingers {
                    2 => Button::Right,
                    3 => Button::Middle,
                    _ => Button::Left,
                };
                self.held = Some(button);
                frame.buttons.push((button, true));
            }
            EventSummary::Key(_, KeyCode::BTN_LEFT, 0) => {
                if let Some(button) = self.held.take() {
                    frame.buttons.push((button, false));
                }
            }
            EventSummary::Key(_, code, value) if value != 2 => {
                if let Some(button) = Button::from_key(code) {
                    self.clicked = true;
                    frame.buttons.push((button, value == 1));
                }
            }
            _ => {}
        }
    }

    fn sync(&mut self, frame: &mut Frame, speed: f64) {
        if self.touching && (self.fingers <= 1 || self.held.is_some()) {
            if let Some(last) = self.last {
                let mm_x = f64::from(self.pos.0 - last.0) / self.units_per_mm.0;
                let mm_y = f64::from(self.pos.1 - last.1) / self.units_per_mm.1;
                self.travelled_mm += mm_x.hypot(mm_y);
                frame.dx += mm_x * speed / MM_PER_COL;
                frame.dy += mm_y * speed / MM_PER_ROW;
            }
            self.last = Some(self.pos);
        }
        if self.released {
            self.released = false;
            self.last = None;
            let is_tap = !self.clicked
                && self.touch_start.elapsed() < TAP_TIME
                && self.travelled_mm < TAP_TRAVEL_MM;
            if is_tap {
                let button = match self.max_fingers {
                    2 => Button::Right,
                    3 => Button::Middle,
                    _ => Button::Left,
                };
                frame.buttons.push((button, true));
                frame.buttons.push((button, false));
            }
            self.max_fingers = 0;
        }
    }
}

fn finger_count(code: KeyCode) -> Option<u8> {
    match code {
        KeyCode::BTN_TOOL_FINGER => Some(1),
        KeyCode::BTN_TOOL_DOUBLETAP => Some(2),
        KeyCode::BTN_TOOL_TRIPLETAP => Some(3),
        KeyCode::BTN_TOOL_QUADTAP => Some(4),
        _ => None,
    }
}

#[derive(Debug)]
pub enum Kind {
    /// A mouse, a `TrackPoint`, or xremap's virtual device: relative motion.
    Relative,
    Touchpad(Touchpad),
    /// A tablet in mouse mode or a virtual machine's USB tablet.
    Absolute(Absolute),
}

impl Kind {
    pub const fn as_str(&self) -> &'static str {
        match self {
            Self::Relative => "pointer",
            Self::Touchpad(_) => "touchpad",
            Self::Absolute(_) => "tablet",
        }
    }
}

#[derive(Debug)]
pub struct Input {
    pub dev: Device,
    pub path: PathBuf,
    pub kind: Kind,
    frame: Frame,
}

impl Input {
    /// Opens `path` and keeps it only if it is a pointing device this daemon
    /// understands: a relative pointer, a touchpad, or an absolute pointer
    /// with a left button. Touchscreens (`BTN_TOUCH` and no `BTN_LEFT`) and
    /// pens are skipped.
    pub fn open(path: &Path) -> Option<Self> {
        let dev = Device::open(path).ok()?;
        let keys = dev.supported_keys()?;
        let kind = if dev.supported_relative_axes().is_some_and(|rel| {
            rel.contains(RelativeAxisCode::REL_X) && rel.contains(RelativeAxisCode::REL_Y)
        }) && keys.contains(KeyCode::BTN_LEFT)
        {
            Kind::Relative
        } else if dev.supported_absolute_axes().is_some_and(|abs| {
            abs.contains(AbsoluteAxisCode::ABS_X) && abs.contains(AbsoluteAxisCode::ABS_Y)
        }) && keys.contains(KeyCode::BTN_TOUCH)
            && keys.contains(KeyCode::BTN_TOOL_FINGER)
            && !dev.properties().contains(PropType::DIRECT)
        {
            Kind::Touchpad(Touchpad::new(&dev))
        } else if dev.supported_absolute_axes().is_some_and(|abs| {
            abs.contains(AbsoluteAxisCode::ABS_X) && abs.contains(AbsoluteAxisCode::ABS_Y)
        }) && keys.contains(KeyCode::BTN_LEFT)
            && !keys.contains(KeyCode::BTN_TOOL_FINGER)
            && !keys.contains(KeyCode::BTN_TOOL_PEN)
        {
            Kind::Absolute(Absolute::new(&dev))
        } else {
            return None;
        };
        dev.set_nonblocking(true).ok()?;
        Some(Self {
            dev,
            path: path.to_owned(),
            kind,
            frame: Frame::default(),
        })
    }

    /// Drains the device. Returns the frames completed by a `SYN_REPORT`, or
    /// an error when the device is gone.
    pub fn read(&mut self, speed: f64) -> io::Result<Vec<Frame>> {
        let mut done = Vec::new();
        let events = match self.dev.fetch_events() {
            Ok(events) => events.collect::<Vec<_>>(),
            Err(e) if e.kind() == io::ErrorKind::WouldBlock => return Ok(done),
            Err(e) => return Err(e),
        };
        for event in events {
            let summary = event.destructure();
            if let EventSummary::Synchronization(_, SynchronizationCode::SYN_REPORT, _) = summary {
                if let Kind::Touchpad(pad) = &mut self.kind {
                    pad.sync(&mut self.frame, speed);
                }
                let frame = std::mem::take(&mut self.frame);
                if !frame.is_empty() {
                    done.push(frame);
                }
                continue;
            }
            match &mut self.kind {
                Kind::Touchpad(pad) => pad.event(&summary, &mut self.frame),
                Kind::Absolute(abs) => match summary {
                    EventSummary::AbsoluteAxis(_, AbsoluteAxisCode::ABS_X, v) => {
                        abs.pos.0 = v;
                        self.frame.at = Some(abs.at());
                    }
                    EventSummary::AbsoluteAxis(_, AbsoluteAxisCode::ABS_Y, v) => {
                        abs.pos.1 = v;
                        self.frame.at = Some(abs.at());
                    }
                    EventSummary::Key(_, code, value) if value != 2 => {
                        if let Some(button) = Button::from_key(code) {
                            self.frame.buttons.push((button, value == 1));
                        }
                    }
                    _ => {}
                },
                Kind::Relative => match summary {
                    EventSummary::RelativeAxis(_, RelativeAxisCode::REL_X, v) => {
                        self.frame.dx += f64::from(v) * speed / COUNTS_PER_COL;
                    }
                    EventSummary::RelativeAxis(_, RelativeAxisCode::REL_Y, v) => {
                        self.frame.dy += f64::from(v) * speed / COUNTS_PER_ROW;
                    }
                    EventSummary::Key(_, code, value) if value != 2 => {
                        if let Some(button) = Button::from_key(code) {
                            self.frame.buttons.push((button, value == 1));
                        }
                    }
                    _ => {}
                },
            }
        }
        Ok(done)
    }
}

/// Every pointing device under `dir`, sorted by path.
pub fn scan(dir: &Path) -> Vec<Input> {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return Vec::new();
    };
    let mut paths: Vec<PathBuf> = entries
        .filter_map(|e| e.ok().map(|e| e.path()))
        .filter(|p| {
            p.file_name()
                .and_then(|n| n.to_str())
                .is_some_and(|n| n.starts_with("event"))
        })
        .collect();
    paths.sort();
    paths.iter().filter_map(|p| Input::open(p)).collect()
}

/// The display name of a device, for logs and `device list`.
pub fn name_of(input: &Input) -> &str {
    input.dev.name().unwrap_or("unnamed device")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn absolute_positions_are_fractions_of_the_range() {
        let abs = Absolute {
            range_x: (0, 32767),
            range_y: (0, 32767),
            pos: (32767, 0),
        };
        assert_eq!(abs.at(), (1.0, 0.0));
        assert!((Absolute::fraction(-5, (0, 10))).abs() < f64::EPSILON);
    }

    #[test]
    fn finger_tools_map_to_counts() {
        assert_eq!(finger_count(KeyCode::BTN_TOOL_DOUBLETAP), Some(2));
        assert_eq!(finger_count(KeyCode::BTN_LEFT), None);
    }

    #[test]
    fn a_tap_without_travel_is_a_left_click() {
        let mut pad = Touchpad {
            units_per_mm: (10.0, 10.0),
            pos: (0, 0),
            last: None,
            touching: false,
            released: false,
            fingers: 0,
            max_fingers: 0,
            touch_start: Instant::now(),
            travelled_mm: 0.0,
            clicked: false,
            held: None,
        };
        let mut frame = Frame::default();
        let ev = |code, value| {
            EventSummary::from(evdev::InputEvent::new(evdev::EventType::KEY.0, code, value))
        };
        pad.event(&ev(KeyCode::BTN_TOOL_FINGER.0, 1), &mut frame);
        pad.event(&ev(KeyCode::BTN_TOUCH.0, 1), &mut frame);
        pad.sync(&mut frame, 1.0);
        pad.event(&ev(KeyCode::BTN_TOUCH.0, 0), &mut frame);
        pad.sync(&mut frame, 1.0);
        assert_eq!(
            frame.buttons,
            vec![(Button::Left, true), (Button::Left, false)]
        );
    }

    #[test]
    fn two_finger_clickpad_press_is_a_right_click() {
        let mut pad = Touchpad {
            units_per_mm: (10.0, 10.0),
            pos: (0, 0),
            last: None,
            touching: true,
            released: false,
            fingers: 2,
            max_fingers: 2,
            touch_start: Instant::now(),
            travelled_mm: 0.0,
            clicked: false,
            held: None,
        };
        let mut frame = Frame::default();
        let ev = |value| {
            EventSummary::from(evdev::InputEvent::new(
                evdev::EventType::KEY.0,
                KeyCode::BTN_LEFT.0,
                value,
            ))
        };
        pad.event(&ev(1), &mut frame);
        pad.event(&ev(0), &mut frame);
        assert_eq!(
            frame.buttons,
            vec![(Button::Right, true), (Button::Right, false)]
        );
    }
}
