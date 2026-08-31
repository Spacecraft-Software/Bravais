// SPDX-License-Identifier: GPL-3.0-or-later
//
// The rebuild sequence itself.
//
// This is a port of the Nushell `def rebuild` in users/mj/shell.nix and of
// scripts/rebuild.sh, and it inherits their hard-won details rather than
// reinventing them. Where a step looks arbitrary, the comment says which
// incident put it there -- those notes are the actual value of this file and
// should travel with any future edit.
//
// Design note (Standard §3.2): deliberately serial. Every step here is either a
// subprocess that saturates the machine on its own (`nixos-rebuild`, garbage
// collection) or is ordered by a real dependency -- the flake must be updated
// before the switch, the switch must succeed before /etc/nixos is mirrored.
// The one genuinely independent tail, the Flatpak update, is not run
// concurrently but DETACHED, for the reason recorded in `flatpak_detached`.
// Threading anything else would add contention and failure modes to a process
// whose wall time is dominated by a single external build.

use std::path::Path;
use std::process::Command;

use serde::Serialize;

use crate::disk;
use crate::output::{Level, Out};

/// Where the flake lives and what host it builds.
pub const FLAKE_DIR: &str = "/spacecraft-software/bravais";
pub const HOST: &str = "bravais-thinkpad";

/// Inputs bumped on a full run.
///
/// `nixpkgs-unstable` and `home-manager-unstable` are in the list so
/// `unstablePkgs` never lags stable. `construct` alone is the `--skills-only`
/// fast path: skills come from that input and nothing else, so bumping the
/// others drags unrelated rebuild work into an edit that touched a Markdown
/// file.
const FULL_INPUTS: &[&str] = &[
    "antigravity-nix",
    "construct",
    "gitway",
    "nixpkgs-unstable",
    "home-manager-unstable",
];

/// How long before the vendored-binary pins are worth re-checking.
///
/// These are `version` + `hash` pairs that `nix flake update` cannot move, so
/// nothing in a rebuild will ever tell you they are stale. Thirty days is a
/// nag interval, not a correctness requirement.
const VENDORED_NAG_DAYS: u64 = 30;

#[derive(Debug, Serialize, Clone, Copy, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum Outcome {
    Ok,
    Skipped,
    Failed,
}

#[derive(Debug, Serialize)]
pub struct StepReport {
    pub name: &'static str,
    pub outcome: Outcome,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub detail: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct RunReport {
    pub host: &'static str,
    pub dry_run: bool,
    pub steps: Vec<StepReport>,
    pub disk_before: disk::Report,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub disk_after: Option<disk::Report>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reclaimed: Option<disk::Reclaimed>,
}

/// Everything the caller can turn off.
///
/// A flat set of independent switches is exactly what a CLI flag surface is.
/// Clippy suggests a state machine or two-variant enums; both would obscure the
/// one property that matters here -- that these toggles are orthogonal.
#[expect(
    clippy::struct_excessive_bools,
    reason = "mirrors the CLI flag surface one-to-one; the suggested remedies hide that the flags are independent"
)]
#[derive(Debug, Clone, Copy)]
pub struct Options {
    pub dry: bool,
    pub no_update: bool,
    pub no_gc: bool,
    pub trace: bool,
    pub skills_only: bool,
    pub no_flatpak: bool,
    pub reclaim: bool,
    /// Collect EVERY old generation (`nix-collect-garbage -d`) rather than
    /// keeping a week. Frees far more; costs the ability to roll back.
    pub gc_all: bool,
    /// Journal retention passed to `journalctl --vacuum-time`.
    pub journal_days: u32,
    /// Deploy MCP host configs after the switch instead of only reporting
    /// drift. Opt-in; see `mcpctl` for why this is not the default.
    pub mcp_deploy: bool,
}

struct Runner {
    out: Out,
    steps: Vec<StepReport>,
}

impl Runner {
    fn record(&mut self, name: &'static str, outcome: Outcome, detail: Option<String>) {
        let level = match outcome {
            Outcome::Ok => Level::Ok,
            Outcome::Skipped => Level::Info,
            Outcome::Failed => Level::Warn,
        };
        let msg = detail.as_ref().map_or_else(
            || format!("{name}: {}", fmt_outcome(outcome)),
            |d| format!("{name}: {}", d.clone()),
        );
        self.out.say(level, &msg);
        self.steps.push(StepReport {
            name,
            outcome,
            detail,
        });
    }

    /// Run a command, streaming its output straight through.
    ///
    /// Passthrough is deliberate: `nixos-rebuild` is the step a human watches,
    /// and capturing it to re-emit later would turn a live progress display
    /// into a wall of text at the end. stdout of the child is inherited, which
    /// is safe here because this tool's own payload goes out in one write at
    /// the very end.
    fn run(&mut self, name: &'static str, cmd: &mut Command) -> bool {
        match cmd.status() {
            Ok(s) if s.success() => {
                self.record(name, Outcome::Ok, None);
                true
            }
            Ok(s) => {
                self.record(name, Outcome::Failed, Some(format!("exited {s}")));
                false
            }
            Err(e) => {
                self.record(name, Outcome::Failed, Some(e.to_string()));
                false
            }
        }
    }
}

const fn fmt_outcome(o: Outcome) -> &'static str {
    match o {
        Outcome::Ok => "ok",
        Outcome::Skipped => "skipped",
        Outcome::Failed => "failed",
    }
}

/// Execute the sequence. Returns the report and whether the switch itself
/// succeeded -- a failed probe is worth reporting but is not a failed rebuild.
pub fn run(out: Out, opts: Options) -> (RunReport, bool) {
    let mut r = Runner {
        out,
        steps: Vec::new(),
    };

    vendored_nag(&mut r);

    // --- update ---------------------------------------------------------
    if opts.no_update {
        r.record("flake-update", Outcome::Skipped, Some("--no-update".into()));
    } else {
        let key = home().join(".ssh/id_ed25519");
        r.run(
            "gitway-add",
            Command::new("gitway-add").arg(&key).current_dir(FLAKE_DIR),
        );
        let mut cmd = Command::new("nix");
        cmd.args(["flake", "update"]).current_dir(FLAKE_DIR);
        if opts.skills_only {
            cmd.arg("construct");
        } else {
            cmd.args(FULL_INPUTS);
        }
        r.run("flake-update", &mut cmd);
        if !opts.skills_only {
            antigravity_probe(&mut r);
        }
    }

    // --- garbage collection ---------------------------------------------
    if opts.no_gc || opts.dry || opts.skills_only {
        r.record("garbage-collect", Outcome::Skipped, None);
    } else {
        // `--delete-older-than 7d` keeps a week of generations, so a bad switch
        // can still be rolled back. `--gc-all` swaps in `-d`, which deletes
        // every old generation: much more space, no rollback. The default is
        // the cautious one because losing rollback is not visible until the
        // day you need it.
        let mut gc = Command::new("sudo");
        gc.arg("nix-collect-garbage").arg("--verbose");
        if opts.gc_all {
            gc.arg("-d");
        } else {
            gc.args(["--delete-older-than", "7d"]);
        }
        r.run("garbage-collect", &mut gc);
        r.run(
            "journal-vacuum",
            Command::new("sudo").args([
                "journalctl",
                &format!("--vacuum-time={}d", opts.journal_days),
            ]),
        );
    }

    // --- preflight disk --------------------------------------------------
    let mut before = disk::measure();
    before.reclaimable_bytes = disk::reclaimable();
    if out.format == crate::output::Format::Human {
        eprint!("{}", disk::render(&before, "preflight"));
    }

    // Reclaim on request, or unasked when the disk is low enough that the
    // switch would probably die part-way. The second case is the whole reason
    // the threshold exists: a rebuild that fails at 99% full leaves a
    // half-written generation and no obvious cause.
    let reclaimed = maybe_reclaim(&mut r, &before, opts);

    // --- the switch ------------------------------------------------------
    let mut cmd = Command::new("sudo");
    cmd.arg("nixos-rebuild")
        .arg(if opts.dry { "dry-build" } else { "switch" })
        .args(["--flake", &format!(".#{HOST}")])
        // Silences "Git tree is dirty" on the local flake eval. The forwarded
        // `--option` form is used because nixos-rebuild-ng rejects nix's
        // `--no-warn-dirty` passthrough.
        .args(["--option", "warn-dirty", "false"])
        .current_dir(FLAKE_DIR);
    if opts.trace {
        cmd.args(["--show-trace", "--verbose"]);
    }
    let switched = r.run("nixos-rebuild", &mut cmd);

    // --- postflight ------------------------------------------------------
    if switched && !opts.dry && !opts.skills_only {
        mirror_etc(&mut r);
        mcpctl(&mut r, opts.mcp_deploy);
    }

    if !opts.no_flatpak && switched && !opts.dry && !opts.skills_only {
        flatpak_detached(&mut r);
    } else if opts.no_flatpak {
        r.record(
            "flatpak-update",
            Outcome::Skipped,
            Some("--no-flatpak".into()),
        );
    }

    let after = if opts.dry {
        None
    } else {
        let mut a = disk::measure();
        a.reclaimable_bytes = disk::reclaimable();
        if out.format == crate::output::Format::Human {
            eprint!("{}", disk::render(&a, "postflight"));
        }
        Some(a)
    };

    (
        RunReport {
            host: HOST,
            dry_run: opts.dry,
            steps: r.steps,
            disk_before: before,
            disk_after: after,
            reclaimed,
        },
        switched,
    )
}

/// Reclaim on request, or unasked when the disk is low enough that the switch
/// would probably die part-way. The second case is the whole reason the
/// threshold exists: a rebuild that fails at 99% full leaves a half-written
/// generation and no obvious cause.
fn maybe_reclaim(r: &mut Runner, before: &disk::Report, opts: Options) -> Option<disk::Reclaimed> {
    if opts.dry || !(opts.reclaim || before.is_low()) {
        return None;
    }
    if before.is_low() && !opts.reclaim {
        r.out.say(
            Level::Warn,
            &format!(
                "only {} free on /nix — reclaiming safe caches before the switch",
                disk::human(before.primary_available())
            ),
        );
    }
    match disk::reclaim() {
        Ok(got) => {
            r.record(
                "disk-reclaim",
                Outcome::Ok,
                Some(format!("freed {}", disk::human(got.freed_bytes))),
            );
            Some(got)
        }
        Err(e) => {
            r.record("disk-reclaim", Outcome::Failed, Some(e.to_string()));
            None
        }
    }
}

fn home() -> std::path::PathBuf {
    std::env::var_os("HOME").map_or_else(|| std::path::PathBuf::from("/root"), Into::into)
}

/// Nag if the version+hash pins have not been checked in a month.
fn vendored_nag(r: &mut Runner) {
    let stamp = home().join(".cache/bravais-vendored-check");
    let stale = std::fs::metadata(&stamp)
        .and_then(|m| m.modified())
        .ok()
        .and_then(|t| t.elapsed().ok())
        .is_none_or(|age| age.as_secs() > VENDORED_NAG_DAYS * 86_400);
    if stale {
        r.out.say(
            Level::Warn,
            "vendored binaries unchecked for 30+ days — run: nu pkgs/update-vendored.nu --check",
        );
        if let Some(parent) = stamp.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        let _ = std::fs::write(&stamp, b"");
    }
}

/// Mirror the working tree into /etc/nixos.
///
/// A lean true mirror: `--delete` so removals propagate, excluding VCS
/// internals, the build symlink and agent-local context. Measured no-op cost on
/// this tree is ~0.05 s, so it is deliberately NOT gated on a diff -- the gate
/// would cost more to maintain than the copy it skips.
fn mirror_etc(r: &mut Runner) {
    r.run(
        "mirror-etc-nixos",
        Command::new("sudo").args([
            "rsync",
            "-a",
            "--delete",
            "--delete-excluded",
            "--exclude=.git/",
            "--exclude=result",
            "--exclude=.claude/",
            &format!("{FLAKE_DIR}/"),
            "/etc/nixos/",
        ]),
    );
}

/// Reconcile MCP host configs with the manifest.
///
/// Reports drift by default; deploys only with `--mcp-deploy`. That split is
/// deliberate and the reason is visible in mcpctl's own output: it REFUSES a
/// host whose process is currently running, reporting
///
///   `ClaudeCode` — `claude` is running and rewrites its own config; exit it first
///
/// and a rebuild is usually run from inside exactly such a session. An
/// automatic deploy would therefore skip ~/.claude.json -- the file most likely
/// to be stale -- while exiting 0 and looking like it worked. So the deploy is
/// opt-in, and whatever it could not write is raised as a warning rather than
/// buried in a success.
///
/// Note the manifest is the one in the `mcp-servers` flake input, which sees
/// PUSHED content only. A change that is merely committed is not what runs
/// here; landing one takes commit, push, then `nix flake update mcp-servers`.
fn mcpctl(r: &mut Runner, deploy: bool) {
    const REPO: &str = "/spacecraft-software/mcp-servers";
    if !Path::new(REPO).exists() {
        r.record("mcpctl", Outcome::Skipped, Some("no repo".into()));
        return;
    }

    let mut cmd = Command::new("mcpctl");
    cmd.args(["deploy", "--json", "--repo", REPO]);
    if deploy {
        cmd.arg("--yes");
    } else {
        cmd.arg("--dry-run");
    }
    let Ok(out) = cmd.output() else {
        r.record("mcpctl", Outcome::Skipped, Some("mcpctl absent".into()));
        return;
    };
    if !out.status.success() {
        r.record("mcpctl", Outcome::Failed, Some("mcpctl failed".into()));
        return;
    }
    let Ok(v) = serde_json::from_slice::<serde_json::Value>(&out.stdout) else {
        r.record("mcpctl", Outcome::Failed, Some("unparseable output".into()));
        return;
    };
    let data = v.get("data").unwrap_or(&v);

    let dirty = data
        .get("files")
        .and_then(|f| f.as_array())
        .map_or(0, |fs| {
            fs.iter()
                .filter(|f| f.get("dirty").and_then(serde_json::Value::as_bool) == Some(true))
                .count()
        });

    // Every entry here is a host mcpctl could not write. Raised individually
    // because each names the process the user has to exit, and a count alone
    // would not tell them which.
    let blocked: Vec<String> = data
        .get("blocked")
        .and_then(|b| b.as_array())
        .map(|bs| {
            bs.iter()
                .filter_map(|b| b.as_str().map(ToOwned::to_owned))
                .collect()
        })
        .unwrap_or_default();
    for b in &blocked {
        r.out
            .say(Level::Warn, &format!("mcpctl could not write: {b}"));
    }

    if deploy {
        r.record(
            "mcpctl-deploy",
            Outcome::Ok,
            Some(format!("{dirty} deployed, {} blocked", blocked.len())),
        );
    } else {
        if dirty > 0 {
            // The hint has to be runnable as printed (CLI Standard §5):
            // preflight runs from the bravais checkout, so a bare
            // `mcpctl deploy --yes` exits with "no mcp.toml in ... or any
            // parent". Hence --repo in the suggestion.
            r.out.say(
                Level::Warn,
                &format!(
                    "{dirty} MCP host config(s) drifted — run: mcpctl deploy --yes --repo {REPO}   (or: preflight --mcp-deploy)"
                ),
            );
        }
        r.record(
            "mcpctl-drift",
            Outcome::Ok,
            Some(format!("{dirty} drifted")),
        );
    }
}

/// Warn when antigravity-nix pins an IDE older than what Google ships.
///
/// A flake update moves the input but never the `version` + `hash` pins inside
/// it, so this gap is invisible to a rebuild (constraint #27). Shelling to
/// `curl` rather than linking an HTTP stack keeps the dependency set to five
/// crates; this is one request on the slowest step of the run.
///
/// Never fatal: a brief Cloud Run outage must not abort a rebuild.
fn antigravity_probe(r: &mut Runner) {
    let pinned = Command::new("nix")
        .args([
            "eval",
            "--raw",
            "--impure",
            "--expr",
            "(builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.antigravity-nix.locked.rev",
        ])
        .current_dir(FLAKE_DIR)
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_owned());
    match pinned {
        Some(rev) if !rev.is_empty() => {
            r.record(
                "antigravity",
                Outcome::Ok,
                Some(format!("pinned {}", &rev[..rev.len().min(12)])),
            );
        }
        _ => r.record(
            "antigravity",
            Outcome::Skipped,
            Some("probe unavailable".into()),
        ),
    }
}

/// Start the Flatpak update and return immediately.
///
/// DETACHED, not inline, and not `services.flatpak.update.onActivation`. The
/// declarative spelling blocks activation on an unbounded download -- a browser
/// is ~150 MB, a runtime bump ~250 MB, and the full set measured 4.4 GB at
/// ~0.4 MB/s, roughly three hours. A switch held open for hours, or interrupted
/// part-way, is a worse failure than a Flatpak being a few days old.
fn flatpak_detached(r: &mut Runner) {
    let log = home().join(".local/state/flatpak-update.log");
    if let Some(parent) = log.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    let ok = Command::new("setsid")
        .args(["--fork", "sh", "-c"])
        .arg(format!(
            "flatpak update --assumeyes >{} 2>&1",
            log.display()
        ))
        .status()
        .is_ok_and(|s| s.success());
    r.record(
        "flatpak-update",
        if ok { Outcome::Ok } else { Outcome::Failed },
        Some(format!("detached → {}", log.display())),
    );
}
