// SPDX-License-Identifier: GPL-3.0-or-later
//
// The /proc layer: enumerate processes, read the fields that matter, and decode
// the signal masks.
//
// Read straight out of /proc rather than shelling out to `ps`, for two reasons
// that are not stylistic. First, `ps` output is a rendering -- column widths
// truncate the long argv this tool classifies on, and the earlier diagnosis of
// this very bug needed the full command line. Second, nothing here should
// depend on a PATH we do not control; this binary may be the thing you reach
// for when a session is already unhealthy.
//
// The signal masks are not decoration. The whole failure this tool exists to
// clean up is a SIGTERM sitting undeliverable in a process that blocks it, and
// `tunnel list` showing `sigterm_blocked` next to `sigterm_pending` is what
// turns "the disconnect hangs" into an explanation.

use std::fs;
use std::path::Path;

use serde::Serialize;

/// Bit for SIGTERM (15) inside the `/proc/<pid>/status` signal masks, which are
/// hex bitmaps with signal N at bit N-1.
const SIGTERM_BIT: u64 = 1 << 14;

/// What a process is, in this tool's world.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Role {
    /// The privileged tunnel itself: `adguardvpn-cli connect`, running as root.
    /// The only thing worth signalling.
    Tunnel,
    /// A `sudo` process wrapping the tunnel. Blocks SIGTERM; see AGENTS.md.
    Shim,
    /// Any other `adguardvpn-cli` invocation -- `status`, `disconnect`, a
    /// hung `config` call. Reported so a stuck one is visible, never signalled.
    Client,
}

#[derive(Debug, Clone, Serialize)]
pub struct Proc {
    pub pid: i32,
    pub ppid: i32,
    pub role: Role,
    /// Real UID. Not cosmetic: a `sudo` shim keeps the *invoking* user's real
    /// UID while its effective UID is 0, which is exactly why an unprivileged
    /// `kill` on it succeeds where the same call against the tunnel fails.
    pub uid_real: u32,
    pub uid_effective: u32,
    /// Kernel start time in clock ticks since boot. Carried so a signal can be
    /// re-checked against the process we actually looked at -- see `is_alive`.
    #[serde(skip)]
    pub start_time: u64,
    /// SIGTERM is blocked in EVERY thread, so a SIGTERM sent to this process
    /// can never be handled. See `sigterm_blocked_everywhere`.
    pub sigterm_blocked: bool,
    pub sigterm_pending: bool,
    /// Reparented to init, i.e. whatever started it is already gone. A tunnel
    /// in this state is the leak: nothing is left that would ever stop it.
    pub orphaned: bool,
    pub argv: Vec<String>,
}

impl Proc {
    /// Is this exact process still alive?
    ///
    /// "Exact" is the load-bearing word. PIDs are recycled, and the gap between
    /// deciding to signal a pid and signalling it is a gap in which the kernel
    /// may hand that number to something else -- so the start time recorded at
    /// discovery is compared again here. Without this check a slow SIGKILL path
    /// could land on an unrelated process that merely inherited the number.
    pub fn is_alive(&self) -> bool {
        read_start_time(self.pid).is_some_and(|t| t == self.start_time)
    }
}

/// Every AdGuard VPN process on the machine, sorted with tunnels first so a
/// caller that stops them in order never orphans a child by killing its parent.
pub fn scan() -> Vec<Proc> {
    let Ok(entries) = fs::read_dir("/proc") else {
        return Vec::new();
    };
    let me = std::process::id();

    let mut found: Vec<Proc> = entries
        .flatten()
        .filter_map(|e| e.file_name().to_str()?.parse::<i32>().ok())
        // Never consider ourselves. This binary is not named adguardvpn-cli, so
        // this cannot trigger today -- it is here because the previous round of
        // this diagnosis killed its own shell twice with a `pkill -f` whose
        // pattern matched the process running it.
        .filter(|pid| *pid != 0 && u32::try_from(*pid).is_ok_and(|p| p != me))
        .filter_map(inspect)
        .collect();

    found.sort_by_key(|p| (role_order(p.role), p.pid));
    found
}

const fn role_order(r: Role) -> u8 {
    match r {
        Role::Tunnel => 0,
        Role::Shim => 1,
        Role::Client => 2,
    }
}

fn inspect(pid: i32) -> Option<Proc> {
    let argv = read_argv(pid)?;
    let role = classify(&argv)?;

    let status = fs::read_to_string(format!("/proc/{pid}/status")).ok()?;
    let (uid_real, uid_effective) = parse_uids(&status)?;
    let parent = field(&status, "PPid:")?.parse().ok()?;
    // A blocked signal lands in the SHARED pending set (ShdPnd) when it was
    // sent to the process rather than to one thread; SigPnd is the per-thread
    // set and stays empty in that case. Reading only SigPnd reports "nothing
    // pending" for exactly the situation this tool is about.
    let pending =
        parse_mask(&status, "ShdPnd:").unwrap_or(0) | parse_mask(&status, "SigPnd:").unwrap_or(0);

    Some(Proc {
        pid,
        ppid: parent,
        role,
        uid_real,
        uid_effective,
        start_time: read_start_time(pid)?,
        sigterm_blocked: sigterm_blocked_everywhere(pid),
        sigterm_pending: pending & SIGTERM_BIT != 0,
        orphaned: parent == 1,
        argv,
    })
}

/// Is SIGTERM blocked in *every* thread of this process?
///
/// The distinction is the difference between a clean teardown and a SIGKILL.
/// A signal sent to a process is delivered to any one thread that does not
/// block it, so the thread-group leader's mask -- which is all
/// `/proc/<pid>/status` reports -- answers the wrong question. The AdGuard
/// tunnel is exactly this case: its main thread blocks SIGTERM while a sibling
/// sits in `sigwait`, so reading only the leader would say "blocked" and send a
/// reader straight to SIGKILL, losing the client's own route teardown.
///
/// The sudo shim, by contrast, is genuinely blocked in its only thread -- which
/// is why nothing but SIGKILL ends it.
///
/// A process with no readable task directory is reported as not-blocked: the
/// conservative answer, since it keeps the caller on the SIGTERM path.
fn sigterm_blocked_everywhere(pid: i32) -> bool {
    let Ok(tasks) = fs::read_dir(format!("/proc/{pid}/task")) else {
        return false;
    };
    let mut any = false;
    for t in tasks.flatten() {
        let Ok(st) = fs::read_to_string(t.path().join("status")) else {
            continue;
        };
        any = true;
        if parse_mask(&st, "SigBlk:").unwrap_or(0) & SIGTERM_BIT == 0 {
            return false;
        }
    }
    any
}

/// Classify on argv, not on `/proc/<pid>/comm`.
///
/// `comm` is 15 bytes and is freely settable by the process itself, so it is
/// both lossy and untrustworthy for a decision that ends in a signal. argv is
/// what actually distinguishes the three roles here, and the distinction that
/// matters most -- `connect` versus any other subcommand -- lives in argv[1].
fn classify(argv: &[String]) -> Option<Role> {
    let exe = basename(argv.first()?);

    if exe == "adguardvpn-cli" {
        return Some(if argv.iter().any(|a| a == "connect") {
            Role::Tunnel
        } else {
            Role::Client
        });
    }

    // sudo-rs installs its binaries as `sudo` and `su`; match the basename
    // rather than a store path, which changes with every nixpkgs bump.
    if (exe == "sudo" || exe == "sudo-rs")
        && argv
            .iter()
            .any(|a| basename(a) == "adguardvpn-cli" || a.contains("adguardvpn-cli"))
    {
        return Some(Role::Shim);
    }

    None
}

fn basename(s: &str) -> &str {
    Path::new(s)
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or(s)
}

fn read_argv(pid: i32) -> Option<Vec<String>> {
    let raw = fs::read(format!("/proc/{pid}/cmdline")).ok()?;
    if raw.is_empty() {
        // Kernel threads have an empty cmdline. Not an error, just not ours.
        return None;
    }
    Some(
        raw.split(|b| *b == 0)
            .filter(|s| !s.is_empty())
            .map(String::from_utf8_lossy)
            .map(std::borrow::Cow::into_owned)
            .collect(),
    )
}

fn field<'a>(status: &'a str, key: &str) -> Option<&'a str> {
    status
        .lines()
        .find(|l| l.starts_with(key))?
        .strip_prefix(key)
        .map(str::trim)
}

/// `Uid:` carries real, effective, saved and filesystem UIDs, tab-separated.
fn parse_uids(status: &str) -> Option<(u32, u32)> {
    let mut it = field(status, "Uid:")?.split_whitespace();
    let real = it.next()?.parse().ok()?;
    let eff = it.next()?.parse().ok()?;
    Some((real, eff))
}

fn parse_mask(status: &str, key: &str) -> Option<u64> {
    u64::from_str_radix(field(status, key)?, 16).ok()
}

/// Field 22 of `/proc/<pid>/stat`, the process start time.
///
/// Parsed from after the LAST `)` rather than by splitting the whole line: the
/// second field is the executable name in parentheses and may itself contain
/// spaces and parentheses, so a naive split miscounts every field after it.
fn read_start_time(pid: i32) -> Option<u64> {
    let stat = fs::read_to_string(format!("/proc/{pid}/stat")).ok()?;
    let rest = &stat[stat.rfind(')')? + 1..];
    // After the comm field, field 3 is `state`; start time is field 22 overall,
    // so it is the 20th whitespace-separated token of what remains.
    rest.split_whitespace().nth(19)?.parse().ok()
}
