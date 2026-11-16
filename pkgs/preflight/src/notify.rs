// SPDX-License-Identifier: GPL-3.0-or-later
//
// Out-of-band notifications when a rebuild needs the user's attention -- in
// practice, when an authorization step (`sudo`, `gitway-add`) is waiting on a
// password or a fingerprint scan while the user is looking at another window,
// tab, or pane.
//
// Five channels, all best-effort and zero extra crate dependencies:
//
// 1. Desktop D-Bus (`org.freedesktop.Notifications` via `busctl --user`) --
//    works identically across GNOME, KDE Plasma, COSMIC, and the bare WMs
//    (Niri, LeftWM, Margo) where `dunst` owns the bus name. Calling `Notify`
//    with `replaces_id` updates in place, and `CloseNotification` dismisses
//    the popup the instant authentication succeeds so no stale banner lingers.
//    If `busctl` cannot reach the bus, `dunstify` is tried as a fallback.
// 2. Terminal bell (`\x07` to `/dev/tty`) -- sets the urgency hint on desktop
//    terminal emulators (Alacritty, Rio, Ghostty, Kitty, WezTerm, Foot), marks
//    background tabs in Zellij (`has_bell_notification`) and tmux, and sounds
//    the console beep on a Linux VTY.
// 3. OSC 9 / OSC 777 desktop notification escape sequences to `/dev/tty` --
//    supported by Ghostty, Kitty, WezTerm, Foot, Rio, and terminal multiplexers
//    that forward or intercept them.
// 4. Terminal window / tab title (`OSC 2`) -- prefixes the title with `[AUTH]`
//    while waiting and restores it afterwards, visible in any window list or
//    multiplexer tab bar.
// 5. Zellij multiplexer integration -- when `$ZELLIJ` is set, inspects the
//    session via `zellij action list-panes --json --tab` and `list-tabs --json`
//    to prefix the hosting pane's and tab's titles with `[AUTH] ` while
//    waiting, restoring the exact original titles on drop. Even if the user is
//    in a Linux real TTY running Zellij and switched to another tab or pane,
//    the tab bar immediately flags the waiting rebuild.

// Rust guideline compliant 2026-05-18

use std::fs::OpenOptions;
use std::io::Write;
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

/// How long an authorization command gets to complete silently (cached sudo
/// credential, already-loaded SSH key) before we conclude it is waiting on the
/// user and fire the notification channels.
///
/// 400 ms is well above the ~5-30 ms of a warm `sudo` or `gitway-add` no-op,
/// and short enough that a prompt or fingerprint scan feels immediately
/// announced.
const AUTH_GRACE: Duration = Duration::from_millis(400);

/// Fixed replacement ID for `dunstify -r` when `busctl` is unavailable.
const DUNST_REPLACE_ID: &str = "9919";

/// Guard that watches an in-flight authorization step and tears down any
/// active alert as soon as authorization succeeds or the step finishes.
#[derive(Debug)]
pub struct AuthWatch {
    done: std::sync::Arc<AtomicBool>,
    handle: Option<std::thread::JoinHandle<AlertState>>,
}

/// Saved Zellij `(id, original_title)` pair for restoring a pane or tab badge.
type ZellijSaved = Option<(u32, String)>;

/// What the background watcher actually activated, so `Drop` can clean up
/// cleanly without touching channels that never fired.
#[derive(Debug, Default)]
struct AlertState {
    fired: bool,
    dbus_id: Option<u32>,
    used_dunstify: bool,
    zellij_pane: ZellijSaved,
    zellij_tab: ZellijSaved,
}

impl AuthWatch {
    /// Start watching an authorization step named `step` (`"sudo"`,
    /// `"gitway-add"`, ...) running `detail`.
    ///
    /// When `enabled` is false (non-interactive / agent / JSON / quiet runs
    /// where no human is being prompted), no thread is spawned unless a live
    /// desktop bus or terminal is present.
    #[must_use]
    pub fn start(step: &str, detail: &str, enabled: bool) -> Self {
        let done = std::sync::Arc::new(AtomicBool::new(false));
        if !enabled {
            return Self { done, handle: None };
        }
        let flag = std::sync::Arc::clone(&done);
        let step_owned = step.to_owned();
        let detail_owned = detail.to_owned();
        let handle = std::thread::Builder::new()
            .name("preflight-auth-watch".into())
            .spawn(move || watch_loop(&flag, &step_owned, &detail_owned))
            .ok();
        Self { done, handle }
    }
}

impl Drop for AuthWatch {
    fn drop(&mut self) {
        self.done.store(true, Ordering::Release);
        if let Some(h) = self.handle.take() {
            h.thread().unpark();
            if let Ok(state) = h.join() {
                if state.fired {
                    clear_alert(&state);
                }
            }
        }
    }
}

fn watch_loop(done: &AtomicBool, step: &str, detail: &str) -> AlertState {
    std::thread::park_timeout(AUTH_GRACE);
    if done.load(Ordering::Acquire) {
        return AlertState::default();
    }
    // A warm credential cache means nothing is waiting on the user: stay
    // silent rather than flash an alert for every privileged step.
    if is_privilege_helper(step) && (privilege_cached(step) || helper_running_command(step)) {
        return AlertState::default();
    }
    let state = fire_alert(step, detail);

    // `sudo nixos-rebuild …` remains alive for the whole rebuild.  Its
    // successful fingerprint scan, though, fills the helper's credential
    // cache as soon as PAM accepts it.  Waiting for the long-running command
    // to exit left the status bar and notification saying "waiting" for the
    // duration of the build.  Poll only the helper's non-interactive cache
    // probe: it never asks a second question and lets us clear the alert at
    // the actual authorization boundary.  `gitway-add` has no comparable
    // safe probe, so it retains the command-lifetime behaviour.
    if !is_privilege_helper(step) {
        return state;
    }

    loop {
        std::thread::park_timeout(Duration::from_millis(150));
        if done.load(Ordering::Acquire) {
            return state;
        }
        if privilege_cached(step) || helper_running_command(step) {
            clear_alert(&state);
            return AlertState::default();
        }
    }
}

/// Return whether a privilege helper can currently run a harmless command
/// without asking a question.  Every probe is deliberately non-interactive:
/// the watcher must observe a credential acceptance, never create another
/// password or fingerprint request of its own.
fn is_privilege_helper(step: &str) -> bool {
    matches!(step, "sudo" | "doas" | "run0")
}

/// Return whether a privilege helper that this process spawned has itself
/// spawned a child. The helper only starts the real command after PAM accepts
/// the password or fingerprint, so a child proves authorization even when the
/// credential cache is off (`timestamp_timeout=0`) and `privilege_cached`
/// can never succeed -- the case that left the alert up for a whole build.
fn helper_running_command(step: &str) -> bool {
    let me = std::process::id();
    let Ok(dir) = std::fs::read_dir("/proc") else {
        return false;
    };
    let procs: Vec<(u32, u32, String)> = dir
        .flatten()
        .filter_map(|e| {
            let pid: u32 = e.file_name().to_str()?.parse().ok()?;
            let stat = std::fs::read_to_string(e.path().join("stat")).ok()?;
            // `pid (comm) S ppid ...`; comm may contain spaces and parens.
            let open = stat.find('(')?;
            let close = stat.rfind(')')?;
            let comm = stat.get(open + 1..close)?.to_owned();
            let parent: u32 = stat
                .get(close + 1..)?
                .split_whitespace()
                .nth(1)?
                .parse()
                .ok()?;
            Some((pid, parent, comm))
        })
        .collect();
    procs
        .iter()
        .filter(|(_, ppid, comm)| *ppid == me && comm == step)
        .any(|(pid, _, _)| procs.iter().any(|(_, ppid, _)| ppid == pid))
}

fn privilege_cached(step: &str) -> bool {
    let args: &[&str] = match step {
        "sudo" | "doas" => &["-n", "true"],
        "run0" => &["--no-ask-password", "true"],
        _ => return false,
    };
    Command::new(step)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .is_ok_and(|status| status.success())
}

fn fire_alert(step: &str, detail: &str) -> AlertState {
    let summary = format!("Preflight waiting for authorization ({step})");
    let body =
        format!("{detail} — scan fingerprint or enter password in the terminal running preflight.");

    // 1. Desktop notification (D-Bus org.freedesktop.Notifications, or dunstify).
    let (dbus_id, used_dunstify) = send_desktop(&summary, &body);

    // 2 + 3 + 4. Terminal bell, OSC 9/777 notification, and OSC 2 window title.
    // Written straight to /dev/tty so neither stdout (JSON payload) nor stderr
    // (step diagnostics / TUI) is disturbed. Wait for real TTY vs emulator:
    // on `TERM=linux` (the kernel virtual console), skip OSC sequences and emit
    // only the BEL (`\x07`) so the console driver never prints stray escape text.
    send_tty_alert(&summary, &body, dbus_id.is_some() || used_dunstify);

    // 5. Zellij pane + tab badge, which works identically in a graphical
    // terminal and inside a real TTY multiplexing panes via Zellij.
    let (zellij_pane, zellij_tab) = send_zellij_badge(step);

    // Also inform the in-process UI (status bar / TUI header) that we are
    // waiting on credentials.
    crate::ui::set_auth_waiting(Some(format!(
        "WAITING FOR AUTHORIZATION ({step}): scan fingerprint or enter password"
    )));

    AlertState {
        fired: true,
        dbus_id,
        used_dunstify,
        zellij_pane,
        zellij_tab,
    }
}

fn clear_alert(state: &AlertState) {
    crate::ui::set_auth_waiting(None);

    if let Some(id) = state.dbus_id {
        close_desktop_dbus(id);
    } else if state.used_dunstify {
        let _ = Command::new("dunstify")
            .args(["-C", DUNST_REPLACE_ID])
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status();
    }

    clear_tty_title();
    clear_zellij_badge(state.zellij_pane.as_ref(), state.zellij_tab.as_ref());
}

/// Call `org.freedesktop.Notifications.Notify` over the user session bus.
///
/// Works in GNOME, KDE Plasma, COSMIC, Niri, `LeftWM`, and Margo without linking
/// `libnotify` or `libdbus` into `preflight`. Returns `(Some(id), false)` when
/// `busctl` succeeds, or `(None, true)` if `dunstify` was used instead.
fn send_desktop(summary: &str, body: &str) -> (Option<u32>, bool) {
    if !has_session_bus() {
        return (None, false);
    }

    // Signature: susssasa{sv}i
    //   app_name: "preflight"
    //   replaces_id: 0
    //   app_icon: "dialog-password"
    //   summary, body
    //   actions: 0 (empty array)
    //   hints: 2 -> urgency: byte 2 (critical), category: string "device"
    //   expire_timeout: 30000 ms
    let out = Command::new("busctl")
        .args([
            "--user",
            "call",
            "org.freedesktop.Notifications",
            "/org/freedesktop/Notifications",
            "org.freedesktop.Notifications",
            "Notify",
            "susssasa{sv}i",
            "preflight",
            "0",
            "dialog-password",
            summary,
            body,
            "0",
            "2",
            "urgency",
            "y",
            "2",
            "category",
            "s",
            "device",
            "30000",
        ])
        .stdin(Stdio::null())
        .stderr(Stdio::null())
        .output();

    if let Ok(o) = out {
        if o.status.success() {
            // busctl prints `u 42\n` for a uint32 reply.
            let text = String::from_utf8_lossy(&o.stdout);
            let id = text
                .split_whitespace()
                .nth(1)
                .and_then(|s| s.parse::<u32>().ok())
                .filter(|&n| n > 0);
            return (id, false);
        }
    }

    // Fallback for bare-WM sessions if busctl failed for any reason.
    let ok = Command::new("dunstify")
        .args([
            "-a",
            "preflight",
            "-r",
            DUNST_REPLACE_ID,
            "-u",
            "critical",
            "-i",
            "dialog-password",
            summary,
            body,
        ])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .is_ok_and(|s| s.success());
    (None, ok)
}

fn close_desktop_dbus(id: u32) {
    let _ = Command::new("busctl")
        .args([
            "--user",
            "call",
            "org.freedesktop.Notifications",
            "/org/freedesktop/Notifications",
            "org.freedesktop.Notifications",
            "CloseNotification",
            "u",
            &id.to_string(),
        ])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
}

fn has_session_bus() -> bool {
    if std::env::var_os("DBUS_SESSION_BUS_ADDRESS").is_some() {
        return true;
    }
    if let Ok(dir) = std::env::var("XDG_RUNTIME_DIR") {
        if std::path::Path::new(&dir).join("bus").exists() {
            return true;
        }
    }
    false
}

fn is_linux_vt() -> bool {
    matches!(std::env::var("TERM").as_deref(), Ok("linux" | "dumb"))
}

///
/// `desktop_sent` means a retractable desktop notification already went out.
/// The terminal's own OSC 9/777 popup cannot be closed once authorization
/// succeeds (`WezTerm` leaves it up for minutes), so it is only the fallback
/// for sessions with no notification daemon; the title badge is always set.
fn send_tty_alert(summary: &str, body: &str, desktop_sent: bool) {
    let Ok(mut tty) = OpenOptions::new().write(true).open("/dev/tty") else {
        return;
    };
    if is_linux_vt() && std::env::var_os("ZELLIJ").is_none() && std::env::var_os("TMUX").is_none() {
        // Real Linux VTY outside a multiplexer: emit BEL only so the console
        // never prints raw OSC sequences.
        let _ = tty.write_all(b"\x07");
        let _ = tty.flush();
        return;
    }
    // Sanitize control characters so OSC payloads stay well-formed.
    let clean_summary: String = summary.chars().filter(|c| !c.is_control()).collect();
    let clean_body: String = body.chars().filter(|c| !c.is_control()).collect();
    // BEL + OSC 9 (ConEmu/Ghostty/iTerm2/Zellij) + OSC 777 (rxvt/Foot/WezTerm)
    // + OSC 2 window title.
    if desktop_sent {
        let _ = write!(tty, "\x07\x1b]2;[AUTH] {clean_summary}\x07");
    } else {
        let _ = write!(
            tty,
            "\x07\x1b]9;{clean_summary}: {clean_body}\x07\x1b]777;notify;{clean_summary};{clean_body}\x07\x1b]2;[AUTH] {clean_summary}\x07"
        );
    }
    let _ = tty.flush();
}

fn clear_tty_title() {
    if is_linux_vt() && std::env::var_os("ZELLIJ").is_none() && std::env::var_os("TMUX").is_none() {
        return;
    }
    if let Ok(mut tty) = OpenOptions::new().write(true).open("/dev/tty") {
        let _ = tty.write_all(b"\x1b]2;preflight\x07");
        let _ = tty.flush();
    }
}

/// If running inside Zellij (`$ZELLIJ` or `$ZELLIJ_SESSION_NAME` set), prefix
/// our pane's title and our tab's name with `[AUTH] ` so the user sees the
/// prompt alert in Zellij's tab bar and pane borders even on a bare TTY.
fn send_zellij_badge(step: &str) -> (ZellijSaved, ZellijSaved) {
    if std::env::var_os("ZELLIJ").is_none() && std::env::var_os("ZELLIJ_SESSION_NAME").is_none() {
        return (None, None);
    }
    let pane_id = std::env::var("ZELLIJ_PANE_ID")
        .ok()
        .and_then(|s| s.parse::<u32>().ok());

    let panes_out = Command::new("zellij")
        .args(["action", "list-panes", "--json", "--tab"])
        .stdin(Stdio::null())
        .stderr(Stdio::null())
        .output()
        .ok()
        .filter(|o| o.status.success());

    let mut saved_pane: Option<(u32, String)> = None;
    let mut saved_tab: Option<(u32, String)> = None;

    if let Some(out) = panes_out {
        if let Ok(serde_json::Value::Array(items)) = serde_json::from_slice(&out.stdout) {
            let entry = items.iter().find(|p| {
                p.get("is_plugin").and_then(serde_json::Value::as_bool) == Some(false)
                    && match pane_id {
                        Some(id) => {
                            p.get("id").and_then(serde_json::Value::as_u64) == Some(u64::from(id))
                        }
                        None => {
                            p.get("is_focused").and_then(serde_json::Value::as_bool) == Some(true)
                        }
                    }
            });
            if let Some(p) = entry {
                if let (Some(id), Some(title)) = (
                    p.get("id")
                        .and_then(serde_json::Value::as_u64)
                        .and_then(|n| u32::try_from(n).ok()),
                    p.get("title").and_then(serde_json::Value::as_str),
                ) {
                    if !title.starts_with("[AUTH") {
                        saved_pane = Some((id, title.to_owned()));
                    }
                }
                if let (Some(tid), Some(tname)) = (
                    p.get("tab_id")
                        .and_then(serde_json::Value::as_u64)
                        .and_then(|n| u32::try_from(n).ok()),
                    p.get("tab_name").and_then(serde_json::Value::as_str),
                ) {
                    if !tname.starts_with("[AUTH") {
                        saved_tab = Some((tid, tname.to_owned()));
                    }
                }
            }
        }
    }

    if let Some((_, ref orig)) = saved_pane {
        let badge = format!("[AUTH: {step}] {orig}");
        let _ = Command::new("zellij")
            .args(["action", "rename-pane", &badge])
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status();
    }
    if let Some((tid, ref orig)) = saved_tab {
        let badge = format!("[AUTH: {step}] {orig}");
        let _ = Command::new("zellij")
            .args(["action", "rename-tab-by-id", &tid.to_string(), &badge])
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status();
    }

    (saved_pane, saved_tab)
}

fn clear_zellij_badge(pane: Option<&(u32, String)>, tab: Option<&(u32, String)>) {
    if pane.is_some() {
        let _ = Command::new("zellij")
            .args(["action", "undo-rename-pane"])
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status();
    }
    if let Some((tid, orig)) = tab {
        let _ = Command::new("zellij")
            .args(["action", "rename-tab-by-id", &tid.to_string(), orig])
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn disabled_watch_does_not_spawn() {
        let w = AuthWatch::start("sudo", "sudo nixos-rebuild switch", false);
        assert!(w.handle.is_none());
    }

    #[test]
    fn fast_completion_cancels_before_grace_period() {
        // Even when enabled, dropping immediately sets `done` and unparks the
        // watcher before `AUTH_GRACE` elapses, so no alert is fired.
        let w = AuthWatch::start("sudo", "sudo true", true);
        drop(w);
    }

    #[test]
    fn only_privilege_helpers_have_a_safe_cache_probe() {
        assert!(is_privilege_helper("sudo"));
        assert!(is_privilege_helper("doas"));
        assert!(is_privilege_helper("run0"));
        assert!(!is_privilege_helper("gitway-add"));
    }
}
