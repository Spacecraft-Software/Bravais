// SPDX-License-Identifier: GPL-3.0-or-later
//
// The `run` command: one poll(2) loop over every pointing device, the
// inotify watch on /dev/input and the sysfs `active` attribute, turning
// frames into console ioctls on the foreground VT.

use std::fs::File;
use std::io::{self, Read as _, Seek as _, SeekFrom};
use std::mem::MaybeUninit;
use std::os::fd::AsFd as _;
use std::path::Path;
use std::time::{Duration, Instant};

use rustix::event::{poll, PollFd, PollFlags};
use rustix::fs::inotify;

use crate::console::{self, Cell, Vt};
use crate::input::{self, Button, Frame, Input};
use crate::output::{AppError, Exit, Level, Out};

/// Directory watched for input devices appearing and disappearing.
pub const INPUT_DIR: &str = "/dev/input";

/// Parent of [`INPUT_DIR`]. The kernel creates /dev/input with the first
/// input device, which can be after this service starts (slow USB
/// enumeration), so /dev is watched until it exists.
const DEV_DIR: &str = "/dev";

/// Sysfs attribute naming the foreground VT (`tty3`). It supports `poll(2)`
/// with `POLLPRI`, raised on every console switch.
pub const ACTIVE_VT: &str = "/sys/class/tty/tty0/active";

/// Clicks closer together than this, on the same cell, count as a double or
/// triple click.
const MULTI_CLICK: Duration = Duration::from_millis(400);

/// Selection state on the foreground VT.
#[derive(Debug, Default)]
struct Selection {
    anchor: Option<Cell>,
    mode: u16,
    left_down: bool,
    right_down: bool,
    last_click: Option<(Instant, Cell)>,
    clicks: u8,
}

/// The pointer position in cells, as a fraction so slow motion accumulates.
#[derive(Debug)]
struct Pointer {
    x: f64,
    y: f64,
    placed: bool,
}

#[derive(Debug)]
struct Daemon {
    out: Out,
    speed: f64,
    inputs: Vec<Input>,
    active_file: File,
    vt: Option<Vt>,
    pointer: Pointer,
    sel: Selection,
    /// The last console error logged, so a persistent failure is logged once
    /// rather than on every pointer event.
    last_error: Option<String>,
}

/// Reads the foreground VT number from the sysfs `active` attribute.
pub fn read_active(file: &mut File) -> io::Result<u16> {
    let mut text = String::new();
    file.seek(SeekFrom::Start(0))?;
    file.read_to_string(&mut text)?;
    text.trim()
        .strip_prefix("tty")
        .and_then(|n| n.parse().ok())
        .ok_or_else(|| {
            io::Error::new(
                io::ErrorKind::InvalidData,
                format!("unexpected {ACTIVE_VT} contents {text:?}"),
            )
        })
}

/// The `run` command. Returns the process exit code.
pub fn run(out: Out, speed: f64) -> i32 {
    const CMD: &str = "steelbore-reticle run";
    // TIOCL_SETSEL and TIOCL_PASTESEL need CAP_SYS_ADMIN (Linux >= 6.7).
    // Checked up front so a missing capability is one clear error at start
    // rather than a silent pointer that never draws.
    let has_cap = rustix::thread::capabilities(None).is_ok_and(|c| {
        c.effective
            .contains(rustix::thread::CapabilitySet::SYS_ADMIN)
    });
    if !has_cap {
        return out.fail(&AppError::new(
            "PERMISSION_DENIED",
            Exit::Permission,
            "CAP_SYS_ADMIN is required to draw the pointer and set the selection",
            "systemctl status steelbore-reticle   # the system service runs it with that capability",
            CMD,
        ));
    }
    let active_file =
        match File::open(ACTIVE_VT) {
            Ok(f) => f,
            Err(e) => return out.fail(&AppError::new(
                "NOT_FOUND",
                Exit::NotFound,
                format!("cannot open {ACTIVE_VT}: {e}"),
                "ls /sys/class/tty/tty0   # a kernel without virtual consoles has no VT to serve",
                CMD,
            )),
        };
    let daemon = Daemon {
        out,
        speed,
        inputs: Vec::new(),
        active_file,
        vt: None,
        pointer: Pointer {
            x: 0.0,
            y: 0.0,
            placed: false,
        },
        sel: Selection::default(),
        last_error: None,
    };
    match daemon.run() {
        Ok(()) => Exit::Success as i32,
        Err(e) => out.fail(&e),
    }
}

impl Daemon {
    /// Opens every pointing device under /dev/input not already open.
    fn scan(&mut self) {
        for input in input::scan(Path::new(INPUT_DIR)) {
            if self.inputs.iter().any(|i| i.path == input.path) {
                continue;
            }
            self.out.say(
                Level::Info,
                &format!(
                    "using {} ({}) as a {}",
                    input::name_of(&input),
                    input.path.display(),
                    input.kind.as_str()
                ),
            );
            self.inputs.push(input);
        }
    }

    /// Re-reads the foreground VT and reopens it if it changed.
    fn refresh_vt(&mut self) -> io::Result<()> {
        let number = read_active(&mut self.active_file)?;
        if self.vt.as_ref().is_some_and(|vt| vt.number == number) {
            return Ok(());
        }
        // A console switch clears the kernel's selection highlight; an anchor
        // or a held button from the previous VT means nothing here.
        self.sel = Selection::default();
        self.vt = None;
        self.vt = Some(Vt::open(number)?);
        Ok(())
    }

    /// Logs a console error once per distinct message.
    fn report(&mut self, result: io::Result<()>) {
        match result {
            Ok(()) => self.last_error = None,
            Err(e) => {
                let msg = e.to_string();
                if self.last_error.as_deref() != Some(msg.as_str()) {
                    self.out.say(Level::Warn, &format!("console: {msg}"));
                    self.last_error = Some(msg);
                }
            }
        }
    }

    fn handle(&mut self, frame: &Frame) -> io::Result<()> {
        let Some(vt) = &self.vt else {
            return Ok(());
        };
        if !vt.is_text()? {
            self.sel.left_down = false;
            self.sel.right_down = false;
            return Ok(());
        }
        let (cols, rows) = vt.size()?;
        if cols == 0 || rows == 0 {
            return Ok(());
        }
        let max_x = f64::from(cols - 1);
        let max_y = f64::from(rows - 1);
        let before = cell_of(&self.pointer);
        let was_placed = self.pointer.placed;
        if !was_placed {
            self.pointer = Pointer {
                x: max_x / 2.0,
                y: max_y / 2.0,
                placed: true,
            };
        }
        if let Some((fx, fy)) = frame.at {
            self.pointer.x = fx * f64::from(cols);
            self.pointer.y = fy * f64::from(rows);
        }
        self.pointer.x = (self.pointer.x + frame.dx).clamp(0.0, max_x);
        self.pointer.y = (self.pointer.y + frame.dy).clamp(0.0, max_y);
        let cell = cell_of(&self.pointer);
        let reporting = vt.mouse_reporting()?;
        let sel = &mut self.sel;

        if cell != before || !was_placed {
            match sel.anchor {
                Some(anchor) if reporting == 0 && (sel.left_down || sel.right_down) => {
                    vt.set_selection(anchor, cell, sel.mode)?;
                }
                _ => vt.set_selection(cell, cell, console::SEL_POINTER)?,
            }
        }

        for &(button, down) in &frame.buttons {
            if reporting != 0 {
                if down {
                    let mode = console::SEL_MOUSE_REPORT + button.report_index();
                    vt.set_selection(cell, cell, mode)?;
                } else if reporting == 2 {
                    vt.set_selection(cell, cell, console::SEL_MOUSE_REPORT + 3)?;
                }
                continue;
            }
            match (button, down) {
                (Button::Left, true) => {
                    let repeat = sel
                        .last_click
                        .is_some_and(|(at, c)| c == cell && at.elapsed() < MULTI_CLICK);
                    sel.clicks = if repeat { sel.clicks % 3 + 1 } else { 1 };
                    sel.last_click = Some((Instant::now(), cell));
                    sel.anchor = Some(cell);
                    sel.left_down = true;
                    sel.mode = match sel.clicks {
                        2 => console::SEL_WORD,
                        3 => console::SEL_LINE,
                        _ => console::SEL_CHAR,
                    };
                    if sel.clicks > 1 {
                        vt.set_selection(cell, cell, sel.mode)?;
                    }
                }
                (Button::Left, false) => sel.left_down = false,
                (Button::Middle, true) => vt.paste()?,
                (Button::Right, true) => {
                    sel.right_down = true;
                    if let Some(anchor) = sel.anchor {
                        vt.set_selection(anchor, cell, sel.mode)?;
                    }
                }
                (Button::Right, false) => sel.right_down = false,
                (Button::Middle, false) => {}
            }
        }
        Ok(())
    }

    #[expect(
        clippy::result_large_err,
        reason = "returned once, at exit; boxing would only add an allocation to the error path"
    )]
    fn run(mut self) -> Result<(), AppError> {
        const CMD: &str = "steelbore-reticle run";
        let startup = |what: String, e: rustix::io::Errno| {
            AppError::new(
                "STARTUP_FAILED",
                Exit::Failure,
                format!("{what}: {e}"),
                "journalctl -u steelbore-reticle -b   # the service log shows what failed",
                CMD,
            )
        };
        let watch = inotify::init(inotify::CreateFlags::CLOEXEC | inotify::CreateFlags::NONBLOCK)
            .map_err(|e| startup("inotify_init".to_owned(), e))?;
        inotify::add_watch(&watch, DEV_DIR, inotify::WatchFlags::CREATE)
            .map_err(|e| startup(format!("watching {DEV_DIR}"), e))?;
        let mut input_watched =
            watch_input_dir(&watch).map_err(|e| startup(format!("watching {INPUT_DIR}"), e))?;
        self.scan();
        let first = self.refresh_vt();
        self.report(first);
        if self.inputs.is_empty() {
            self.out.say(
                Level::Warn,
                "no pointing device yet; waiting for one to appear",
            );
        }
        self.out.say(Level::Ok, "console mouse running");

        let mut inotify_buf = [MaybeUninit::<u8>::uninit(); 4096];
        loop {
            let (watch_ready, vt_ready, ready) = {
                let mut fds = Vec::with_capacity(self.inputs.len() + 2);
                fds.push(PollFd::new(&watch, PollFlags::IN));
                fds.push(PollFd::new(
                    &self.active_file,
                    PollFlags::PRI | PollFlags::ERR,
                ));
                for input in &self.inputs {
                    fds.push(PollFd::from_borrowed_fd(input.dev.as_fd(), PollFlags::IN));
                }
                match poll(&mut fds, None) {
                    Ok(_) => {}
                    Err(rustix::io::Errno::INTR) => continue,
                    Err(e) => return Err(startup("poll".to_owned(), e)),
                }
                let ready: Vec<bool> = fds[2..].iter().map(|f| !f.revents().is_empty()).collect();
                (
                    !fds[0].revents().is_empty(),
                    !fds[1].revents().is_empty(),
                    ready,
                )
            };

            if vt_ready {
                let result = self.refresh_vt();
                self.report(result);
            }

            let mut gone = Vec::new();
            let mut frames = Vec::new();
            for (i, input) in self.inputs.iter_mut().enumerate() {
                if !ready.get(i).copied().unwrap_or(false) {
                    continue;
                }
                match input.read(self.speed) {
                    Ok(mut f) => frames.append(&mut f),
                    Err(_) => gone.push(i),
                }
            }
            for i in gone.into_iter().rev() {
                let input = self.inputs.remove(i);
                self.out
                    .say(Level::Info, &format!("{} went away", input.path.display()));
            }
            for frame in &frames {
                let mut result = self.handle(frame);
                if result
                    .as_ref()
                    .is_err_and(|e| e.raw_os_error() == Some(rustix::io::Errno::IO.raw_os_error()))
                {
                    // getty and login hang the VT up (vhangup) on every login
                    // and logout, which leaves an already-open descriptor
                    // returning EIO forever. Reopen and replay the frame; the
                    // first ioctl in `handle` fails before the pointer moves,
                    // so the replay does not move it twice.
                    self.vt = None;
                    result = self.refresh_vt().and_then(|()| self.handle(frame));
                }
                self.report(result);
            }

            if watch_ready {
                let mut reader = inotify::Reader::new(&watch, &mut inotify_buf);
                while reader.next().is_ok() {}
                if !input_watched {
                    match watch_input_dir(&watch) {
                        Ok(w) => input_watched = w,
                        Err(e) => return Err(startup(format!("watching {INPUT_DIR}"), e)),
                    }
                }
                self.scan();
            }
        }
    }
}

/// Adds the inotify watch on [`INPUT_DIR`]. `Ok(false)` means it does not
/// exist yet; the /dev watch wakes the loop when it is created.
fn watch_input_dir(watch: &impl std::os::fd::AsFd) -> Result<bool, rustix::io::Errno> {
    match inotify::add_watch(
        watch,
        INPUT_DIR,
        inotify::WatchFlags::CREATE | inotify::WatchFlags::ATTRIB,
    ) {
        Ok(_) => Ok(true),
        Err(rustix::io::Errno::NOENT) => Ok(false),
        Err(e) => Err(e),
    }
}

#[allow(
    clippy::cast_possible_truncation,
    clippy::cast_sign_loss,
    reason = "the pointer is clamped to [0, cols-1] x [0, rows-1], both u16"
)]
fn cell_of(pointer: &Pointer) -> Cell {
    Cell {
        col: pointer.x.floor() as u16,
        row: pointer.y.floor() as u16,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cell_floors_the_fraction() {
        let p = Pointer {
            x: 3.9,
            y: 0.2,
            placed: true,
        };
        assert_eq!(cell_of(&p), Cell { col: 3, row: 0 });
    }
}
