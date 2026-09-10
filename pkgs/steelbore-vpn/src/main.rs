// SPDX-License-Identifier: GPL-3.0-or-later
//
// steelbore-vpn — AdGuard VPN tunnel inspector and teardown helper.
//
// Two jobs, both of which exist because the vendor client cannot do them here:
//
//   `tunnel status`  answers "what is actually running, and is the SCRIPT-mode
//                    route script installed the way the client demands" without
//                    running anything that can hang.
//   `tunnel stop`    tears the tunnel down in the order that does not strand a
//                    root process holding the interface. See tunnel.rs for why
//                    that order is what it is.
//
// This does NOT replace `adguardvpn-cli`. Connecting, logging in, locations and
// configuration all stay with the vendor client; only the teardown is taken
// over, because the vendor's own teardown hangs (AGENTS.md constraint #36).
//
// Standard §3.1: no `unwrap`/`expect` on any fallible runtime path. A /proc
// entry that vanishes mid-scan is ordinary -- processes exit -- so every read
// is allowed to fail and simply drops that process from the result.

mod output;
mod proc;
mod tunnel;

use std::fmt::Write as _;
use std::time::Duration;

use clap::{Parser, Subcommand};

use output::{AppError, ColorWhen, Exit, Format, Level, Out};

#[derive(Parser, Debug)]
#[command(
    name = "steelbore-vpn",
    version,
    // §15.2: --version carries the maintainer and the project URL. clap's bare
    // `version` prints name + number only, so attribution goes in long_version,
    // which is what both -V and --version render.
    long_version = concat!(
        env!("CARGO_PKG_VERSION"), "\n",
        "Maintained by Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>\n",
        "Copyright (C) 2026 Mohamed Hammad & Spacecraft Software  |  License: GPL-3.0-or-later\n",
        "https://Bravais.SpacecraftSoftware.org/"
    ),
    about = "AdGuard VPN tunnel inspector and teardown helper.",
    after_help = concat!(
        "EXAMPLES:\n",
        "  steelbore-vpn tunnel status              What is running, and is the route script usable\n",
        "  steelbore-vpn tunnel status --json       The same, machine-readable\n",
        "  steelbore-vpn tunnel list                Every AdGuard VPN process, with its signal state\n",
        "  steelbore-vpn tunnel stop --dry-run      What a teardown would signal, and why\n",
        "  sudo steelbore-vpn tunnel stop --yes     Tear the tunnel down (needs root)\n",
        "\n",
        "Maintained by Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>\n",
        "https://Bravais.SpacecraftSoftware.org/"
    )
)]
#[expect(
    clippy::struct_excessive_bools,
    reason = "this IS the flag surface; enums here would only rename the same independent switches"
)]
struct Cli {
    #[command(subcommand)]
    command: Cmd,

    /// Emit machine-readable JSON (alias for --format json)
    #[arg(long, global = true)]
    json: bool,

    /// Output format
    #[arg(long, global = true, value_enum)]
    format: Option<Format>,

    /// Colour policy
    #[arg(long, global = true, value_enum, default_value = "auto")]
    color: ColorWhen,

    /// Disable colour (equivalent to --color never)
    #[arg(long, global = true)]
    no_color: bool,

    /// Lower the severity floor to info
    #[arg(long, short, global = true, conflicts_with = "quiet")]
    verbose: bool,

    /// Raise the severity floor to errors only
    #[arg(long, short, global = true)]
    quiet: bool,
}

#[derive(Subcommand, Debug)]
enum Cmd {
    /// Inspect and control the AdGuard VPN tunnel
    Tunnel {
        #[command(subcommand)]
        action: TunnelCmd,
    },
    /// Emit the JSON Schema of the command surface
    Schema,
    /// Emit a compact capability manifest
    Describe,
}

#[derive(Subcommand, Debug)]
enum TunnelCmd {
    /// Whether a tunnel is up, plus route-script and stale-file checks
    Status,
    /// Every AdGuard VPN process, with role and signal state
    List,
    /// Tear the tunnel down. Needs root; reports the plan without --yes.
    Stop {
        /// Actually signal. Without it, `stop` only prints the plan.
        #[arg(long, visible_alias = "force")]
        yes: bool,

        /// Print the plan and exit, even with --yes
        #[arg(long)]
        dry_run: bool,

        /// Seconds to wait for a signalled process before escalating
        #[arg(long, value_name = "SECONDS", default_value_t = 10)]
        timeout: u64,
    },
}

fn main() -> std::process::ExitCode {
    let cli = Cli::parse();

    let color = if cli.no_color {
        ColorWhen::Never
    } else {
        cli.color
    };
    let format = if cli.json {
        Some(Format::Json)
    } else {
        cli.format
    };
    let out = Out::resolve(format, color, cli.verbose, cli.quiet);

    let code = match &cli.command {
        Cmd::Schema => cmd_schema(out),
        Cmd::Describe => cmd_describe(out),
        Cmd::Tunnel { action } => match action {
            TunnelCmd::Status => cmd_status(out),
            TunnelCmd::List => cmd_list(out),
            TunnelCmd::Stop {
                yes,
                dry_run,
                timeout,
            } => cmd_stop(out, *yes, *dry_run, *timeout),
        },
    };

    #[expect(
        clippy::cast_possible_truncation,
        clippy::cast_sign_loss,
        reason = "exit codes are 0..=125 by construction; the enum has no other values"
    )]
    std::process::ExitCode::from(code as u8)
}

fn cmd_status(out: Out) -> i32 {
    let st = tunnel::status();

    let mut human = String::new();
    human.push_str(if st.connected {
        "  tunnel      running\n"
    } else {
        "  tunnel      not running\n"
    });
    let _ = writeln!(
        human,
        "  interfaces  {}",
        if st.tun_interfaces.is_empty() {
            "none".to_owned()
        } else {
            st.tun_interfaces.join(", ")
        }
    );
    let _ = writeln!(
        human,
        "  processes   {}",
        if st.processes.is_empty() {
            "none".to_owned()
        } else {
            st.processes.len().to_string()
        }
    );
    let rs = &st.route_script;
    let _ = writeln!(
        human,
        "  route hook  {}",
        if !rs.exists {
            "absent".to_owned()
        } else if rs.usable {
            format!("ok (root, {})", rs.mode)
        } else {
            format!(
                "UNUSABLE (owner root: {}, mode {} -- the client requires root and 0700)",
                rs.owner_root, rs.mode
            )
        }
    );
    for s in &st.stale {
        let _ = writeln!(human, "  stale       {} -- {}", s.path, s.reason);
    }

    // A tunnel with no interface, or an interface with no tunnel, is the
    // half-torn-down state this whole tool is about. Say so on stderr where a
    // human will see it, without failing: `status` reports, it does not judge.
    if st.connected && st.tun_interfaces.is_empty() {
        out.say(
            Level::Warn,
            "a tunnel process is running but no tun interface exists",
        );
    }
    if !st.connected && !st.tun_interfaces.is_empty() {
        out.say(
            Level::Warn,
            "a tun interface exists with no tunnel process -- something was torn down out of order",
        );
    }
    if !st.stale.is_empty() {
        out.say(
            Level::Warn,
            "stale client state found; `steelbore-vpn tunnel stop --yes` clears it once nothing is running",
        );
    }

    out.emit("steelbore-vpn tunnel status", &st, false, &human);
    Exit::Success as i32
}

fn cmd_list(out: Out) -> i32 {
    let procs = proc::scan();

    let mut human = String::new();
    if procs.is_empty() {
        human.push_str("  no AdGuard VPN processes\n");
    } else {
        human.push_str("  PID     PPID    ROLE     UID(r/e)  FLAGS\n");
        for p in &procs {
            let mut flags = Vec::new();
            if p.sigterm_blocked {
                flags.push("sigterm-blocked");
            }
            if p.sigterm_pending {
                flags.push("sigterm-pending");
            }
            if p.orphaned {
                flags.push("orphaned");
            }
            let _ = writeln!(
                human,
                "  {:<7} {:<7} {:<8} {:<9} {}",
                p.pid,
                p.ppid,
                format!("{:?}", p.role).to_lowercase(),
                format!("{}/{}", p.uid_real, p.uid_effective),
                if flags.is_empty() {
                    "-".to_owned()
                } else {
                    flags.join(",")
                }
            );
        }
    }

    if procs.iter().any(|p| p.sigterm_blocked && p.sigterm_pending) {
        out.say(
            Level::Warn,
            "a process is holding an undeliverable SIGTERM -- this is the state in which \
             `adguardvpn-cli disconnect` hangs forever",
        );
    }

    out.emit("steelbore-vpn tunnel list", &procs, false, &human);
    Exit::Success as i32
}

fn cmd_stop(out: Out, yes: bool, dry_run: bool, timeout: u64) -> i32 {
    let procs = proc::scan();

    // Idempotent: stopping a stopped tunnel is a success, not an error
    // (CLI Standard rule 3). An agent retrying after a timeout must not see a
    // failure just because the first attempt worked.
    if procs.is_empty() {
        out.say(Level::Ok, "no AdGuard VPN processes; nothing to stop");
        let report = tunnel::StopReport {
            actions: Vec::new(),
            removed: Vec::new(),
            residual: Vec::new(),
            tun_interfaces: Vec::new(),
            stopped: true,
        };
        out.emit(
            "steelbore-vpn tunnel stop",
            &report,
            dry_run,
            "  nothing to stop\n",
        );
        return Exit::Success as i32;
    }

    if dry_run || !yes {
        let plan = tunnel::plan(&procs);
        let mut human = String::from("  would signal:\n");
        for a in &plan {
            let _ = writeln!(human, "    {} -> pid {}  ({})", a.signal, a.pid, a.reason);
        }
        human.push_str("  nothing signalled. Re-run with --yes to apply.\n");
        out.emit("steelbore-vpn tunnel stop", &plan, true, &human);
        return Exit::Success as i32;
    }

    // Only now does privilege matter, so an unprivileged caller can still see
    // the plan above. The hint names a command the caller must run themselves:
    // it starts with `sudo`, so it is marked as human escalation rather than
    // offered as something an agent can retry (agentic-cli §12.5).
    if !tunnel::can_signal_tunnel() && procs.iter().any(|p| p.role == proc::Role::Tunnel) {
        return out.fail(
            &AppError::new(
                "PERMISSION_DENIED",
                Exit::Permission,
                "the tunnel process runs as root; stopping it needs root",
                "steelbore-vpn tunnel stop",
            )
            .with_hint(
                "requires human escalation: run `sudo steelbore-vpn tunnel stop --yes` yourself",
            ),
        );
    }

    let report = tunnel::stop(Duration::from_secs(timeout), out);

    let mut human = String::new();
    for a in &report.actions {
        let _ = writeln!(
            human,
            "  {} -> pid {}: {}",
            a.signal,
            a.pid,
            a.outcome.as_deref().unwrap_or("no outcome recorded")
        );
    }
    for r in &report.removed {
        let _ = writeln!(human, "  removed {r}");
    }

    if report.stopped {
        out.say(
            Level::Ok,
            "tunnel stopped; no processes and no tun interface remain",
        );
        out.emit("steelbore-vpn tunnel stop", &report, false, &human);
        return Exit::Success as i32;
    }

    // Report the residue precisely. "Mostly stopped" is the state that started
    // all this, and calling it success is how it stayed invisible.
    let what = if report.residual.is_empty() {
        format!(
            "tun interface still present: {}",
            report.tun_interfaces.join(", ")
        )
    } else {
        format!(
            "process(es) still running: {}",
            report
                .residual
                .iter()
                .map(|p| p.pid.to_string())
                .collect::<Vec<_>>()
                .join(", ")
        )
    };
    out.emit("steelbore-vpn tunnel stop", &report, false, &human);
    out.fail(
        &AppError::new(
            "STOP_INCOMPLETE",
            Exit::Failure,
            format!("teardown did not fully complete: {what}"),
            "steelbore-vpn tunnel stop",
        )
        .with_hint("steelbore-vpn tunnel status --json   # inspect what survived"),
    )
}

fn cmd_schema(out: Out) -> i32 {
    // Hand-written rather than derived, matching preflight: `schemars` would add
    // a dependency and a derive on every struct to describe a surface this
    // small, and the exit-code table has no derive source at all.
    let schema = serde_json::json!({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "steelbore-vpn",
        "description": "AdGuard VPN tunnel inspector and teardown helper",
        "commands": {
            "steelbore-vpn tunnel status": {
                "description": "Whether a tunnel is up, plus route-script and stale-file checks",
                "privileged": false
            },
            "steelbore-vpn tunnel list": {
                "description": "Every AdGuard VPN process, with role and signal state",
                "privileged": false
            },
            "steelbore-vpn tunnel stop": {
                "description": "Tear the tunnel down in an order that strands nothing",
                "privileged": true,
                "flags": {
                    "--yes": "actually signal; without it the plan is printed and nothing happens",
                    "--dry-run": "print the plan and exit, even with --yes",
                    "--timeout": "seconds to wait before escalating SIGTERM to SIGKILL (default 10)"
                }
            },
            "steelbore-vpn schema": { "description": "This document" },
            "steelbore-vpn describe": { "description": "Capability manifest" }
        },
        "exit_codes": {
            "0": "success (including a tunnel that was already stopped)",
            "1": "teardown did not fully complete; something survived",
            "2": "usage error",
            "4": "permission denied; the tunnel runs as root and this caller is not"
        },
        "route_script_contract": {
            "path": "$AGVPN_CLI_DATA_PATH/setup_routes.sh",
            "owner": "root:root",
            "mode": "0700",
            "argv": ["$1 = tunnel interface name"],
            "note": "enforced by adguardvpn-cli itself; it executes this file as root"
        }
    });
    let human = format!("{schema:#}\n");
    out.emit("steelbore-vpn schema", &schema, false, &human);
    Exit::Success as i32
}

fn cmd_describe(out: Out) -> i32 {
    let manifest = serde_json::json!({
        "tool": env!("CARGO_PKG_NAME"),
        "version": env!("CARGO_PKG_VERSION"),
        "summary": env!("CARGO_PKG_DESCRIPTION"),
        "data_dir": tunnel::data_dir().display().to_string(),
        "maintainer": output::MAINTAINER,
        "website": output::WEBSITE,
        "capabilities": [
            "tunnel-status",
            "tunnel-list",
            "tunnel-stop",
            "route-script-check",
        ],
        // Nothing is shelled out to. The /proc walk and kill(2) are the whole
        // implementation, which is deliberate: this tool is meant to work when
        // the session is already unhealthy.
        "external_tools": [],
    });
    let human = format!("{manifest:#}\n");
    out.emit("steelbore-vpn describe", &manifest, false, &human);
    Exit::Success as i32
}
