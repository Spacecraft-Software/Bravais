// SPDX-License-Identifier: GPL-3.0-or-later
//
// The kernel console interface: one character device per VT and the
// TIOCLINUX subcodes this tool uses (include/uapi/linux/tiocl.h). Every
// `unsafe` block in the crate is in this file, one per ioctl shape.

use std::ffi::c_int;
use std::fs::{File, OpenOptions};
use std::io;
use std::os::unix::fs::OpenOptionsExt as _;

use rustix::ioctl::{ioctl, Getter, Opcode, Updater};

const TIOCLINUX: Opcode = 0x541C;
const KDGETMODE: Opcode = 0x4B3B;
const KD_TEXT: c_int = 0;

const TIOCL_SETSEL: u8 = 2;
const TIOCL_PASTESEL: u8 = 3;
const TIOCL_GETMOUSEREPORTING: u8 = 7;

pub const SEL_CHAR: u16 = 0;
pub const SEL_WORD: u16 = 1;
pub const SEL_LINE: u16 = 2;
pub const SEL_POINTER: u16 = 3;
pub const SEL_MOUSE_REPORT: u16 = 16;

/// A character cell, zero-based.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Cell {
    pub col: u16,
    pub row: u16,
}

/// An open VT (`/dev/ttyN`).
///
/// Each VT is opened by number rather than through `/dev/tty0`, because
/// `/dev/tty0` is bound to whichever VT was in the foreground when it was
/// OPENED, and `TIOCL_PASTESEL` and the mouse report write into the VT the
/// descriptor refers to. Write-only with `O_NOCTTY`: the daemon never reads
/// the VT and must never become its controlling process. The unit's
/// `tty` group gives write access to a VT a user has logged in on, whose
/// node is then owned by that user.
#[derive(Debug)]
pub struct Vt {
    file: File,
}

impl Vt {
    pub fn open(number: u16) -> io::Result<Self> {
        let file = OpenOptions::new()
            .write(true)
            .custom_flags(rustix::fs::OFlags::NOCTTY.bits().cast_signed())
            .open(format!("/dev/tty{number}"))?;
        Ok(Self { file })
    }

    /// True when the VT shows text. A compositor or the X server puts its
    /// VT in `KD_GRAPHICS`, where the kernel draws nothing.
    pub fn is_text(&self) -> io::Result<bool> {
        // SAFETY: KDGETMODE writes one `int` (the VT's `vc_mode`) through
        // the pointer, which is exactly what `Getter<_, c_int>` provides.
        let mode = unsafe { ioctl(&self.file, Getter::<KDGETMODE, c_int>::new()) }?;
        Ok(mode == KD_TEXT)
    }

    /// Columns and rows, re-read on every use so a font change is followed.
    pub fn size(&self) -> io::Result<(u16, u16)> {
        let ws = rustix::termios::tcgetwinsize(&self.file)?;
        Ok((ws.ws_col, ws.ws_row))
    }

    /// `TIOCL_SETSEL` from `from` to `to` in `mode`.
    pub fn set_selection(&self, from: Cell, to: Cell, mode: u16) -> io::Result<()> {
        // `struct tiocl_selection { u16 xs, ys, xe, ye, sel_mode; }`, one-based,
        // starting one byte after the subcode, so deliberately unaligned.
        let mut buf = [0_u8; 11];
        buf[0] = TIOCL_SETSEL;
        let fields = [from.col + 1, from.row + 1, to.col + 1, to.row + 1, mode];
        for (i, value) in fields.iter().enumerate() {
            buf[1 + 2 * i..3 + 2 * i].copy_from_slice(&value.to_ne_bytes());
        }
        self.linux(&mut buf)
    }

    /// `TIOCL_PASTESEL`: push the current selection into this VT's input.
    pub fn paste(&self) -> io::Result<()> {
        self.linux(&mut [TIOCL_PASTESEL])
    }

    /// The mouse-reporting mode a program on the foreground VT asked for:
    /// 0 off, 1 X10 (presses only), 2 X11 (presses and releases).
    pub fn mouse_reporting(&self) -> io::Result<u8> {
        let mut buf = [TIOCL_GETMOUSEREPORTING];
        self.linux(&mut buf)?;
        Ok(buf[0])
    }

    fn linux<const N: usize>(&self, buf: &mut [u8; N]) -> io::Result<()> {
        // SAFETY: TIOCLINUX reads the subcode from `buf[0]`. TIOCL_SETSEL
        // then reads a 10-byte `tiocl_selection` at `buf[1..11]` (callers
        // pass 11 bytes), TIOCL_PASTESEL reads nothing more, and
        // TIOCL_GETMOUSEREPORTING writes one byte to `buf[0]`. No subcode
        // used here touches memory past `N` bytes.
        unsafe { ioctl(&self.file, Updater::<TIOCLINUX, [u8; N]>::new(buf)) }?;
        Ok(())
    }
}
