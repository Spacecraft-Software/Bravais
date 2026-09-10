// SPDX-License-Identifier: GPL-3.0-or-later
//
// Tunnel inspection and the teardown sequence.
//
// ── Why this exists ───────────────────────────────────────────────────────────
//
// `adguardvpn-cli disconnect` hangs forever in TUN mode on this system, and the
// reason is structural rather than incidental (AGENTS.md constraint #36).
// `connect` re-launches itself as root through `sudo -b` and records the pid of
// the SUDO SHIM -- not the tunnel -- in `vpn.pid`. `disconnect` then sends that
// pid a SIGTERM and polls `kill(pid, 0)` every 21 ms until it disappears. It
// never does: sudo-rs blocks SIGTERM in that shim, so the signal parks in the
// shared pending set and is never handled. Ctrl+C then leaves the whole tree
// running.
//
// Measured on the live system, 2026-09-09:
//
//     /proc/<shim>/status
//       SigBlk:  0000000000004003   <- bit 15, SIGTERM, blocked
//       ShdPnd:  0000000000004000   <- bit 15, SIGTERM, pending, undeliverable
//
// ── Why the order below is the order ──────────────────────────────────────────
//
// Signal the TUNNEL first, never the shim. The tunnel is the process holding
// the interface and the routes, and it does have a thread with SIGTERM
// unblocked, so it tears down cleanly. Its shims then exit on their own because
// their child is gone.
//
// Killing the shim first -- which is what an impatient operator does, because
// the shim is the pid the client hands you and it is the one an unprivileged
// user is allowed to signal -- "works" in that `disconnect` finally returns,
// and leaves the tunnel reparented to init with the interface still up and
// `vpn.pid` deleted, so the client now reports "disconnected" while the tunnel
// is still there. That is a worse state than the hang, and it is the state this
// tool was written after cleaning up by hand.

use std::fs;
use std::os::unix::fs::MetadataExt;
use std::path::PathBuf;
use std::time::{Duration, Instant};

use rustix::process::{Pid, Signal};
use serde::Serialize;

use crate::proc::{self, Proc, Role};

/// How often to re-check a signalled process. Cheap: one `/proc/<pid>/stat`
/// read. Deliberately not the client's own 21 ms -- nothing here is racing.
const POLL: Duration = Duration::from_millis(100);

#[derive(Debug, Serialize)]
pub struct Status {
    pub connected: bool,
    pub tun_interfaces: Vec<String>,
    pub processes: Vec<Proc>,
    pub route_script: RouteScript,
    pub stale: Vec<Stale>,
}

/// The SCRIPT-mode route script, checked against the contract the client
/// enforces: root-owned, mode 0700, at the client's data directory.
///
/// Checked here because the client only reports it when you run
/// `config create-route-script`, and that subcommand hangs for the same reason
/// `disconnect` does -- it shells out to sudo to chown the file. This is the
/// non-hanging way to ask the same question, and it needs no privileges.
#[derive(Debug, Serialize)]
#[expect(
    clippy::struct_excessive_bools,
    reason = "this is a wire struct: each flag is one independently useful answer, and `usable` is the AND that saves every consumer from re-deriving the client's rule"
)]
pub struct RouteScript {
    pub path: String,
    pub exists: bool,
    pub owner_root: bool,
    pub mode: String,
    pub mode_ok: bool,
    /// True only when the client would actually accept and run it.
    pub usable: bool,
}

#[derive(Debug, Serialize)]
pub struct Stale {
    pub path: String,
    pub reason: String,
}

#[derive(Debug, Serialize)]
pub struct Action {
    pub pid: i32,
    pub role: Role,
    pub signal: &'static str,
    pub reason: &'static str,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub outcome: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct StopReport {
    pub actions: Vec<Action>,
    pub removed: Vec<String>,
    pub residual: Vec<Proc>,
    pub tun_interfaces: Vec<String>,
    /// Everything is gone: no tunnel, no shim, no tun interface.
    pub stopped: bool,
}

/// The client's data directory, resolved the way the client resolves it.
pub fn data_dir() -> PathBuf {
    if let Some(p) = std::env::var_os("AGVPN_CLI_DATA_PATH") {
        return PathBuf::from(p);
    }
    if let Some(p) = std::env::var_os("XDG_DATA_HOME") {
        return PathBuf::from(p).join("adguardvpn-cli");
    }
    let home = std::env::var_os("HOME").map_or_else(|| PathBuf::from("/"), PathBuf::from);
    home.join(".local/share/adguardvpn-cli")
}

pub fn status() -> Status {
    let processes = proc::scan();
    let connected = processes.iter().any(|p| p.role == Role::Tunnel);
    Status {
        connected,
        tun_interfaces: tun_interfaces(),
        stale: stale_artifacts(&processes),
        route_script: route_script(),
        processes,
    }
}

/// TUN devices, by the presence of the `tun_flags` attribute.
///
/// That attribute is what distinguishes a real tun/tap device from anything
/// merely named `tun*`, so this does not depend on the client's naming.
fn tun_interfaces() -> Vec<String> {
    let Ok(entries) = fs::read_dir("/sys/class/net") else {
        return Vec::new();
    };
    let mut v: Vec<String> = entries
        .flatten()
        .filter(|e| e.path().join("tun_flags").exists())
        .filter_map(|e| e.file_name().to_str().map(ToOwned::to_owned))
        .collect();
    v.sort();
    v
}

fn route_script() -> RouteScript {
    let path = data_dir().join("setup_routes.sh");
    let display = path.display().to_string();

    let Ok(md) = fs::metadata(&path) else {
        return RouteScript {
            path: display,
            exists: false,
            owner_root: false,
            mode: String::new(),
            mode_ok: false,
            usable: false,
        };
    };

    let perms = md.mode() & 0o7777;
    let owner_root = md.uid() == 0;
    let mode_ok = perms == 0o700;
    RouteScript {
        path: display,
        exists: true,
        owner_root,
        mode: format!("{perms:04o}"),
        mode_ok,
        usable: owner_root && mode_ok,
    }
}

/// Files the client leaves behind when a teardown goes wrong.
fn stale_artifacts(procs: &[Proc]) -> Vec<Stale> {
    let dir = data_dir();
    let mut out = Vec::new();

    let pid_file = dir.join("vpn.pid");
    if let Ok(txt) = fs::read_to_string(&pid_file) {
        if let Ok(pid) = txt.trim().parse::<i32>() {
            if !procs.iter().any(|p| p.pid == pid) {
                out.push(Stale {
                    path: pid_file.display().to_string(),
                    reason: format!("names pid {pid}, which is not an AdGuard VPN process"),
                });
            }
        }
    }

    let socket = dir.join("vpn.socket");
    if socket.exists() && !procs.iter().any(|p| p.role == Role::Tunnel) {
        out.push(Stale {
            path: socket.display().to_string(),
            reason: "control socket left behind with no tunnel running".to_owned(),
        });
    }

    out
}

/// What `stop` would do, without doing it. Also the body of `--dry-run`.
pub fn plan(procs: &[Proc]) -> Vec<Action> {
    let mut actions: Vec<Action> = procs
        .iter()
        .filter(|p| p.role == Role::Tunnel)
        .map(|p| Action {
            pid: p.pid,
            role: p.role,
            signal: "SIGTERM",
            reason: "tunnel process; terminates cleanly and releases the interface and routes",
            outcome: None,
        })
        .collect();

    // Shims are listed as SIGKILL, not SIGTERM, and that is not impatience:
    // they *block* SIGTERM, so sending one only adds another undeliverable
    // signal to the pending set. They are also expected to be gone by the time
    // this runs, having lost their child.
    actions.extend(
        procs
            .iter()
            .filter(|p| p.role == Role::Shim)
            .map(|p| Action {
                pid: p.pid,
                role: p.role,
                signal: "SIGKILL",
                reason: "sudo shim; blocks SIGTERM, so only SIGKILL can end it",
                outcome: None,
            }),
    );

    actions
}

/// Does this caller have the privilege to signal the tunnel?
///
/// The tunnel runs with every UID set to 0, so only root may signal it. A shim
/// is different -- its REAL uid is still the invoking user's, which is why an
/// unprivileged kill on the shim succeeds and misleads.
pub fn can_signal_tunnel() -> bool {
    rustix::process::geteuid().is_root()
}

pub fn stop(timeout: Duration, out: crate::output::Out) -> StopReport {
    use crate::output::Level;

    let mut actions = Vec::new();
    let mut removed = Vec::new();

    // Pass 1 -- the tunnels.
    for p in proc::scan().into_iter().filter(|p| p.role == Role::Tunnel) {
        let mut act = Action {
            pid: p.pid,
            role: p.role,
            signal: "SIGTERM",
            reason: "tunnel process; terminates cleanly and releases the interface and routes",
            outcome: None,
        };
        out.say(Level::Info, &format!("SIGTERM -> pid {} (tunnel)", p.pid));

        act.outcome = Some(match signal(&p, Signal::TERM) {
            Err(e) => format!("could not signal: {e}"),
            Ok(()) => {
                if wait_gone(&p, timeout) {
                    "exited".to_owned()
                } else {
                    // Escalating loses the client's own teardown, so routes and
                    // the interface may survive. Say so rather than reporting a
                    // clean stop.
                    out.say(
                        Level::Warn,
                        &format!(
                            "pid {} ignored SIGTERM for {}s; escalating to SIGKILL -- \
                             routes may be left behind",
                            p.pid,
                            timeout.as_secs()
                        ),
                    );
                    match signal(&p, Signal::KILL) {
                        Err(e) => format!("SIGKILL failed: {e}"),
                        Ok(()) => {
                            if wait_gone(&p, timeout) {
                                "killed after SIGTERM timeout".to_owned()
                            } else {
                                "survived SIGKILL".to_owned()
                            }
                        }
                    }
                }
            }
        });
        actions.push(act);
    }

    // Pass 2 -- shims that outlived their child. Re-scanned rather than reused
    // from pass 1: the common case is that they are already gone, and killing a
    // recycled pid would be the one genuinely dangerous thing this tool could do.
    for p in proc::scan().into_iter().filter(|p| p.role == Role::Shim) {
        out.say(
            Level::Info,
            &format!("SIGKILL -> pid {} (sudo shim)", p.pid),
        );
        let outcome = match signal(&p, Signal::KILL) {
            Err(e) => format!("could not signal: {e}"),
            Ok(()) => {
                if wait_gone(&p, timeout) {
                    "killed".to_owned()
                } else {
                    "survived SIGKILL".to_owned()
                }
            }
        };
        actions.push(Action {
            pid: p.pid,
            role: p.role,
            signal: "SIGKILL",
            reason: "sudo shim; blocks SIGTERM, so only SIGKILL can end it",
            outcome: Some(outcome),
        });
    }

    // Pass 3 -- the files. Only once nothing is running, so a live tunnel never
    // loses the socket out from under it.
    let residual = proc::scan();
    if !residual.iter().any(|p| p.role == Role::Tunnel) {
        for s in stale_artifacts(&residual) {
            match fs::remove_file(&s.path) {
                Ok(()) => removed.push(s.path),
                Err(e) => out.say(Level::Warn, &format!("could not remove {}: {e}", s.path)),
            }
        }
    }

    let tun_interfaces = tun_interfaces();
    let stopped = residual.is_empty() && tun_interfaces.is_empty();

    StopReport {
        actions,
        removed,
        residual,
        tun_interfaces,
        stopped,
    }
}

/// Send a signal, but only if the pid still refers to the process we inspected.
fn signal(p: &Proc, sig: Signal) -> Result<(), String> {
    if !p.is_alive() {
        return Ok(());
    }
    let pid = Pid::from_raw(p.pid).ok_or_else(|| "implausible pid".to_owned())?;
    rustix::process::kill_process(pid, sig).map_err(|e| e.to_string())
}

fn wait_gone(p: &Proc, timeout: Duration) -> bool {
    let deadline = Instant::now() + timeout;
    while Instant::now() < deadline {
        if !p.is_alive() {
            return true;
        }
        std::thread::sleep(POLL);
    }
    !p.is_alive()
}
