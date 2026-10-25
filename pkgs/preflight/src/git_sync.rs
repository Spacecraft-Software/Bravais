// SPDX-License-Identifier: GPL-3.0-or-later
//
// Bring the flake checkout up to date with `origin` before anything is built.
//
// preflight builds whatever is checked out in FLAKE_DIR, and until this step
// it never looked at git at all. Two failures on 2026-10-19 came from that:
// Margo was "missing" after a rebuild because the checkout sat on a PR branch
// that had been merged and deleted upstream days earlier, and a PR test would
// have silently built `main` because nobody had switched to the PR branch.
// Both are the same bug -- the build tree is not the tree the user thinks it
// is -- so the run now starts by making it so, or by refusing loudly.
//
// The policy, in order:
//
//   1. Uncommitted changes to tracked files are carried along, the way
//      `git switch` and `git merge --ff-only` carry them, and named in a
//      warning. Refusing on them was the first design and it refused the
//      very next run on the ThinkPad: preflight's own updaters left
//      `flake.lock` and the vendored pins modified, so a dirty tree was the
//      normal state between a rebuild and the commit that recorded its bumps.
//      Since 2026-10-24 the run commits them itself (`deps_commit`), but a
//      run on a PR branch, under `--no-commit`, or whose switch failed still
//      leaves them behind.
//      A change the incoming commits also touch is resolved, never refused
//      (`Clash`): identical to the incoming version, it is dropped; else
//      stashed, the move made and the stash reapplied, and if that clashes
//      the incoming version stands and the edits stay in `git stash`.
//      The one exception is `flake.lock`: it is tool-generated (a flake
//      update, or a run of this tool, wrote that bump), so when the incoming
//      commits change it too the local bump is dropped and origin's lock
//      stands -- under `--no-update` as well, with a note saying so.
//   2. `git fetch --prune origin`. Pruning is what makes a deleted upstream
//      branch visible as gone rather than as a stale remote-tracking ref.
//   3. Pick the branch: `--branch <name>` if given; else the current branch
//      while its upstream still exists; else -- detached HEAD, or an upstream
//      that was merged and deleted -- origin's default branch. A local branch
//      that never had an upstream is refused: it is somebody's deliberate
//      local work, and silently leaving it for `main` would be the same
//      surprise in the other direction. One already merged into the default
//      branch has no work of its own, so it goes to the default branch too.
//   4. Fast-forward only. A branch with commits origin does not have is
//      refused, never merged or reset: rewriting someone's work to make a
//      rebuild go is not this tool's call.
//
// Every git invocation is an argv array; the one user-supplied string, the
// branch name, is validated at parse time (`parse_branch`) and passed after
// the option list so it can never be read as a flag.

use std::process::Command;

use crate::output::Exit;

/// The lock file, which a following flake update regenerates; see the
/// policy above.
pub const LOCK: &str = "flake.lock";

/// Why the run will not go ahead. Becomes the CLI's structured error.
#[derive(Debug)]
pub struct Refusal {
    pub code: &'static str,
    pub exit: Exit,
    pub message: String,
    /// A command the caller can run verbatim (tips-thinking).
    pub hint: String,
}

impl Refusal {
    fn new(code: &'static str, message: impl Into<String>, hint: impl Into<String>) -> Self {
        Self {
            code,
            exit: Exit::Failure,
            message: message.into(),
            hint: hint.into(),
        }
    }

    /// A refusal because the tree disagrees with the run (CLI Standard §4,
    /// exit 5): resolve the conflict, do not retry as is.
    fn conflict(code: &'static str, message: impl Into<String>, hint: impl Into<String>) -> Self {
        Self {
            code,
            exit: Exit::Conflict,
            message: message.into(),
            hint: hint.into(),
        }
    }
}

/// What the caller asked for.
#[derive(Debug, Clone, Copy)]
pub struct Request<'a> {
    pub dir: &'a str,
    /// `--branch`: switch to this branch instead of following the current one.
    pub branch: Option<&'a str>,
    /// `--dry`: fetch and report, but do not move the checkout.
    pub dry: bool,
}

/// State of the current branch's upstream after a pruning fetch.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Upstream {
    /// Configured and the remote-tracking ref exists.
    Live,
    /// Configured, but the remote branch is gone (merged and deleted).
    Gone,
    /// Never configured: a local-only branch.
    Unset,
    /// Never configured, but every commit is already in origin's default
    /// branch (a finished local branch, e.g. a deps branch that was merged).
    Merged,
}

/// Why a branch was chosen, for the report.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Why {
    Requested,
    Current,
    Detached,
    UpstreamGone,
    AlreadyMerged,
}

/// Decide which branch to build. Pure, so the policy is testable without git.
pub fn choose(
    requested: Option<&str>,
    current: Option<&str>,
    upstream: Upstream,
    default: &str,
    dir: &str,
) -> Result<(String, Why), Refusal> {
    if let Some(b) = requested {
        return Ok((b.to_owned(), Why::Requested));
    }
    let Some(cur) = current else {
        return Ok((default.to_owned(), Why::Detached));
    };
    match upstream {
        Upstream::Live => Ok((cur.to_owned(), Why::Current)),
        Upstream::Gone => Ok((default.to_owned(), Why::UpstreamGone)),
        Upstream::Merged => Ok((default.to_owned(), Why::AlreadyMerged)),
        Upstream::Unset => Err(Refusal::conflict(
            "NO_UPSTREAM",
            format!(
                "branch '{cur}' has no upstream on origin, so there is nothing to update it from"
            ),
            format!(
                "git -C {dir} switch {default}   # or build '{cur}' as it is: preflight --no-sync"
            ),
        )),
    }
}

/// Tracked paths with uncommitted changes, `flake.lock` excepted, from
/// `git status --porcelain=v1`. A rename reports its new path.
pub fn carried_changes(porcelain: &str) -> Vec<String> {
    porcelain
        .lines()
        .filter_map(|l| l.get(3..))
        .map(|p| p.rsplit(" -> ").next().unwrap_or(p).to_owned())
        .filter(|p| p != LOCK)
        .collect()
}

/// Validate `--branch` at parse time (Agentic CLI §7). git's own
/// `check-ref-format` still has the last word when the name is used; this
/// only rejects what must never reach an argv at all.
pub fn parse_branch(s: &str) -> Result<String, String> {
    if s.is_empty() {
        return Err("branch name is empty".into());
    }
    if s.starts_with('-') {
        return Err("branch name may not start with '-'".into());
    }
    if s.chars().any(|c| c.is_control() || c.is_whitespace()) {
        return Err("branch name may not contain whitespace or control characters".into());
    }
    if s.contains("..") {
        return Err("branch name may not contain '..'".into());
    }
    // Accept the remote-qualified spelling people copy from `git branch -r`.
    Ok(s.strip_prefix("origin/").unwrap_or(s).to_owned())
}

/// Run git and capture its trimmed stdout; `None` if it fails to run or exits
/// non-zero.
pub(crate) fn git(dir: &str, args: &[&str]) -> Option<String> {
    git_raw(dir, args).map(|s| s.trim().to_owned())
}

/// [`git`] without the trim. Porcelain status needs this: its first column is
/// a space for an unstaged change, and trimming it shifts the path by one.
pub(crate) fn git_raw(dir: &str, args: &[&str]) -> Option<String> {
    Command::new("git")
        .arg("-C")
        .arg(dir)
        .args(args)
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
}

/// Run git with its output shown. Its stdout goes to OUR stderr, as with
/// every other child here, so `--json` keeps exactly one payload on stdout.
pub(crate) fn git_shown(dir: &str, args: &[&str]) -> bool {
    Command::new("git")
        .arg("-C")
        .arg(dir)
        .args(args)
        .stdout(std::io::stderr())
        .status()
        .is_ok_and(|s| s.success())
}

/// Whether `rev` names an existing object (`git rev-parse --verify`).
pub(crate) fn exists(dir: &str, rev: &str) -> bool {
    git(dir, &["rev-parse", "--verify", "--quiet", rev]).is_some()
}

/// The outcome of a sync the caller reports.
#[derive(Debug)]
pub struct Synced {
    /// The step's report line.
    pub line: String,
    /// Uncommitted paths (`flake.lock` aside) the checkout carried along, so
    /// the build is origin's code PLUS these. The caller warns about them.
    pub carried: Vec<String>,
}

/// Sync the checkout.
pub fn sync(req: Request) -> Result<Synced, Refusal> {
    let (lock_dirty, carried) = check_tree(req.dir)?;
    let plan = plan(req)?;

    // `nix flake update` leaves flake.lock modified after every full run. If
    // the incoming commits also change it, git would refuse the switch or
    // fast-forward. The bump is tool-generated, so origin's lock wins; the
    // report line says it was dropped. Never a reason to make the user run
    // `git restore`.
    let lock_conflicts = lock_dirty
        && git(
            req.dir,
            &["diff", "--quiet", "HEAD", &plan.target, "--", LOCK],
        )
        .is_none();

    if req.dry {
        return Ok(Synced {
            line: plan.describe_dry(req.dir),
            carried,
        });
    }
    if lock_conflicts {
        drop_lock_bump(req)?;
    }
    let clash = Clash::resolve(req.dir, &plan, &carried);
    let line = match apply(req.dir, &plan, &carried) {
        Ok(l) => l,
        Err(e) => {
            // Put the edits back; the refusal then describes a tree the way
            // the user left it.
            clash.restore(req.dir);
            return Err(e);
        }
    };
    let mut line = line;
    if lock_conflicts {
        line = format!("{line}; dropped the uncommitted {LOCK} bump (origin's lock replaces it)");
    }
    for note in clash.reapply(req.dir) {
        line = format!("{line}; {note}");
    }
    Ok(Synced { line, carried })
}

/// The tree must be a checkout. Returns whether `flake.lock` is modified, and
/// every other uncommitted tracked path.
fn check_tree(dir: &str) -> Result<(bool, Vec<String>), Refusal> {
    if git(dir, &["rev-parse", "--is-inside-work-tree"]).as_deref() != Some("true") {
        return Err(Refusal::new(
            "NOT_A_CHECKOUT",
            format!("{dir} is not a git checkout (or git is not on PATH)"),
            "preflight --no-sync   # build the tree as it is",
        ));
    }
    let porcelain =
        git_raw(dir, &["status", "--porcelain=v1", "--untracked-files=no"]).unwrap_or_default();
    let lock_dirty = porcelain.lines().any(|l| l.get(3..) == Some(LOCK));
    Ok((lock_dirty, carried_changes(&porcelain)))
}

/// Moving was blocked by uncommitted changes the incoming commits also touch.
fn dirty_refusal(dir: &str, carried: &[String]) -> Refusal {
    Refusal::conflict(
        "DIRTY_TREE",
        format!(
            "uncommitted changes conflict with the incoming commits: {}",
            carried.join(", ")
        ),
        format!(
            "git -C {dir} stash   # then re-run; or build the tree as it is: preflight --no-sync"
        ),
    )
}

/// Uncommitted edits to files the incoming commits also change. Moving would
/// overwrite them, so git refuses; preflight resolves it instead, because a
/// plain `preflight` has to work whatever the last run left behind (the case
/// that bit: a vendored pin bump left in the tree that arrived on `main` too).
///
/// The edits are stashed, the move made, and the stash reapplied. An edit
/// identical to the incoming file reapplies as a no-op; one that clashes
/// leaves the incoming version in place and stays in the stash, named in the
/// report. A refused move pops the stash back, so nothing is ever lost and
/// nothing aborts.
#[derive(Debug, Default)]
struct Clash {
    stashed: Vec<String>,
}

impl Clash {
    fn resolve(dir: &str, plan: &Plan, carried: &[String]) -> Self {
        let mut incoming =
            git(dir, &["diff", "--name-only", "HEAD", &plan.target]).unwrap_or_default();
        // Switching onto an existing local branch is judged against it too.
        if let Some(local) = git(
            dir,
            &[
                "diff",
                "--name-only",
                "HEAD",
                &format!("refs/heads/{}", plan.branch),
            ],
        ) {
            incoming = format!("{incoming}\n{local}");
        }
        let mut c = Self {
            stashed: carried
                .iter()
                .filter(|p| incoming.lines().any(|l| l == p.as_str()))
                .cloned()
                .collect(),
        };
        if !c.stashed.is_empty() {
            let mut args = vec![
                "stash",
                "push",
                "--quiet",
                "-m",
                "preflight: edits the update clashed with",
                "--",
            ];
            args.extend(c.stashed.iter().map(String::as_str));
            if !git_shown(dir, &args) {
                c.stashed.clear();
            }
        }
        c
    }

    /// A refused move: bring the stashed edits back.
    fn restore(&self, dir: &str) {
        if !self.stashed.is_empty() {
            git_shown(dir, &["stash", "pop", "--quiet"]);
        }
    }

    /// After the move: reapply what was stashed.
    fn reapply(&self, dir: &str) -> Vec<String> {
        if self.stashed.is_empty() {
            return Vec::new();
        }
        let files = self.stashed.join(", ");
        if git_shown(dir, &["stash", "pop", "--quiet"]) {
            return vec![format!("reapplied your edits to {files}")];
        }
        let mut args = vec!["restore", "--source=HEAD", "--staged", "--worktree", "--"];
        args.extend(self.stashed.iter().map(String::as_str));
        git_shown(dir, &args);
        vec![format!(
            "your edits to {files} clash with the incoming ones and stay in `git stash` (git -C {dir} stash show -p)"
        )]
    }
}

/// Where the checkout is going.
#[derive(Debug)]
struct Plan {
    branch: String,
    /// The ref to fast-forward to: the branch's own upstream when staying
    /// put, `origin/<branch>` otherwise.
    target: String,
    switching: bool,
    /// Why the branch was chosen, ready to append to the report line.
    note: String,
}

impl Plan {
    fn describe_dry(&self, dir: &str) -> String {
        let behind = git(
            dir,
            &["rev-list", "--count", &format!("HEAD..{}", self.target)],
        )
        .unwrap_or_else(|| "?".into());
        let (branch, target, note) = (&self.branch, &self.target, &self.note);
        let action = if self.switching {
            format!("switch to {branch}{note} and fast-forward to {target}")
        } else {
            format!("fast-forward {branch} to {target}")
        };
        format!("dry run; would {action} ({behind} commit(s) behind); building the tree as it is")
    }
}

/// origin's default branch (`origin/HEAD`), or `main` when that ref is unset.
pub(crate) fn default_branch(dir: &str) -> String {
    git(
        dir,
        &[
            "symbolic-ref",
            "--quiet",
            "--short",
            "refs/remotes/origin/HEAD",
        ],
    )
    .and_then(|r| r.strip_prefix("origin/").map(ToOwned::to_owned))
    .unwrap_or_else(|| "main".to_owned())
}

/// Fetch, then decide the branch and the ref to move it to.
fn plan(req: Request) -> Result<Plan, Refusal> {
    let dir = req.dir;
    if !git_shown(dir, &["fetch", "--prune", "origin"]) {
        return Err(Refusal::new(
            "FETCH_FAILED",
            "git fetch from origin failed, so the latest code is unknown",
            "preflight --no-sync --no-update   # offline: build the tree as it is",
        ));
    }

    let current = git(dir, &["symbolic-ref", "--quiet", "--short", "HEAD"]);
    let default = default_branch(dir);
    let upstream = current.as_deref().map_or(Upstream::Unset, |c| {
        if git(dir, &["config", "--get", &format!("branch.{c}.merge")]).is_none() {
            // Nothing of its own to lose: its work is already on the default
            // branch, so leaving it is not the surprise NO_UPSTREAM guards.
            if git(
                dir,
                &[
                    "merge-base",
                    "--is-ancestor",
                    "HEAD",
                    &format!("origin/{default}"),
                ],
            )
            .is_some()
            {
                Upstream::Merged
            } else {
                Upstream::Unset
            }
        } else if exists(dir, &format!("{c}@{{upstream}}")) {
            Upstream::Live
        } else {
            Upstream::Gone
        }
    });

    let (branch, why) = choose(req.branch, current.as_deref(), upstream, &default, dir)?;
    let switching = current.as_deref() != Some(branch.as_str());
    let target = if switching {
        format!("origin/{branch}")
    } else {
        git(
            dir,
            &[
                "rev-parse",
                "--abbrev-ref",
                &format!("{branch}@{{upstream}}"),
            ],
        )
        .unwrap_or_else(|| format!("origin/{branch}"))
    };
    if !exists(dir, &format!("{target}^{{commit}}")) {
        return Err(Refusal {
            exit: Exit::NotFound,
            ..Refusal::new(
                "NO_SUCH_BRANCH",
                format!("origin has no branch '{branch}'"),
                format!("git -C {dir} branch --remotes   # the branches origin has"),
            )
        });
    }

    let note = match why {
        Why::UpstreamGone => format!(
            " ('{}' was deleted on origin)",
            current.as_deref().unwrap_or_default()
        ),
        Why::Detached => " (HEAD was detached)".to_owned(),
        Why::AlreadyMerged => format!(
            " ('{}' is already in {default})",
            current.as_deref().unwrap_or_default()
        ),
        Why::Requested | Why::Current => String::new(),
    };
    Ok(Plan {
        branch,
        target,
        switching,
        note,
    })
}

/// Discard the stale `flake.lock` bump that would block the move; origin's
/// lock replaces it.
fn drop_lock_bump(req: Request) -> Result<(), Refusal> {
    let dir = req.dir;
    if git_shown(dir, &["restore", "--staged", "--worktree", "--", LOCK]) {
        Ok(())
    } else {
        Err(Refusal::new(
            "LOCK_CONFLICT",
            format!("could not discard the uncommitted {LOCK} bump"),
            format!("git -C {dir} status"),
        ))
    }
}

/// Switch if needed, then fast-forward. Returns the report line.
fn apply(dir: &str, plan: &Plan, carried: &[String]) -> Result<String, Refusal> {
    let (branch, target) = (&plan.branch, &plan.target);
    if plan.switching {
        let ok = if exists(dir, &format!("refs/heads/{branch}")) {
            git_shown(dir, &["switch", branch])
        } else {
            git_shown(dir, &["switch", "--create", branch, "--track", target])
        };
        if !ok && !carried.is_empty() {
            return Err(dirty_refusal(dir, carried));
        }
        if !ok {
            return Err(Refusal::new(
                "SWITCH_FAILED",
                format!("could not switch to '{branch}'"),
                format!("git -C {dir} status"),
            ));
        }
    }

    let before = git(dir, &["rev-parse", "HEAD"]).unwrap_or_default();
    if !git_shown(dir, &["merge", "--ff-only", target]) {
        // A fast-forward that is possible in history can only have been
        // stopped by the working tree.
        let ancestor = git(dir, &["merge-base", "--is-ancestor", "HEAD", target]).is_some();
        if ancestor && !carried.is_empty() {
            return Err(dirty_refusal(dir, carried));
        }
        return Err(Refusal::conflict(
            "NOT_FAST_FORWARD",
            format!(
                "'{branch}' has commits that {target} does not, so it cannot be fast-forwarded"
            ),
            format!("git -C {dir} log --oneline {target}..{branch}   # the local-only commits"),
        ));
    }
    let new = git(dir, &["rev-list", "--count", &format!("{before}..HEAD")])
        .unwrap_or_else(|| "?".into());
    let head = git(dir, &["rev-parse", "--short", "HEAD"]).unwrap_or_default();
    Ok(format!(
        "{branch} at {head}{}; {new} new commit(s)",
        plan.note
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    const D: &str = "/flake";

    #[test]
    fn a_live_branch_is_kept() {
        let got = choose(None, Some("feat"), Upstream::Live, "main", D).map(|c| c.0);
        assert_eq!(got.ok().as_deref(), Some("feat"));
    }

    #[test]
    fn a_deleted_upstream_falls_back_to_the_default_branch() {
        let got = choose(None, Some("feat"), Upstream::Gone, "main", D);
        assert!(got.is_ok_and(|(b, w)| b == "main" && w == Why::UpstreamGone));
    }

    #[test]
    fn a_detached_head_goes_to_the_default_branch() {
        let got = choose(None, None, Upstream::Unset, "main", D);
        assert!(got.is_ok_and(|(b, w)| b == "main" && w == Why::Detached));
    }

    #[test]
    fn a_local_only_branch_is_refused() {
        let got = choose(None, Some("wip"), Upstream::Unset, "main", D);
        assert!(got.is_err_and(|r| r.code == "NO_UPSTREAM"));
    }

    #[test]
    fn a_requested_branch_wins() {
        let got = choose(Some("pr-1"), Some("feat"), Upstream::Live, "main", D).map(|c| c.0);
        assert_eq!(got.ok().as_deref(), Some("pr-1"));
    }

    #[test]
    fn a_dirty_lock_is_not_reported_as_carried() {
        assert!(carried_changes(" M flake.lock\n").is_empty());
    }

    #[test]
    fn other_changes_are_carried_and_renames_report_the_new_path() {
        let got = carried_changes(" M flake.lock\nM  flake.nix\nR  a.nix -> b.nix\n");
        assert_eq!(got, ["flake.nix", "b.nix"]);
    }

    #[test]
    fn branch_names_that_could_be_flags_or_traversal_are_rejected() {
        for bad in ["", "-x", "--force", "a b", "a\x07", "a..b"] {
            assert!(parse_branch(bad).is_err(), "{bad:?} must be rejected");
        }
    }

    #[test]
    fn the_origin_prefix_is_accepted_and_dropped() {
        assert_eq!(
            parse_branch("origin/claude/x").ok().as_deref(),
            Some("claude/x")
        );
    }

    /// End-to-end scenarios against throwaway repositories. Skipped when git
    /// cannot run (the Nix build sandbox has none), so it never fails a build
    /// for want of a tool; `cargo test` on a workstation exercises it.
    mod against_git {
        use super::super::*;
        use std::path::{Path, PathBuf};

        struct Lab {
            root: PathBuf,
        }

        impl Lab {
            fn new(name: &str) -> Option<Self> {
                Command::new("git").arg("--version").output().ok()?;
                let root = std::env::temp_dir()
                    .join(format!("preflight-git-sync-{}-{name}", std::process::id()));
                let _ = std::fs::remove_dir_all(&root);
                std::fs::create_dir_all(&root).ok()?;
                let lab = Self { root };
                lab.sh(&["init", "--quiet", "--bare", "-b", "main", "origin.git"]);
                lab.sh(&["clone", "--quiet", "origin.git", "seed"]);
                lab.configure("seed");
                lab.commit("seed", "flake.lock", "lock 1");
                lab.commit("seed", "flake.nix", "nix 1");
                lab.git("seed", &["push", "--quiet", "origin", "main"]);
                lab.sh(&["clone", "--quiet", "origin.git", "work"]);
                lab.configure("work");
                Some(lab)
            }

            fn path(&self, repo: &str) -> PathBuf {
                self.root.join(repo)
            }

            fn dir(&self) -> String {
                self.path("work").display().to_string()
            }

            fn sh(&self, args: &[&str]) {
                let ok = Command::new("git")
                    .args(args)
                    .current_dir(&self.root)
                    .output()
                    .is_ok_and(|o| o.status.success());
                assert!(ok, "git {args:?}");
            }

            fn git(&self, repo: &str, args: &[&str]) -> String {
                let out = Command::new("git")
                    .arg("-C")
                    .arg(self.path(repo))
                    .args(args)
                    .output();
                let out = out.ok().filter(|o| o.status.success());
                assert!(out.is_some(), "git -C {repo} {args:?}");
                out.map(|o| String::from_utf8_lossy(&o.stdout).trim().to_owned())
                    .unwrap_or_default()
            }

            fn configure(&self, repo: &str) {
                for (k, v) in [
                    ("user.name", "t"),
                    ("user.email", "t@example.org"),
                    ("commit.gpgsign", "false"),
                ] {
                    self.git(repo, &["config", k, v]);
                }
            }

            fn write(&self, repo: &str, file: &str, body: &str) {
                let ok = std::fs::write(Path::new(&self.path(repo)).join(file), body).is_ok();
                assert!(ok, "write {file}");
            }

            fn commit(&self, repo: &str, file: &str, body: &str) {
                self.write(repo, file, body);
                self.git(repo, &["add", file]);
                self.git(repo, &["commit", "--quiet", "-m", body]);
            }

            fn request(&self) -> Request<'static> {
                Request {
                    dir: Box::leak(self.dir().into_boxed_str()),
                    branch: None,
                    dry: false,
                }
            }

            fn head(&self) -> String {
                self.git("work", &["symbolic-ref", "--short", "HEAD"])
            }
        }

        impl Drop for Lab {
            fn drop(&mut self) {
                let _ = std::fs::remove_dir_all(&self.root);
            }
        }

        #[test]
        fn fast_forwards_the_current_branch() {
            let Some(lab) = Lab::new("ff") else { return };
            lab.commit("seed", "flake.nix", "nix 2");
            lab.git("seed", &["push", "--quiet"]);
            let got = sync(lab.request());
            assert!(
                got.as_ref().is_ok_and(|l| l.line.contains("1 new commit")),
                "{got:?}"
            );
            assert_eq!(
                std::fs::read_to_string(lab.path("work").join("flake.nix"))
                    .ok()
                    .as_deref(),
                Some("nix 2")
            );
        }

        #[test]
        fn a_merged_and_deleted_branch_returns_to_main() {
            let Some(lab) = Lab::new("gone") else { return };
            lab.git("seed", &["switch", "--quiet", "-c", "feat"]);
            lab.commit("seed", "flake.nix", "feat");
            lab.git("seed", &["push", "--quiet", "-u", "origin", "feat"]);
            lab.git("work", &["fetch", "--quiet"]);
            lab.git("work", &["switch", "--quiet", "feat"]);
            lab.git("seed", &["push", "--quiet", "origin", "--delete", "feat"]);
            let got = sync(lab.request());
            assert!(
                got.as_ref()
                    .is_ok_and(|l| l.line.contains("deleted on origin")),
                "{got:?}"
            );
            assert_eq!(lab.head(), "main");
        }

        #[test]
        fn a_requested_branch_is_created_from_origin() {
            let Some(lab) = Lab::new("req") else { return };
            lab.git("seed", &["switch", "--quiet", "-c", "pr"]);
            lab.commit("seed", "flake.nix", "pr");
            lab.git("seed", &["push", "--quiet", "origin", "pr"]);
            let got = sync(Request {
                branch: Some("pr"),
                ..lab.request()
            });
            assert!(got.is_ok(), "{got:?}");
            assert_eq!(lab.head(), "pr");
            assert_eq!(
                lab.git("work", &["rev-parse", "--abbrev-ref", "pr@{upstream}"]),
                "origin/pr"
            );
        }

        #[test]
        fn an_unknown_requested_branch_is_not_found() {
            let Some(lab) = Lab::new("nf") else { return };
            let got = sync(Request {
                branch: Some("nope"),
                ..lab.request()
            });
            assert!(got.is_err_and(|r| r.code == "NO_SUCH_BRANCH" && r.exit == Exit::NotFound));
            assert_eq!(lab.head(), "main");
        }

        #[test]
        fn carried_changes_are_reported_and_kept() {
            let Some(lab) = Lab::new("kept") else { return };
            lab.commit("seed", "other.nix", "other");
            lab.git("seed", &["push", "--quiet"]);
            lab.write("work", "flake.nix", "local edit");
            let got = sync(lab.request());
            assert!(
                got.as_ref().is_ok_and(|s| s.carried == ["flake.nix"]),
                "{got:?}"
            );
            assert_eq!(
                std::fs::read_to_string(lab.path("work").join("flake.nix"))
                    .ok()
                    .as_deref(),
                Some("local edit")
            );
        }

        #[test]
        fn carried_changes_also_work_when_switching_branch() {
            let Some(lab) = Lab::new("carrysw") else {
                return;
            };
            lab.git("seed", &["switch", "--quiet", "-c", "pr"]);
            lab.commit("seed", "other.nix", "pr");
            lab.git("seed", &["push", "--quiet", "origin", "pr"]);
            lab.write("work", "flake.nix", "local edit");
            let got = sync(Request {
                branch: Some("pr"),
                ..lab.request()
            });
            assert!(
                got.as_ref().is_ok_and(|s| s.carried == ["flake.nix"]),
                "{got:?}"
            );
            assert_eq!(lab.head(), "pr");
        }

        #[test]
        fn an_edit_identical_to_the_incoming_one_leaves_a_clean_tree() {
            let Some(lab) = Lab::new("same") else { return };
            lab.commit("seed", "flake.nix", "nix 2");
            lab.git("seed", &["push", "--quiet"]);
            lab.write("work", "flake.nix", "nix 2");
            let got = sync(lab.request());
            assert!(got.is_ok(), "{got:?}");
            assert_eq!(lab.git("work", &["status", "--porcelain"]), "");
            assert_eq!(lab.git("work", &["stash", "list"]), "");
        }

        #[test]
        fn a_refused_move_gives_the_edits_back() {
            let Some(lab) = Lab::new("refused") else {
                return;
            };
            lab.commit("seed", "flake.nix", "nix 2");
            lab.git("seed", &["push", "--quiet"]);
            lab.commit("work", "other.nix", "local");
            lab.write("work", "flake.nix", "nix 2");
            let got = sync(lab.request());
            assert!(got.is_err_and(|r| r.code == "NOT_FAST_FORWARD"));
            assert_eq!(
                std::fs::read_to_string(lab.path("work").join("flake.nix"))
                    .ok()
                    .as_deref(),
                Some("nix 2")
            );
        }

        #[test]
        fn a_clashing_edit_is_stashed_and_the_run_goes_on() {
            let Some(lab) = Lab::new("clash") else { return };
            lab.commit("seed", "flake.nix", "nix 2");
            lab.git("seed", &["push", "--quiet"]);
            lab.write("work", "flake.nix", "local edit");
            let got = sync(lab.request());
            assert!(
                got.as_ref()
                    .is_ok_and(|l| l.line.contains("stay in `git stash`")),
                "{got:?}"
            );
            assert_eq!(
                std::fs::read_to_string(lab.path("work").join("flake.nix"))
                    .ok()
                    .as_deref(),
                Some("nix 2")
            );
            assert!(!lab.git("work", &["stash", "list"]).is_empty());
        }

        #[test]
        fn a_disjoint_edit_is_reapplied_after_the_move() {
            let Some(lab) = Lab::new("disjoint") else {
                return;
            };
            lab.commit("seed", "flake.nix", "a\nb\nc\nd\ne\nf\ng\nh\n");
            lab.git("seed", &["push", "--quiet"]);
            lab.git("work", &["pull", "--quiet"]);
            lab.commit("seed", "flake.nix", "A\nb\nc\nd\ne\nf\ng\nh\n");
            lab.git("seed", &["push", "--quiet"]);
            lab.write("work", "flake.nix", "a\nb\nc\nd\ne\nf\ng\nH\n");
            let got = sync(lab.request());
            assert!(
                got.as_ref()
                    .is_ok_and(|l| l.line.contains("reapplied your edits")),
                "{got:?}"
            );
            assert_eq!(
                std::fs::read_to_string(lab.path("work").join("flake.nix"))
                    .ok()
                    .as_deref(),
                Some("A\nb\nc\nd\ne\nf\ng\nH\n")
            );
        }

        #[test]
        fn a_clashing_edit_does_not_block_a_branch_switch_either() {
            let Some(lab) = Lab::new("clashsw") else {
                return;
            };
            lab.git("seed", &["switch", "--quiet", "-c", "pr"]);
            lab.commit("seed", "flake.nix", "pr");
            lab.git("seed", &["push", "--quiet", "origin", "pr"]);
            lab.write("work", "flake.nix", "local edit");
            let got = sync(Request {
                branch: Some("pr"),
                ..lab.request()
            });
            assert!(got.is_ok(), "{got:?}");
            assert_eq!(lab.head(), "pr");
        }

        #[test]
        fn a_finished_local_branch_returns_to_main() {
            let Some(lab) = Lab::new("merged") else {
                return;
            };
            lab.git("work", &["switch", "--quiet", "-c", "chore/deps"]);
            let got = sync(lab.request());
            assert!(got.is_ok(), "{got:?}");
            assert_eq!(lab.head(), "main");
        }

        #[test]
        fn a_stale_lock_bump_is_dropped_even_without_an_update() {
            let Some(lab) = Lab::new("lock") else { return };
            lab.commit("seed", "flake.lock", "lock 2");
            lab.git("seed", &["push", "--quiet"]);
            lab.write("work", "flake.lock", "local bump");
            let got = sync(lab.request());
            assert!(
                got.as_ref().is_ok_and(|l| l.line.contains("dropped")),
                "{got:?}"
            );
            assert_eq!(
                std::fs::read_to_string(lab.path("work").join("flake.lock"))
                    .ok()
                    .as_deref(),
                Some("lock 2")
            );
        }

        #[test]
        fn a_lock_bump_that_does_not_conflict_is_kept() {
            let Some(lab) = Lab::new("lockok") else {
                return;
            };
            lab.commit("seed", "flake.nix", "nix 2");
            lab.git("seed", &["push", "--quiet"]);
            lab.write("work", "flake.lock", "local bump");
            let got = sync(lab.request());
            assert!(got.is_ok(), "{got:?}");
            assert_eq!(
                std::fs::read_to_string(lab.path("work").join("flake.lock"))
                    .ok()
                    .as_deref(),
                Some("local bump")
            );
        }

        #[test]
        fn diverged_history_is_refused() {
            let Some(lab) = Lab::new("div") else { return };
            lab.commit("seed", "flake.nix", "upstream");
            lab.git("seed", &["push", "--quiet"]);
            lab.commit("work", "other.nix", "local");
            let got = sync(lab.request());
            assert!(got.is_err_and(|r| r.code == "NOT_FAST_FORWARD"));
        }

        #[test]
        fn a_detached_head_goes_to_main() {
            let Some(lab) = Lab::new("det") else { return };
            lab.git("work", &["switch", "--quiet", "--detach"]);
            let got = sync(lab.request());
            assert!(got.is_ok(), "{got:?}");
            assert_eq!(lab.head(), "main");
        }

        #[test]
        fn dry_run_reports_without_moving() {
            let Some(lab) = Lab::new("dry") else { return };
            lab.commit("seed", "flake.nix", "nix 2");
            lab.git("seed", &["push", "--quiet"]);
            let before = lab.git("work", &["rev-parse", "HEAD"]);
            let got = sync(Request {
                dry: true,
                ..lab.request()
            });
            assert!(
                got.as_ref()
                    .is_ok_and(|l| l.line.contains("1 commit(s) behind")),
                "{got:?}"
            );
            assert_eq!(lab.git("work", &["rev-parse", "HEAD"]), before);
        }
    }
}
