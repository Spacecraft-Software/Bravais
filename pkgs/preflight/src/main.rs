// SPDX-License-Identifier: GPL-3.0-or-later
//
// preflight — Steelbore OS rebuild orchestrator.
//
// Preflight checks, the switch, postflight accounting. A Rust port of the
// Nushell `def rebuild` (users/mj/shell.nix) and scripts/rebuild.sh, which it
// is meant to replace as the single implementation rather than join as a third
// one: two copies of this sequence already drifted, and the AGENTS.md note
// telling a maintainer to "change one and change the other" is the smell this
// port exists to remove.
//
// What it adds over both: disk accounting is a first-class step rather than a
// pair of `df` banners. The report is always emitted; reclamation happens on
// `--reclaim`, or unasked when free space is low enough that the switch would
// likely fail part-way (see disk::LOW_WATER_BYTES).
//
// Standard §3.1: no `unwrap`/`expect` on any fallible runtime path. Subprocess
// and filesystem failures are recorded as step outcomes and reported, because a
// probe that cannot run is information, not a reason to abandon a rebuild.
//
// `mimalloc` (M-MIMALLOC-APPS) is intentionally omitted: this process allocates
// a few hundred small strings and then blocks in `waitpid` for minutes. There
// is no allocation hot path to speed up, and the allocator would be pure
// closure weight on a tool whose whole job is to run other programs.

mod disk;
mod output;
mod steps;

use clap::{Parser, Subcommand};

use output::{AppError, ColorWhen, Exit, Format, Level, Out};

#[derive(Parser, Debug)]
#[command(
    name = "preflight",
    version,
    // §15.2 requires --version to carry the maintainer and the project URL.
    // clap's bare `version` prints name + number only, so the attribution goes
    // in long_version, which is what both -V and --version render.
    long_version = concat!(
        env!("CARGO_PKG_VERSION"), "\n",
        "Maintained by Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>\n",
        "Copyright (C) 2026 Mohamed Hammad & Spacecraft Software  |  License: GPL-3.0-or-later\n",
        "https://Bravais.SpacecraftSoftware.org/"
    ),
    about = "Steelbore OS rebuild orchestrator: preflight checks, the switch, postflight disk accounting.",
    after_help = concat!(
        "EXAMPLES:\n",
        "  preflight                     Full rebuild: update, switch, mirror, report\n",
        "  preflight --dry               Dry-build only; no GC, no mirror, no deletion\n",
        "  preflight --skills-only       Bump `construct` and switch; skip GC and mirror\n",
        "  preflight --reclaim           Reclaim safe caches before the switch\n",
        "  preflight --gc-all            Collect every old generation (no rollback)\n",
        "  preflight --mcp-deploy        Also deploy MCP host configs after the switch\n",
        "  preflight disk report --json  Machine-readable free space and reclaimable bytes\n",
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
    command: Option<Cmd>,

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

    /// Dry-build; make no changes
    #[arg(long, visible_alias = "dry-run")]
    dry: bool,

    /// Skip `nix flake update`
    #[arg(long)]
    no_update: bool,

    /// Skip garbage collection and journal vacuum
    #[arg(long)]
    no_gc: bool,

    /// Pass --show-trace --verbose to nixos-rebuild
    #[arg(long)]
    trace: bool,

    /// Bump only `construct`; skip GC, the /etc/nixos mirror and the mcpctl probe
    #[arg(long)]
    skills_only: bool,

    /// Skip the detached Flatpak update
    #[arg(long)]
    no_flatpak: bool,

    /// Reclaim safe caches before the switch (implied when /nix is low)
    #[arg(long)]
    reclaim: bool,

    /// Collect every old generation (nix-collect-garbage -d) instead of keeping a week
    #[arg(long)]
    gc_all: bool,

    /// Journal retention for journalctl --vacuum-time, in days
    #[arg(long, value_name = "DAYS", default_value_t = 7)]
    journal_days: u32,

    /// Deploy MCP host configs after the switch (default: report drift only)
    #[arg(long)]
    mcp_deploy: bool,
}

#[derive(Subcommand, Debug)]
enum Cmd {
    /// Disk space accounting
    Disk {
        #[command(subcommand)]
        action: DiskCmd,
    },
    /// Emit the JSON Schema of the command surface
    Schema,
    /// Emit a compact capability manifest
    Describe,
}

#[derive(Subcommand, Debug)]
enum DiskCmd {
    /// Show free space on the real paths and what is reclaimable
    Report,
    /// Reclaim safe caches (dry-run unless --yes)
    Reclaim {
        /// Actually delete. Without this the command only reports.
        #[arg(long)]
        yes: bool,
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
        Some(Cmd::Schema) => cmd_schema(out),
        Some(Cmd::Describe) => cmd_describe(out),
        Some(Cmd::Disk { action }) => match action {
            DiskCmd::Report => cmd_disk_report(out),
            DiskCmd::Reclaim { yes } => cmd_disk_reclaim(out, *yes),
        },
        None => cmd_run(out, &cli),
    };

    #[expect(
        clippy::cast_possible_truncation,
        clippy::cast_sign_loss,
        reason = "exit codes are 0..=125 by construction; the enum has no other values"
    )]
    std::process::ExitCode::from(code as u8)
}

fn cmd_run(out: Out, cli: &Cli) -> i32 {
    let opts = steps::Options {
        dry: cli.dry,
        no_update: cli.no_update,
        no_gc: cli.no_gc,
        trace: cli.trace,
        skills_only: cli.skills_only,
        no_flatpak: cli.no_flatpak,
        reclaim: cli.reclaim,
        gc_all: cli.gc_all,
        journal_days: cli.journal_days,
        mcp_deploy: cli.mcp_deploy,
    };
    let (report, switched) = steps::run(out, opts);

    let human = String::new(); // the sequence narrates on stderr as it goes
    out.emit("preflight", &report, cli.dry, &human);

    if switched {
        Exit::Success as i32
    } else {
        out.fail(
            &AppError::new(
                "REBUILD_FAILED",
                Exit::Failure,
                "nixos-rebuild did not complete",
                "preflight",
            )
            .with_hint("preflight --trace   # re-run with --show-trace --verbose"),
        )
    }
}

fn cmd_disk_report(out: Out) -> i32 {
    let mut r = disk::measure();
    r.reclaimable_bytes = disk::reclaimable();
    if r.mounts.is_empty() {
        return out.fail(
            &AppError::new(
                "NO_MOUNTS",
                Exit::NotFound,
                "none of the watched paths exist",
                "preflight disk report",
            )
            .with_hint("df -h /nix   # confirm the partition layout"),
        );
    }
    let human = disk::render(&r, "disk");
    out.emit("preflight disk report", &r, false, &human);
    Exit::Success as i32
}

fn cmd_disk_reclaim(out: Out, yes: bool) -> i32 {
    if !yes {
        let mut r = disk::measure();
        r.reclaimable_bytes = disk::reclaimable();
        let human = format!(
            "{}\n  dry run — nothing deleted. Re-run with --yes to reclaim.\n",
            disk::render(&r, "disk")
        );
        out.emit("preflight disk reclaim", &r, true, &human);
        return Exit::Success as i32;
    }
    match disk::reclaim() {
        Ok(got) => {
            let human = format!("  freed {}\n", disk::human(got.freed_bytes));
            out.say(
                Level::Ok,
                &format!("reclaimed {}", disk::human(got.freed_bytes)),
            );
            out.emit("preflight disk reclaim", &got, false, &human);
            Exit::Success as i32
        }
        Err(e) => out.fail(
            &AppError::new(
                "RECLAIM_FAILED",
                Exit::Failure,
                e.to_string(),
                "preflight disk reclaim",
            )
            .with_hint("vacuum list   # inspect the candidates by hand"),
        ),
    }
}

fn cmd_schema(out: Out) -> i32 {
    // Hand-written rather than derived: `schemars` would add a dependency and a
    // derive on every options struct to describe a surface this small, and the
    // exit-code table below has no derive source at all.
    let schema = serde_json::json!({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "preflight",
        "description": "Steelbore OS rebuild orchestrator",
        "commands": {
            "preflight": {
                "description": "Run the rebuild sequence",
                "flags": {
                    "--dry": "dry-build; make no changes",
                    "--no-update": "skip nix flake update",
                    "--no-gc": "skip garbage collection and journal vacuum",
                    "--trace": "pass --show-trace --verbose to nixos-rebuild",
                    "--skills-only": "bump construct only; skip GC, mirror, mcpctl probe",
                    "--no-flatpak": "skip the detached Flatpak update",
                    "--reclaim": "reclaim safe caches before the switch",
                    "--gc-all": "nix-collect-garbage -d; deletes every old generation",
                    "--journal-days": "journalctl --vacuum-time, in days (default 7)",
                    "--mcp-deploy": "run mcpctl deploy --yes after the switch; blocked hosts are warned about individually"
                }
            },
            "preflight disk report": { "description": "Free space and reclaimable bytes" },
            "preflight disk reclaim": { "description": "Reclaim safe caches; --yes to apply" },
            "preflight schema": { "description": "This document" },
            "preflight describe": { "description": "Capability manifest" }
        },
        "exit_codes": {
            "0": "success",
            "1": "general failure (the switch did not complete)",
            "2": "usage error",
            "3": "resource not found (no watched mount exists)",
            "4": "permission denied"
        },
        "safe_categories": disk::SAFE_CATEGORIES,
        "low_water_bytes": disk::LOW_WATER_BYTES
    });
    let human = format!("{schema:#}\n");
    out.emit("preflight schema", &schema, false, &human);
    Exit::Success as i32
}

fn cmd_describe(out: Out) -> i32 {
    let manifest = serde_json::json!({
        "tool": env!("CARGO_PKG_NAME"),
        "version": env!("CARGO_PKG_VERSION"),
        "summary": env!("CARGO_PKG_DESCRIPTION"),
        "host": steps::HOST,
        "flake_dir": steps::FLAKE_DIR,
        "maintainer": output::MAINTAINER,
        "website": output::WEBSITE,
        "capabilities": [
            "rebuild-orchestration",
            "disk-report",
            "disk-reclaim",
        ],
        "external_tools": ["nixos-rebuild", "nix", "sudo", "rsync", "vacuum", "gitway-add", "mcpctl", "flatpak"],
    });
    let human = format!("{manifest:#}\n");
    out.emit("preflight describe", &manifest, false, &human);
    Exit::Success as i32
}
