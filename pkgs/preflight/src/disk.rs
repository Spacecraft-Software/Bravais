// SPDX-License-Identifier: GPL-3.0-or-later
//
// Disk accounting and reclamation.
//
// The whole reason this module exists as something other than a `df` call:
// AGENTS.md constraint #28. On this host `/` is a 16 GiB tmpfs while `/nix`,
// `/var`, `/home` and `/spacecraft-software` are bind mounts of one 203 GiB
// partition. Any free-space check aimed at `/` reports ~16 GiB free forever, no
// matter how full the real disk is -- which is exactly how a rebuild came to
// fail mid-switch on a disk that `df -h /` swore was almost empty.
//
// So every path measured here is a REAL path on the partition that actually
// fills, and adding a new check means adding a real path to `WATCHED`.

use serde::Serialize;

/// The builder's scratch directory: a loop-mounted ext4 image on a removable
/// drive, per `modules/core/nix-tmp.nix`.
///
/// Measured here because it is where the BUILD peaks, which is a different
/// question from where the SWITCH writes. The nix-daemon's `TMPDIR` and
/// `nix.settings.build-dir` both point at it unconditionally, so every build
/// this tool triggers lands here whether or not this tool knows about it --
/// and a peak of 50-55 GiB has been measured. Leaving it unmeasured meant a
/// build could die with ENOSPC while the disk report said nothing was wrong.
///
/// Nothing needs to check whether the drive is plugged in: with it absent this
/// path is a plain directory on the system partition, so `statvfs` returns the
/// same `f_fsid` as `/nix` and the dedup below drops it. Present, it is a
/// separate loop device and reports separately. Both cases fall out of the
/// existing logic.
const BUILD_SCRATCH: &str = "/mnt/nix-tmp";

/// Paths whose free space is reported, in display order.
///
/// `/nix` must stay FIRST: `primary_available` and therefore `is_low` read
/// `mounts.first()`, and the low-water threshold below is sized for `/nix`
/// alone. `/var/lib/flatpak` is measured because the Flatpak update this tool
/// detaches at the end can pull several GiB and is the other way the partition
/// fills without anyone noticing.
const WATCHED: &[&str] = &["/nix", BUILD_SCRATCH, "/var/lib/flatpak"];

/// Below this much free space on the build scratch, a large build is at risk.
///
/// Sized against the peak that justified the loop image existing at all:
/// 40 GiB once failed to fit a parallel Rust build with LTO and a single
/// codegen unit, and the image was raised to 80 GiB for a measured peak of
/// 50-55 GiB. 20 GiB is well under that peak on purpose -- this is a "you are
/// heading for trouble" line, not a guarantee, because the true requirement
/// depends entirely on what is being built.
///
/// Deliberately NOT folded into `is_low`. That predicate implies `--reclaim`,
/// and reclamation cannot help here: it delegates to vacuum, whose roots are
/// `~` and `/spacecraft-software` and whose roots also bound its deletions, so
/// this path is outside its reach entirely. The orphaned scratch trees that
/// accumulate here are owned by a tmpfiles age rule instead. Triggering a
/// remedy that provably cannot apply would be worse than reporting the fact.
const SCRATCH_LOW_WATER_BYTES: u64 = 20 * 1024 * 1024 * 1024;

/// Below this much free space on `/nix`, a rebuild is at real risk of failing
/// part-way through, so `--reclaim` is implied rather than merely suggested.
///
/// 10 GiB is not arbitrary: a full system closure here measures ~37 GiB, a
/// switch commonly writes 1-2 GiB of new closure, and a Flatpak runtime bump
/// has measured 4.4 GiB. Ten leaves room for the worst of those to land
/// concurrently. Raising it makes reclamation fire on healthy systems; lowering
/// it reintroduces the mid-switch failure this constant exists to prevent.
pub const LOW_WATER_BYTES: u64 = 10 * 1024 * 1024 * 1024;

#[derive(Debug, Serialize, Clone)]
pub struct Mount {
    pub path: String,
    pub total_bytes: u64,
    pub available_bytes: u64,
    pub used_percent: u8,
}

#[derive(Debug, Serialize, Clone, Default)]
pub struct Report {
    pub mounts: Vec<Mount>,
    /// Bytes vacuum considers reclaimable in its `safe` categories, when it
    /// could be asked. `None` means vacuum is absent or failed -- deliberately
    /// distinct from `Some(0)`, which means it ran and found nothing.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reclaimable_bytes: Option<u64>,
}

impl Report {
    /// Free bytes on the first watched path, which is `/nix`.
    pub fn primary_available(&self) -> u64 {
        self.mounts.first().map_or(0, |m| m.available_bytes)
    }

    pub fn is_low(&self) -> bool {
        self.primary_available() < LOW_WATER_BYTES
    }

    /// The build scratch, when it is a filesystem of its own.
    ///
    /// `None` means the removable drive is absent and builds are falling back
    /// to the system partition -- which is not an error, and is already
    /// covered by the `/nix` figure, since the two are then one filesystem.
    pub fn scratch(&self) -> Option<&Mount> {
        self.mounts.iter().find(|m| m.path == BUILD_SCRATCH)
    }

    /// Whether the build scratch is tight enough to be worth saying so.
    pub fn scratch_is_low(&self) -> bool {
        self.scratch()
            .is_some_and(|m| m.available_bytes < SCRATCH_LOW_WATER_BYTES)
    }
}

/// Human-readable size. Binary units, because that is what `df -h` and every
/// other disk tool on this system print, and mixing the two is how a 10 GiB
/// threshold silently becomes a 10 GB one.
pub fn human(bytes: u64) -> String {
    const UNITS: [&str; 5] = ["B", "K", "M", "G", "T"];
    #[expect(
        clippy::cast_precision_loss,
        reason = "display only; a petabyte-scale rounding error is invisible at one decimal place"
    )]
    let mut v = bytes as f64;
    let mut unit = 0;
    while v >= 1024.0 && unit < UNITS.len() - 1 {
        v /= 1024.0;
        unit += 1;
    }
    if unit == 0 {
        format!("{bytes}{}", UNITS[0])
    } else {
        format!("{v:.1}{}", UNITS[unit])
    }
}

/// Measure the watched paths. Missing paths are skipped, not fatal: a machine
/// without Flatpak is a normal machine, not a broken one.
///
/// Paths that resolve to the SAME filesystem are collapsed to the first one.
/// That is not tidiness, it is the whole point of constraint #28: on this host
/// `/nix` and `/var/lib/flatpak` are both bind mounts of one partition, and
/// listing them separately reads as two independent pools with twice the real
/// capacity -- precisely the wrong inference to invite from a disk report.
pub fn measure() -> Report {
    let mut mounts = Vec::new();
    let mut seen: Vec<u64> = Vec::new();
    for path in WATCHED {
        let Ok(st) = rustix::fs::statvfs(*path) else {
            continue;
        };
        // f_fsid identifies the filesystem; equal ids mean one pool.
        if seen.contains(&st.f_fsid) {
            continue;
        }
        seen.push(st.f_fsid);
        let block = st.f_frsize;
        let total = st.f_blocks * block;
        let avail = st.f_bavail * block;
        // Percentages follow `df`: used is measured against the space a
        // non-root user can actually reach, so the reserved blocks show up as
        // used rather than as phantom headroom.
        let usable = st.f_blocks.saturating_sub(st.f_bfree - st.f_bavail);
        let used_pct = if usable == 0 {
            0
        } else {
            let used = usable.saturating_sub(st.f_bavail);
            u8::try_from(used.saturating_mul(100) / usable).unwrap_or(100)
        };
        mounts.push(Mount {
            path: (*path).to_owned(),
            total_bytes: total,
            available_bytes: avail,
            used_percent: used_pct,
        });
    }
    Report {
        mounts,
        reclaimable_bytes: None,
    }
}

/// Ask vacuum what it could reclaim without touching anything.
///
/// Only the categories vacuum marks `risk: safe` are counted. `large-files` is
/// deliberately excluded here and everywhere else in this tool: it is a list of
/// big things, not a list of junk, and on this machine it is mostly the user's
/// own models, downloads and git packs.
pub fn reclaimable() -> Option<u64> {
    let out = std::process::Command::new("vacuum")
        .args(["list", "--json"])
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    let v: serde_json::Value = serde_json::from_slice(&out.stdout).ok()?;
    let cats = v.get("data")?.get("categories")?.as_array()?;
    let mut total = 0u64;
    for cat in cats {
        let Some(items) = cat.get("candidates").and_then(|c| c.as_array()) else {
            continue;
        };
        for item in items {
            let safe = item.get("risk").and_then(|r| r.as_str()) == Some("safe");
            let cat_name = item.get("category").and_then(|c| c.as_str()).unwrap_or("");
            if safe && SAFE_CATEGORIES.contains(&cat_name) {
                total += item
                    .get("bytes")
                    .and_then(serde_json::Value::as_u64)
                    .unwrap_or(0);
            }
        }
    }
    Some(total)
}

/// Categories this tool will ever delete from.
pub const SAFE_CATEGORIES: &[&str] = &["caches", "build-artifacts", "package-gc"];

#[derive(Debug, Serialize)]
pub struct Reclaimed {
    pub freed_bytes: u64,
    pub categories: Vec<String>,
}

/// Run the reclamation.
///
/// `--purge` rather than the default move-to-trash, and that is load-bearing:
/// the trash lives on the same partition, so trashing frees nothing at all on
/// the full disk this is meant to rescue. Measured on this host -- a trash-mode
/// run reported success and moved free space by zero bytes.
pub fn reclaim() -> anyhow::Result<Reclaimed> {
    let before = measure().primary_available();
    let mut cmd = std::process::Command::new("vacuum");
    cmd.arg("clean");
    for c in SAFE_CATEGORIES {
        cmd.args(["--category", c]);
    }
    cmd.args(["--apply", "--yes", "--purge"]);
    let status = cmd.status()?;
    if !status.success() {
        anyhow::bail!("vacuum clean exited with {status}");
    }
    let after = measure().primary_available();
    Ok(Reclaimed {
        freed_bytes: after.saturating_sub(before),
        categories: SAFE_CATEGORIES.iter().map(|s| (*s).to_owned()).collect(),
    })
}

/// Render a report as the human-mode block.
pub fn render(report: &Report, heading: &str) -> String {
    use std::fmt::Write as _;

    let mut s = format!("── {heading} ──\n");
    for m in &report.mounts {
        // Writing into the buffer cannot fail; a String's fmt::Write is
        // infallible, so discarding the Result is correct rather than lazy.
        let _ = writeln!(
            s,
            "  {:<18} {:>8} free of {:>8}  ({}% used)",
            m.path,
            human(m.available_bytes),
            human(m.total_bytes),
            m.used_percent
        );
    }
    if let Some(r) = report.reclaimable_bytes {
        if r > 0 {
            let _ = writeln!(
                s,
                "  {:<18} {:>8} reclaimable (preflight disk reclaim)",
                "safe caches",
                human(r)
            );
        }
    }
    // Carries its own severity tag rather than relying on color, per Standard
    // §18.2.1, and says what to do -- reclamation is not the remedy here, as
    // SCRATCH_LOW_WATER_BYTES explains.
    if report.scratch_is_low() {
        let _ = writeln!(
            s,
            "  [WARN] build scratch is low; a large build may fail with ENOSPC.\n\
             {:9}`preflight disk reclaim` cannot help -- {BUILD_SCRATCH} is outside\n\
             {:9}vacuum's roots. Free the drive or let the tmpfiles age rule run.",
            "", ""
        );
    }
    s
}

#[cfg(test)]
mod tests {
    use super::*;

    fn mount(path: &str, avail: u64) -> Mount {
        Mount {
            path: path.to_owned(),
            total_bytes: 100 * 1024 * 1024 * 1024,
            available_bytes: avail,
            used_percent: 0,
        }
    }

    fn report(mounts: Vec<Mount>) -> Report {
        Report {
            mounts,
            reclaimable_bytes: None,
        }
    }

    const GIB: u64 = 1024 * 1024 * 1024;

    #[test]
    fn primary_is_the_first_mount_not_the_smallest() {
        // `/nix` leads WATCHED and must keep leading the report: the whole
        // low-water contract is expressed against it.
        let r = report(vec![mount("/nix", 50 * GIB), mount(BUILD_SCRATCH, GIB)]);
        assert_eq!(r.primary_available(), 50 * GIB);
        assert!(!r.is_low());
    }

    #[test]
    fn a_full_build_scratch_does_not_trigger_reclamation() {
        // The load-bearing separation: `is_low` implies `--reclaim`, and
        // reclamation provably cannot free this path (see
        // SCRATCH_LOW_WATER_BYTES). Folding the two together would fire a
        // remedy that cannot apply.
        let r = report(vec![mount("/nix", 50 * GIB), mount(BUILD_SCRATCH, 0)]);
        assert!(!r.is_low(), "scratch must not drive the reclaim predicate");
        assert!(r.scratch_is_low(), "but it must still be reported");
    }

    #[test]
    fn an_absent_drive_reports_no_scratch() {
        // With the drive unplugged the dedup in `measure` drops the path, so
        // no scratch mount exists and nothing warns -- builds are then falling
        // back onto the partition `/nix` already accounts for.
        let r = report(vec![mount("/nix", GIB)]);
        assert!(r.scratch().is_none());
        assert!(!r.scratch_is_low());
        assert!(r.is_low(), "the /nix threshold still applies");
    }

    #[test]
    fn a_roomy_scratch_is_quiet() {
        let r = report(vec![
            mount("/nix", 50 * GIB),
            mount(BUILD_SCRATCH, 74 * GIB),
        ]);
        assert!(!r.scratch_is_low());
    }
}
