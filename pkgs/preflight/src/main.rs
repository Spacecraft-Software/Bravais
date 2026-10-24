// SPDX-License-Identifier: GPL-3.0-or-later
//
// preflight — Steelbore OS rebuild orchestrator.
//
// Preflight checks, the switch, postflight accounting. A Rust port of the
// Nushell `rebuild` (users/mj/rebuild-classic.nu, embedded by users/mj/shell.nix) and
// scripts/rebuild-classic.sh, which it is meant to replace as the single
// implementation rather than join as a third one: two copies of this sequence
// already drifted, and AGENTS.md still has to say "change one and change all
// three". Retiring the two shells is the remaining step; docs/rebuild.md
// describes the deprecation question both open with today.
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

mod ai_tools;
mod appimages;
mod deps_commit;
mod disk;
mod git_sync;
mod output;
mod progress;
mod steps;

use std::fmt::Write as _;

use clap::{Parser, Subcommand};

use output::{AppError, ColorWhen, Exit, Format, Level, Out};

/// One-line summary for `--help` and `describe`. The OS name (and the URL in
/// the help text below) come from lib/identity.nix via build.rs, so this
/// binary never restates them; Cargo.toml's static `description` cannot.
const ABOUT: &str = concat!(
    env!("STEELBORE_OS_NAME"),
    " rebuild orchestrator: preflight checks, the switch, postflight disk accounting."
);

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
        env!("STEELBORE_OS_URL")
    ),
    about = ABOUT,
    after_help = concat!(
        "EXAMPLES:\n",
        "  preflight                     Full rebuild: sync with origin, update, switch, mirror, report\n",
        "  preflight --branch <NAME>     Switch to origin's <NAME> first (testing a PR), then rebuild\n",
        "  preflight --no-sync           Skip the fetch; build the checkout exactly as it is\n",
        "  preflight --dry               Dry-build only; no GC, no mirror, no deletion\n",
        "  preflight --skills-only       Bump `construct` and switch; skip GC and mirror\n",
        "  preflight --update-all        Also bump the vendored pins and AI tools (alias: --full-update)\n",
        "  preflight --update-vendored   Also bump pinned upstream binaries (claude-desktop, …)\n",
        "  preflight --update-ai-tools   Also run the out-of-band AI tools' updaters (claude, codex, …)\n",
        "  preflight --update-appimages  Also apply the AppImage updates Gear Lever finds\n",
        "  preflight --no-commit         Leave the bumps uncommitted instead of committing them\n",
        "  preflight --reclaim           Reclaim safe caches before the switch\n",
        "  preflight --gc-all            Collect every old generation (no rollback)\n",
        "  preflight --mcp-deploy        Also deploy MCP host configs after the switch\n",
        "  preflight --detach-flatpak    Start the Flatpak update and return instead of following it\n",
        "  preflight flatpak watch       Follow a running Flatpak update with a progress bar\n",
        "  preflight appimage status     Which AppImages have updates (asks Gear Lever)\n",
        "  preflight disk report --json  Machine-readable free space and reclaimable bytes\n",
        "\n",
        "Maintained by Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>\n",
        env!("STEELBORE_OS_URL")
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

    /// Build the checkout as it is: skip the git fetch and fast-forward
    #[arg(long)]
    no_sync: bool,

    /// Switch the checkout to this branch from origin before building (e.g. a PR branch)
    #[arg(long, short = 'b', value_name = "NAME", value_parser = git_sync::parse_branch, conflicts_with = "no_sync")]
    branch: Option<String>,

    /// Skip `nix flake update`
    #[arg(long)]
    no_update: bool,

    /// Update everything: every flake input (as always), the vendored pins, the out-of-band AI tools and the AppImages; implies --update-vendored, --update-ai-tools and --update-appimages
    // `--full-update` is the spelling people reach for. Without the alias,
    // clap's did-you-mean answered it with `--no-update` -- the opposite
    // request, which a user following the tip would have run.
    #[arg(long, visible_alias = "full-update", conflicts_with_all = ["no_update", "skills_only"])]
    update_all: bool,

    /// Also bump the version+hash-pinned upstream binaries (pkgs/update-vendored.nu)
    #[arg(long, conflicts_with = "skills_only")]
    update_vendored: bool,

    /// Also run the self-updaters of the AI tools installed outside Nix (claude update, opencode upgrade, …)
    #[arg(long, conflicts_with = "skills_only")]
    update_ai_tools: bool,

    /// Also apply the AppImage updates Gear Lever finds (the report-only check runs on every run)
    #[arg(long, conflicts_with_all = ["skills_only", "no_appimages"])]
    update_appimages: bool,

    /// Skip the AppImage update check
    #[arg(long)]
    no_appimages: bool,

    /// Leave the bumped flake.lock and vendored pins uncommitted (default: commit them on a chore/deps-bump-<date> branch after a successful switch)
    #[arg(long)]
    no_commit: bool,

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

    /// Start the Flatpak update and return instead of following its progress (always the case off a terminal)
    #[arg(long, conflicts_with = "no_flatpak")]
    detach_flatpak: bool,

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
    /// AppImages: which have updates (asks Gear Lever)
    Appimage {
        #[command(subcommand)]
        action: AppimageCmd,
    },
    /// Disk space accounting
    Disk {
        #[command(subcommand)]
        action: DiskCmd,
    },
    /// The detached Flatpak update: progress now, or followed to the end
    Flatpak {
        #[command(subcommand)]
        action: FlatpakCmd,
    },
    /// Emit the JSON Schema of the command surface
    Schema,
    /// Emit a compact capability manifest
    Describe,
}

#[derive(Subcommand, Debug)]
enum FlatpakCmd {
    /// Whether an update is running, and how far it has got
    Status,
    /// Follow a running update to its end with a progress bar (off a terminal: wait, then report)
    Watch,
}

#[derive(Subcommand, Debug)]
enum AppimageCmd {
    /// List the AppImages with updates, and those Gear Lever does not manage
    Status,
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
        Some(Cmd::Flatpak { action }) => cmd_flatpak(out, matches!(action, FlatpakCmd::Watch)),
        Some(Cmd::Appimage {
            action: AppimageCmd::Status,
        }) => cmd_appimage_status(out),
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

/// The run's options as the flags select them.
fn options(cli: &Cli) -> steps::Options<'_> {
    steps::Options {
        dry: cli.dry,
        sync: !cli.no_sync,
        branch: cli.branch.as_deref(),
        no_update: cli.no_update,
        // "Update everything" has to include the pins `nix flake update`
        // cannot move, or it silently leaves the stalest things in the tree
        // behind -- exactly what a user reaching for --update-all wants gone.
        update_vendored: cli.update_vendored || cli.update_all,
        // The same for the AI tools outside Nix, which no rebuild reaches.
        update_ai_tools: cli.update_ai_tools || cli.update_all,
        // The check is cheap (one small request per source) and report-only,
        // so it runs unasked; applying is the part that downloads.
        check_appimages: !cli.no_appimages,
        update_appimages: cli.update_appimages || (cli.update_all && !cli.no_appimages),
        no_commit: cli.no_commit,
        no_gc: cli.no_gc,
        trace: cli.trace,
        skills_only: cli.skills_only,
        no_flatpak: cli.no_flatpak,
        detach_flatpak: cli.detach_flatpak,
        reclaim: cli.reclaim,
        gc_all: cli.gc_all,
        journal_days: cli.journal_days,
        mcp_deploy: cli.mcp_deploy,
    }
}

fn cmd_run(out: Out, cli: &Cli) -> i32 {
    let (report, switched) = match steps::run(out, options(cli)) {
        Ok(done) => done,
        Err(refused) => {
            return out.fail(
                &AppError::new(refused.code, refused.exit, refused.message, "preflight")
                    .with_hint(refused.hint),
            );
        }
    };

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

/// What `preflight flatpak status|watch` report.
#[derive(Debug, serde::Serialize)]
struct FlatpakStatus {
    running: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pid: Option<u32>,
    log: String,
    progress: progress::FlatpakProgress,
}

fn flatpak_status(log: &std::path::Path) -> FlatpakStatus {
    let pid = progress::running_update();
    FlatpakStatus {
        running: pid.is_some(),
        pid,
        log: log.display().to_string(),
        progress: progress::read_tail(log)
            .map(|t| progress::parse(&t))
            .unwrap_or_default(),
    }
}

fn cmd_flatpak(out: Out, watch: bool) -> i32 {
    let log = steps::flatpak_log();
    let command = if watch {
        "preflight flatpak watch"
    } else {
        "preflight flatpak status"
    };
    if watch && progress::running_update().is_some() {
        progress::note(
            out,
            "following the Flatpak update — Ctrl-C stops following; the update keeps running",
        );
        progress::watch_flatpak(out, &log, &mut || progress::running_update().is_some());
    }
    let st = flatpak_status(&log);
    let p = &st.progress;
    let state = if st.running {
        match (p.percent, p.op, p.ops) {
            (Some(pct), Some(a), Some(b)) => format!("running — operation {a}/{b}, {pct}% overall"),
            (Some(pct), _, _) => format!("running — {pct}%"),
            _ => "running".to_owned(),
        }
    } else {
        "not running".to_owned()
    };
    let human = format!(
        "  flatpak update: {state}\n  last line:      {}\n  log:            {}\n",
        p.line.as_deref().unwrap_or("(no run recorded)"),
        st.log
    );
    out.emit(command, &st, false, &human);
    Exit::Success as i32
}

fn cmd_appimage_status(out: Out) -> i32 {
    const COMMAND: &str = "preflight appimage status";
    if !appimages::gear_lever_installed() {
        return out.fail(
            &AppError::new(
                "NO_GEAR_LEVER",
                Exit::NotFound,
                "Gear Lever is not installed, and it is what checks AppImages",
                COMMAND,
            )
            .with_hint(format!("flatpak install flathub {}", appimages::GEAR_LEVER)),
        );
    }
    match progress::spin(out, "checking AppImages for updates", appimages::check) {
        Ok(rep) => {
            let mut human = format!("  managed by Gear Lever: {}\n", rep.managed);
            if rep.updates.is_empty() {
                human.push_str("  updates:               none\n");
            }
            for u in &rep.updates {
                let running = if u.running == Some(true) {
                    "  (running)"
                } else {
                    ""
                };
                let _ = writeln!(
                    human,
                    "  update:    {}  {}{running}",
                    u.name,
                    u.current_version.as_deref().unwrap_or("?")
                );
            }
            for u in &rep.unmanaged {
                let _ = writeln!(
                    human,
                    "  unmanaged: {}  {}",
                    u.path,
                    u.update_info
                        .as_deref()
                        .unwrap_or("(no update information)")
                );
            }
            if !rep.updates.is_empty() {
                let _ = writeln!(human, "  apply:     {}", appimages::update_command());
            }
            out.emit(COMMAND, &rep, false, &human);
            Exit::Success as i32
        }
        Err(e) => out.fail(
            &AppError::new("APPIMAGE_CHECK_FAILED", Exit::Failure, e, COMMAND).with_hint(format!(
                "flatpak run {} --list-updates",
                appimages::GEAR_LEVER
            )),
        ),
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
        "description": concat!(env!("STEELBORE_OS_NAME"), " rebuild orchestrator"),
        "commands": {
            "preflight": {
                "description": "Run the rebuild sequence",
                "flags": {
                    "--dry": "dry-build; make no changes (the git sync fetches and reports what it would do, but does not move the checkout)",
                    "--no-sync": "build the checkout as it is; skip git fetch and the fast-forward",
                    "--branch": "switch to origin's <NAME> before building (testing a PR); conflicts with --no-sync",
                    "--no-update": "skip nix flake update",
                    "--update-all": "update everything: every flake input (a full run always bumps them all) plus --update-vendored, --update-ai-tools and --update-appimages (unless --no-appimages); conflicts with --no-update and --skills-only; alias --full-update",
                    "--update-vendored": "run pkgs/update-vendored.nu before the switch (--check under --dry); conflicts with --skills-only",
                    "--update-appimages": "after the switch, whether or not it succeeded, apply the AppImage updates Gear Lever found (flatpak run it.mijorus.gearlever --update --all --yes; running apps are skipped); listed only under --dry; killed after 1800 s; implied by --update-all unless --no-appimages; conflicts with --skills-only and --no-appimages",
                    "--no-appimages": "skip the AppImage update check (a full run asks Gear Lever which AppImages have updates, report-only)",
                    "--update-ai-tools": "after the switch, run each installed out-of-band AI tool's own updater (`preflight describe` lists them); skipped if not installed or Nix-managed, listed only under --dry, killed after 1800 s; conflicts with --skills-only",
                    "--no-commit": "leave the bumps uncommitted; by default, after a successful switch on origin's default branch, the paths this run bumped (flake.lock, the vendored pins, and .github/skills/ re-synced by pkgs/sync-skills.nu when construct moved) are committed with a plain `git commit` (the user's signing config) on a new local chore/deps-bump-<date> branch, never pushed, and the checkout switches back; on another branch, under --dry or after a failed switch they are left uncommitted",
                    "--no-gc": "skip garbage collection and journal vacuum",
                    "--trace": "pass --show-trace --verbose to nixos-rebuild",
                    "--skills-only": "bump construct only; skip GC, mirror, mcpctl probe",
                    "--no-flatpak": "skip the detached Flatpak update",
                    "--detach-flatpak": "start the Flatpak update and return; without it a live (terminal, non-agent) run follows the update to its end with a progress bar, and Ctrl-C stops following without stopping the update; conflicts with --no-flatpak",
                    "--reclaim": "reclaim safe caches before the switch",
                    "--gc-all": "nix-collect-garbage -d; deletes every old generation",
                    "--journal-days": "journalctl --vacuum-time, in days (default 7)",
                    "--mcp-deploy": "run mcpctl deploy --yes after the switch; blocked hosts are warned about individually"
                }
            },
            "preflight flatpak status": { "description": "Whether a Flatpak update is running, and its progress parsed from ~/.local/state/flatpak-update.log: op/ops, op_percent, percent (each operation an equal share), rate, line" },
            "preflight flatpak watch": { "description": "Follow a running Flatpak update to its end (progress bar at a terminal; otherwise block, then emit the final status)" },
            "preflight appimage status": { "description": "AppImages with updates (Gear Lever's --list-updates --json, schema 1) and AppImages in ~/Applications or ~/AppImages it does not manage, with their embedded update information" },
            "preflight disk report": { "description": "Free space and reclaimable bytes" },
            "preflight disk reclaim": { "description": "Reclaim safe caches; --yes to apply" },
            "preflight schema": { "description": "This document" },
            "preflight describe": { "description": "Capability manifest" }
        },
        "exit_codes": {
            "0": "success",
            "1": "general failure (the switch did not complete; or the git sync could not run: FETCH_FAILED, SWITCH_FAILED, NOT_A_CHECKOUT)",
            "2": "usage error",
            "3": "resource not found (no watched mount exists; NO_SUCH_BRANCH for --branch)",
            "4": "permission denied",
            "5": "conflict: the git sync refused to move the checkout (DIRTY_TREE, NO_UPSTREAM, LOCK_CONFLICT, NOT_FAST_FORWARD); nothing was built"
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
        "summary": ABOUT,
        "host": steps::HOST,
        "flake_dir": steps::FLAKE_DIR,
        "maintainer": output::MAINTAINER,
        "website": output::WEBSITE,
        "capabilities": [
            "git-sync",
            "deps-commit",
            "rebuild-orchestration",
            "flatpak-progress",
            "appimage-updates",
            "disk-report",
            "disk-reclaim",
        ],
        "external_tools": external_tools(),
        "ai_tools": ai_tools::TOOLS.iter().map(ai_tools::Tool::command_line).collect::<Vec<_>>(),
    });
    let human = format!("{manifest:#}\n");
    out.emit("preflight describe", &manifest, false, &human);
    Exit::Success as i32
}

/// Every program preflight runs, the AI tools' updaters included.
fn external_tools() -> Vec<&'static str> {
    let mut tools = vec![
        "nixos-rebuild",
        "nix",
        "sudo",
        "rsync",
        "vacuum",
        "gitway-add",
        "mcpctl",
        "flatpak",
        "nu",
        "git",
    ];
    for t in ai_tools::TOOLS {
        if !tools.contains(&t.program) {
            tools.push(t.program);
        }
    }
    tools
}

#[cfg(test)]
mod tests {
    use super::*;
    use clap::CommandFactory;

    #[test]
    fn the_flag_surface_is_well_formed() {
        // Catches clashing names, dangling `conflicts_with` targets and the
        // like at test time instead of at a user's first invocation.
        Cli::command().debug_assert();
    }

    #[test]
    fn full_update_is_an_alias_for_update_all() {
        let cli = Cli::try_parse_from(["preflight", "--full-update"]);
        assert!(cli.is_ok_and(|c| c.update_all));
    }

    #[test]
    fn full_update_implies_both_extra_update_steps() {
        let cli = Cli::try_parse_from(["preflight", "--full-update"]);
        assert!(cli.is_ok_and(|c| {
            let o = options(&c);
            o.update_vendored && o.update_ai_tools
        }));
    }

    #[test]
    fn update_ai_tools_alone_leaves_the_vendored_pins() {
        let cli = Cli::try_parse_from(["preflight", "--update-ai-tools"]);
        assert!(cli.is_ok_and(|c| {
            let o = options(&c);
            o.update_ai_tools && !o.update_vendored
        }));
    }

    #[test]
    fn a_plain_run_updates_no_ai_tools() {
        let cli = Cli::try_parse_from(["preflight"]);
        assert!(cli.is_ok_and(|c| !options(&c).update_ai_tools));
    }

    #[test]
    fn update_ai_tools_conflicts_with_skills_only() {
        assert!(Cli::try_parse_from(["preflight", "--update-ai-tools", "--skills-only"]).is_err());
    }

    #[test]
    fn a_plain_run_syncs_and_no_sync_turns_it_off() {
        let on = Cli::try_parse_from(["preflight"]);
        assert!(on.is_ok_and(|c| options(&c).sync));
        let off = Cli::try_parse_from(["preflight", "--no-sync"]);
        assert!(off.is_ok_and(|c| !options(&c).sync));
    }

    #[test]
    fn branch_conflicts_with_no_sync_and_rejects_flag_lookalikes() {
        assert!(Cli::try_parse_from(["preflight", "--branch", "x", "--no-sync"]).is_err());
        assert!(Cli::try_parse_from(["preflight", "--branch=-f"]).is_err());
        let ok = Cli::try_parse_from(["preflight", "-b", "origin/claude/x"]);
        assert!(ok.is_ok_and(|c| c.branch.as_deref() == Some("claude/x")));
    }

    #[test]
    fn detach_flatpak_is_off_by_default_and_refuses_no_flatpak() {
        assert!(Cli::try_parse_from(["preflight"]).is_ok_and(|c| !options(&c).detach_flatpak));
        assert!(Cli::try_parse_from(["preflight", "--detach-flatpak"])
            .is_ok_and(|c| options(&c).detach_flatpak));
        assert!(Cli::try_parse_from(["preflight", "--detach-flatpak", "--no-flatpak"]).is_err());
    }

    #[test]
    fn appimages_are_checked_by_default_and_updated_on_request() {
        assert!(Cli::try_parse_from(["preflight"]).is_ok_and(|c| {
            let o = options(&c);
            o.check_appimages && !o.update_appimages
        }));
        assert!(Cli::try_parse_from(["preflight", "--update-appimages"])
            .is_ok_and(|c| options(&c).update_appimages));
        assert!(Cli::try_parse_from(["preflight", "--full-update"])
            .is_ok_and(|c| options(&c).update_appimages));
        assert!(
            Cli::try_parse_from(["preflight", "--full-update", "--no-appimages"]).is_ok_and(|c| {
                let o = options(&c);
                !o.check_appimages && !o.update_appimages
            })
        );
        for other in ["--no-appimages", "--skills-only"] {
            assert!(Cli::try_parse_from(["preflight", "--update-appimages", other]).is_err());
        }
    }

    #[test]
    fn bumps_are_committed_unless_no_commit() {
        assert!(Cli::try_parse_from(["preflight"]).is_ok_and(|c| !options(&c).no_commit));
        assert!(
            Cli::try_parse_from(["preflight", "--no-commit"]).is_ok_and(|c| options(&c).no_commit)
        );
    }

    #[test]
    fn full_update_keeps_the_update_all_conflicts() {
        // An alias is the same argument, so it must refuse the same company.
        for other in ["--no-update", "--skills-only"] {
            assert!(
                Cli::try_parse_from(["preflight", "--full-update", other]).is_err(),
                "--full-update must conflict with {other}"
            );
        }
    }
}
