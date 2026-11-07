// SPDX-License-Identifier: GPL-3.0-or-later
//
// Terminal protocols for `bravais-cli` (spacecraft-tui-protocols v1.0.0).
//
// bravais-cli has no TUI, reads no keys and runs no long operation, so of the
// skill's protocols only OSC 52 clipboard write applies: `rewrite --copy` and
// `suggest --copy` put the result on the clipboard, which works over SSH and
// through tmux where `wl-copy` cannot. Nothing here changes terminal state, so
// there is nothing to restore and no probe to run (OSC 52 write has no query).
//
// The same `--term-protocols` / `SPACECRAFT_TERM_PROTOCOLS` syntax as
// `preflight` and `construct` is accepted so one setting serves every
// Spacecraft tool; names this tool does not use are reported as such.
//
// The gate (skill §2.1) is also what decides colour: escape sequences of any
// kind go only to a stream that is a terminal, with no agent or CI variable
// set and a `TERM` that is neither unset nor `dumb`. `mcp` never emits any.

// Rust guideline compliant 2026-05-18

use std::io::{IsTerminal as _, Write as _};

use serde::Serialize;

/// Environment variable holding the protocol override list (skill §2.5).
pub const ENV: &str = "SPACECRAFT_TERM_PROTOCOLS";

/// The skill §2.5 names, in its order.
pub const NAMES: [&str; 7] = [
    "keyboard",
    "graphics",
    "animation",
    "clipboard",
    "clipboard-rich",
    "progress",
    "pointer",
];

/// Largest text sent through OSC 52; 74 000 bytes encodes to 98 668, under
/// the ~100 KB cap several terminals and tmux apply to the whole sequence.
pub const CLIPBOARD_MAX: usize = 74_000;

/// Agent or CI, by presence (CLI Standard §5: a live Claude Code session sets
/// `AI_AGENT=claude-code_2-1-218_agent`, so `== "1"` would miss it). `CI` is
/// the one value-carrying variable: set and not `0` / `false`.
pub fn agent_env() -> bool {
    let set = |v: &str| std::env::var(v).is_ok_and(|s| !s.is_empty());
    set("AI_AGENT")
        || set("AGENT")
        || std::env::var("CI").is_ok_and(|v| !v.is_empty() && v != "0" && v != "false")
}

fn term_ok() -> Result<(), &'static str> {
    match std::env::var("TERM").as_deref() {
        Err(_) | Ok("") => Err("TERM is unset"),
        Ok("dumb") => Err("TERM=dumb"),
        // The kernel console prints the payload of an OSC it does not know.
        Ok("linux") => Err("TERM=linux (kernel console)"),
        Ok(_) => Ok(()),
    }
}

/// Whether a stream may carry colour: a terminal, no agent, `NO_COLOR`
/// unset, `TERM` not `dumb`, and `--no-color` not given.
pub fn color_for(stream_is_tty: bool, no_color_flag: bool) -> bool {
    !no_color_flag
        && stream_is_tty
        && !agent_env()
        && std::env::var_os("NO_COLOR").is_none()
        && std::env::var("TERM")
            .as_deref()
            .is_ok_and(|t| !t.is_empty() && t != "dumb")
}

/// The skill §2.1 gate for sequences sent on stderr (where OSC 52 goes, so
/// stdout stays data only).
fn gate() -> Result<(), &'static str> {
    if agent_env() {
        return Err("agent or CI environment");
    }
    if !std::io::stderr().is_terminal() {
        return Err("stderr is not a terminal");
    }
    term_ok()
}

/// Parse `+name,-name,name,all` into the clipboard switch, the only protocol
/// this tool uses: `Some(true)` forced on, `Some(false)` forced off.
///
/// # Errors
///
/// Returns the offending item when a name is not one of skill §2.5's.
fn clipboard_override(list: &str) -> Result<Option<bool>, String> {
    let mut state = None;
    for item in list.split(',').map(str::trim).filter(|s| !s.is_empty()) {
        let (on, name) = match item.as_bytes()[0] {
            b'+' => (true, &item[1..]),
            b'-' => (false, &item[1..]),
            _ => (true, item),
        };
        if name != "all" && !NAMES.contains(&name) {
            return Err(format!("unknown terminal protocol '{item}'"));
        }
        if name == "all" || name == "clipboard" {
            state = Some(on);
        }
    }
    Ok(state)
}

/// One protocol's resolved state, for `env`.
#[derive(Debug, Clone, Serialize)]
pub struct Entry {
    pub protocol: &'static str,
    pub enabled: bool,
    pub reason: String,
}

/// Resolved protocol state for this run.
#[derive(Debug, Clone, Serialize)]
pub struct Caps {
    pub protocols: Vec<Entry>,
    #[serde(skip)]
    clipboard: bool,
}

impl Caps {
    /// Resolve from the flag, layered over the variable (the flag wins).
    ///
    /// # Errors
    ///
    /// Names the source and the bad item.
    pub fn resolve(flag: Option<&str>) -> Result<Self, String> {
        let env = match std::env::var(ENV) {
            Ok(v) => clipboard_override(&v).map_err(|e| format!("{ENV}: {e}"))?,
            Err(_) => None,
        };
        let flag = match flag {
            Some(v) => clipboard_override(v).map_err(|e| format!("--term-protocols: {e}"))?,
            None => None,
        };
        let (clipboard, reason) = match (gate(), flag.or(env)) {
            // An override beats detection, never the gate: no user intent
            // makes escape sequences in an agent's or a pipe's stream right.
            (Err(why), _) => (false, why.to_owned()),
            (Ok(()), Some(on)) => (
                on,
                format!(
                    "forced {} by --term-protocols / {ENV}",
                    if on { "on" } else { "off" }
                ),
            ),
            (Ok(()), None) => (true, "OSC 52 write has no query; sent on --copy".to_owned()),
        };
        let protocols = NAMES
            .iter()
            .map(|&name| {
                if name == "clipboard" {
                    Entry {
                        protocol: name,
                        enabled: clipboard,
                        reason: reason.clone(),
                    }
                } else {
                    Entry {
                        protocol: name,
                        enabled: false,
                        reason: "not used by bravais-cli".to_owned(),
                    }
                }
            })
            .collect();
        Ok(Self {
            protocols,
            clipboard,
        })
    }

    /// Why the clipboard is off, when it is.
    pub fn clipboard_reason(&self) -> &str {
        self.protocols
            .iter()
            .find(|e| e.protocol == "clipboard")
            .map_or("", |e| e.reason.as_str())
    }
}

/// What became of a copy request.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Copied {
    /// Sent; terminals never acknowledge OSC 52, so the caller confirms.
    Sent { bytes: usize },
    /// Over [`CLIPBOARD_MAX`]; nothing sent.
    TooLarge { bytes: usize },
    /// Gate closed or `-clipboard`; nothing sent.
    Unavailable,
}

/// Put `text` on the system clipboard with OSC 52, written to stderr.
pub fn copy(caps: &Caps, text: &str) -> Copied {
    if !caps.clipboard {
        return Copied::Unavailable;
    }
    if text.len() > CLIPBOARD_MAX {
        return Copied::TooLarge { bytes: text.len() };
    }
    let mut seq = String::with_capacity(text.len() / 3 * 4 + 16);
    seq.push_str("\x1b]52;c;");
    base64_into(text.as_bytes(), &mut seq);
    seq.push_str("\x1b\\");
    let mut err = std::io::stderr().lock();
    let _ = err.write_all(seq.as_bytes());
    let _ = err.flush();
    Copied::Sent { bytes: text.len() }
}

/// Standard (RFC 4648 §4) base64 with padding; one call site does not earn a
/// dependency and a `cargoHash` bump.
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

/// Remove every escape sequence (CSI, OSC, other `ESC x`) and every C0 control
/// but tab and newline. Used on human output when colour is off, which also
/// keeps a control character smuggled in through an argument from ever
/// reaching the terminal.
pub fn strip_escapes(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut it = s.chars().peekable();
    while let Some(c) = it.next() {
        match c {
            '\x1b' => match it.next() {
                Some('[') => {
                    for c in it.by_ref() {
                        if ('\x40'..='\x7e').contains(&c) {
                            break;
                        }
                    }
                }
                Some(']') => {
                    while let Some(c) = it.next() {
                        if c == '\x07' || (c == '\x1b' && it.next_if_eq(&'\\').is_some()) {
                            break;
                        }
                    }
                }
                _ => {}
            },
            '\t' | '\n' => out.push(c),
            c if c.is_control() => {}
            c => out.push(c),
        }
    }
    out
}

/// The first control character in `s` that agent-supplied input may not
/// carry (agentic-cli §7: 0x00–0x08, 0x0B–0x0C, 0x0E–0x1F, plus DEL).
pub fn forbidden_control(s: &str) -> Option<char> {
    s.chars()
        .find(|&c| matches!(c, '\x00'..='\x08' | '\x0b' | '\x0c' | '\x0e'..='\x1f' | '\x7f'))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn clipboard_override_layers_and_rejects() {
        assert_eq!(clipboard_override("-all").unwrap(), Some(false));
        assert_eq!(clipboard_override("-all,+clipboard").unwrap(), Some(true));
        assert_eq!(clipboard_override("+progress").unwrap(), None);
        assert_eq!(clipboard_override("").unwrap(), None);
        assert!(clipboard_override("+images").is_err());
    }

    #[test]
    fn base64_matches_rfc4648_vectors() {
        for (input, want) in [
            ("", ""),
            ("f", "Zg=="),
            ("fo", "Zm8="),
            ("foo", "Zm9v"),
            ("foobar", "Zm9vYmFy"),
        ] {
            let mut s = String::new();
            base64_into(input.as_bytes(), &mut s);
            assert_eq!(s, want);
        }
    }

    #[test]
    fn strip_removes_sgr_osc_and_controls() {
        assert_eq!(strip_escapes("\x1b[1;31mrg\x1b[0m"), "rg");
        assert_eq!(strip_escapes("a\x1b]52;c;Zm9v\x1b\\b"), "ab");
        assert_eq!(strip_escapes("a\x1b]2;t\x07b\x08c\n"), "abc\n");
    }

    #[test]
    fn control_characters_are_found() {
        assert_eq!(forbidden_control("grep -r foo"), None);
        assert_eq!(forbidden_control("tab\tok"), None);
        assert_eq!(forbidden_control("x\x1b[2J"), Some('\x1b'));
    }
}
