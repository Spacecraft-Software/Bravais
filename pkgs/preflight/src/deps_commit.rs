// SPDX-License-Identifier: GPL-3.0-or-later
//
// Commit the bumps a run made, on a branch of their own.
//
// Until 2026-10-24 the flake update and the vendored bumper left `flake.lock`
// and the pinned files modified in the checkout, and nothing recorded them.
// The next sync then had to carry them, drop them or refuse over them, and the
// deps commit AGENTS.md asks for was a chore someone had to remember. Now a
// run that switched successfully commits what it bumped, right then.
//
// The policy, in order:
//
//   1. Only after a successful switch. The switch is the gate: a bump that
//      does not build is left in the tree, uncommitted, for the next run (or
//      a person) to fix, rather than recorded as if it were good.
//   2. After the /etc/nixos mirror, so the mirror is the tree that was built.
//   3. Only on origin's default branch. AGENTS.md keeps bumps in their own
//      `chore(deps)` branch and PR; one cut from a PR branch would carry that
//      PR's commits into the deps PR, so there the bumps stay uncommitted.
//   4. Never on the default branch itself. A new local branch,
//      `chore/deps-bump-<date>` (`-2`, `-3`, ... when one exists locally or
//      on origin), is cut from HEAD, the bumped paths -- and nothing else --
//      are committed there with a plain `git commit`, so the user's own
//      signing configuration applies, and the checkout switches back. Any
//      other uncommitted change is carried there and back untouched.
//   5. Never pushed. Publishing is the user's call; the step prints the
//      command.
//
// Switching back means the checkout's `flake.lock` is the default branch's
// again, older than the system that is now running, until the deps branch is
// merged. A following `--no-update` run builds that older lock.

use crate::git_sync::{default_branch, exists, git, git_shown, LOCK};

/// Every deps branch starts with this; the date follows.
pub const BRANCH_PREFIX: &str = "chore/deps-bump-";

/// The Copilot agent's lock-derived copy of the Construct skills, rewritten
/// by `pkgs/sync-skills.nu`. CI's Skills Drift check fails a push that moves
/// `construct` in the lock without it.
pub const SKILLS_DIR: &str = ".github/skills";

/// What this run bumped. Paths that were already modified before the run are
/// not in here: they are somebody else's change, and stay uncommitted.
#[derive(Debug, Default)]
pub struct Bumps {
    /// `flake.lock` differs from HEAD after a successful flake update.
    pub lock: bool,
    /// Pinned files `pkgs/update-vendored.nu` rewrote.
    pub vendored: Vec<String>,
    /// `.github/skills/` was re-synced to a moved `construct`.
    pub skills: bool,
}

impl Bumps {
    pub fn is_empty(&self) -> bool {
        !self.lock && self.vendored.is_empty() && !self.skills
    }

    /// The pathspecs to stage and commit.
    pub fn paths(&self) -> Vec<String> {
        let mut p = Vec::new();
        if self.lock {
            p.push(LOCK.to_owned());
        }
        p.extend(self.vendored.iter().cloned());
        if self.skills {
            p.push(SKILLS_DIR.to_owned());
        }
        p
    }

    /// The commit subject, naming what moved.
    pub fn subject(&self) -> String {
        let what = match (self.lock, self.vendored.is_empty()) {
            (true, false) => "flake inputs and vendored pins",
            (false, false) => "vendored pins",
            _ => "flake inputs",
        };
        format!("chore(deps): bump {what}")
    }
}

/// The first free deps branch name for `date`. Pure, so it is testable
/// without git; `taken` says whether a name is in use.
pub fn branch_name(date: &str, taken: impl Fn(&str) -> bool) -> String {
    let base = format!("{BRANCH_PREFIX}{date}");
    if !taken(&base) {
        return base;
    }
    (2_u32..=999)
        .map(|n| format!("{base}-{n}"))
        .find(|b| !taken(b))
        .unwrap_or(base)
}

/// The `construct` rev pinned by a `flake.lock` text.
fn construct_rev(lock: &str) -> Option<String> {
    let v: serde_json::Value = serde_json::from_str(lock).ok()?;
    v.pointer("/nodes/construct/locked/rev")?
        .as_str()
        .map(ToOwned::to_owned)
}

/// Whether the working tree's lock pins a different `construct` than HEAD's,
/// so `.github/skills/` has to be re-synced before the commit.
pub fn construct_moved(dir: &str) -> bool {
    let head = git(dir, &["show", &format!("HEAD:{LOCK}")]);
    let tree = std::fs::read_to_string(std::path::Path::new(dir).join(LOCK)).ok();
    match (head, tree) {
        (Some(h), Some(t)) => construct_rev(&h) != construct_rev(&t),
        _ => false,
    }
}

/// Whether `path` differs from HEAD in the working tree, untracked files
/// included (a skill Construct added is a new directory).
pub fn changed(dir: &str, path: &str) -> bool {
    git(dir, &["status", "--porcelain", "--", path]).is_some_and(|s| !s.is_empty())
}

/// The branch a commit may be cut from: the current one, if it is origin's
/// default branch. `Err` says why not, for a skipped step.
pub fn base(dir: &str) -> Result<String, String> {
    let default = default_branch(dir);
    match git(dir, &["symbolic-ref", "--quiet", "--short", "HEAD"]) {
        Some(cur) if cur == default => Ok(cur),
        Some(cur) => Err(format!(
            "on '{cur}', not {default}: a deps branch cut here would carry its commits"
        )),
        None => Err(format!("HEAD is detached, not on {default}")),
    }
}

/// A commit made.
#[derive(Debug)]
pub struct Committed {
    pub branch: String,
    pub commit: String,
}

/// Commit `bumps` on a new deps branch cut from `base`, then switch back.
///
/// `Err` carries a message for a failed step. On every failure the checkout
/// ends on `base` with the bumps still in the tree, as if the step never ran;
/// only a failed switch back can leave it elsewhere, and the message says so.
pub fn commit(dir: &str, base: &str, bumps: &Bumps, date: &str) -> Result<Committed, String> {
    let branch = branch_name(date, |b| {
        exists(dir, &format!("refs/heads/{b}")) || exists(dir, &format!("refs/remotes/origin/{b}"))
    });
    let paths = bumps.paths();

    // `switch --create` from HEAD always succeeds with a dirty tree: nothing
    // in the tree has to change.
    if !git_shown(dir, &["switch", "--create", &branch]) {
        return Err(format!("could not create branch '{branch}'"));
    }

    let mut add = vec!["add", "--all", "--"];
    add.extend(paths.iter().map(String::as_str));
    // `git commit -- <paths>` commits those paths only (`--only`), so a change
    // the user had staged elsewhere stays staged and out of this commit.
    // Plain `git commit`: commit.gpgsign and the signing key are the user's.
    let body = format!(
        "Committed by preflight after a successful switch.\n\nChanged:\n{}",
        paths
            .iter()
            .map(|p| format!("- {p}"))
            .collect::<Vec<_>>()
            .join("\n")
    );
    let subject = bumps.subject();
    let mut commit = vec!["commit", "--quiet", "-m", &subject, "-m", &body, "--"];
    commit.extend(paths.iter().map(String::as_str));

    if !(git_shown(dir, &add) && git_shown(dir, &commit)) {
        // The new branch still points at `base`'s commit, so switching back
        // carries the bumps along unchanged and deleting it loses nothing.
        let back = git_shown(dir, &["switch", base]);
        if back {
            let _ = git_shown(dir, &["branch", "--quiet", "--delete", &branch]);
        }
        return Err(if back {
            "git commit failed (is the signing key loaded? gitway-add ~/.ssh/id_ed25519); bumps left uncommitted".to_owned()
        } else {
            format!("git commit failed and the checkout is still on '{branch}'")
        });
    }

    let sha = git(dir, &["rev-parse", "--short", "HEAD"]).unwrap_or_default();
    // Only the committed paths differ between the two branches, and they are
    // clean now, so the switch back cannot clash with a carried change.
    if !git_shown(dir, &["switch", base]) {
        return Err(format!(
            "committed {sha} on '{branch}', but could not switch back to '{base}'"
        ));
    }
    Ok(Committed {
        branch,
        commit: sha,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_first_free_name_is_taken() {
        assert_eq!(
            branch_name("2026-10-24", |_| false),
            "chore/deps-bump-2026-10-24"
        );
        let taken = ["chore/deps-bump-2026-10-24", "chore/deps-bump-2026-10-24-2"];
        assert_eq!(
            branch_name("2026-10-24", |b| taken.contains(&b)),
            "chore/deps-bump-2026-10-24-3"
        );
    }

    #[test]
    fn the_subject_names_what_moved() {
        let lock = Bumps {
            lock: true,
            ..Bumps::default()
        };
        assert_eq!(lock.subject(), "chore(deps): bump flake inputs");
        let both = Bumps {
            lock: true,
            vendored: vec!["pkgs/ollama/package.nix".into()],
            skills: false,
        };
        assert_eq!(
            both.subject(),
            "chore(deps): bump flake inputs and vendored pins"
        );
        assert_eq!(both.paths(), ["flake.lock", "pkgs/ollama/package.nix"]);
    }

    #[test]
    fn the_construct_rev_is_read_from_the_lock() {
        let lock = r#"{"nodes":{"construct":{"locked":{"rev":"abc"}}}}"#;
        assert_eq!(construct_rev(lock).as_deref(), Some("abc"));
        assert_eq!(construct_rev("{}"), None);
    }

    /// End-to-end against a throwaway repository; skipped without git, as in
    /// `git_sync`'s tests.
    mod against_git {
        use super::super::*;
        use std::path::PathBuf;
        use std::process::Command;

        struct Lab {
            root: PathBuf,
        }

        impl Lab {
            fn new(name: &str) -> Option<Self> {
                Command::new("git").arg("--version").output().ok()?;
                let root = std::env::temp_dir().join(format!(
                    "preflight-deps-commit-{}-{name}",
                    std::process::id()
                ));
                let _ = std::fs::remove_dir_all(&root);
                std::fs::create_dir_all(root.join("pkgs/x")).ok()?;
                let lab = Self { root };
                lab.git(&["init", "--quiet", "-b", "main"]);
                for (k, v) in [
                    ("user.name", "t"),
                    ("user.email", "t@example.org"),
                    ("commit.gpgsign", "false"),
                ] {
                    lab.git(&["config", k, v]);
                }
                lab.write("flake.lock", "lock 1");
                lab.write("pkgs/x/package.nix", "pin 1");
                lab.write("flake.nix", "nix 1");
                lab.git(&["add", "-A"]);
                lab.git(&["commit", "--quiet", "-m", "seed"]);
                Some(lab)
            }

            fn dir(&self) -> String {
                self.root.display().to_string()
            }

            fn git(&self, args: &[&str]) -> String {
                let out = Command::new("git")
                    .arg("-C")
                    .arg(&self.root)
                    .args(args)
                    .output()
                    .ok()
                    .filter(|o| o.status.success());
                assert!(out.is_some(), "git {args:?}");
                out.map(|o| String::from_utf8_lossy(&o.stdout).trim().to_owned())
                    .unwrap_or_default()
            }

            fn write(&self, file: &str, body: &str) {
                assert!(std::fs::write(self.root.join(file), body).is_ok());
            }

            fn read(&self, file: &str) -> String {
                std::fs::read_to_string(self.root.join(file)).unwrap_or_default()
            }
        }

        impl Drop for Lab {
            fn drop(&mut self) {
                let _ = std::fs::remove_dir_all(&self.root);
            }
        }

        #[test]
        fn bumps_land_on_a_new_branch_and_main_is_left_clean() {
            let Some(lab) = Lab::new("ok") else { return };
            lab.write("flake.lock", "lock 2");
            lab.write("pkgs/x/package.nix", "pin 2");
            lab.write("flake.nix", "an experiment");
            lab.write("staged.txt", "staged");
            lab.git(&["add", "staged.txt"]);
            let bumps = Bumps {
                lock: true,
                vendored: vec!["pkgs/x/package.nix".into()],
                skills: false,
            };
            let got = commit(&lab.dir(), "main", &bumps, "2026-10-24");
            assert!(
                got.as_ref()
                    .is_ok_and(|c| c.branch == "chore/deps-bump-2026-10-24"),
                "{got:?}"
            );
            assert_eq!(lab.git(&["symbolic-ref", "--short", "HEAD"]), "main");
            // The bumps are committed there and gone from main's tree...
            assert_eq!(lab.read("flake.lock"), "lock 1");
            assert_eq!(
                lab.git(&["show", "chore/deps-bump-2026-10-24:pkgs/x/package.nix"]),
                "pin 2"
            );
            assert_eq!(
                lab.git(&["log", "-1", "--format=%s", "chore/deps-bump-2026-10-24"]),
                "chore(deps): bump flake inputs and vendored pins"
            );
            // ...and nothing else went with them.
            assert_eq!(lab.read("flake.nix"), "an experiment");
            assert_eq!(
                lab.git(&["diff", "--name-only", "main", "chore/deps-bump-2026-10-24"]),
                "flake.lock\npkgs/x/package.nix"
            );
            assert_eq!(lab.git(&["diff", "--cached", "--name-only"]), "staged.txt");

            // A second run the same day takes the next name.
            lab.write("flake.lock", "lock 3");
            let again = commit(
                &lab.dir(),
                "main",
                &Bumps {
                    lock: true,
                    ..Bumps::default()
                },
                "2026-10-24",
            );
            assert!(
                again
                    .as_ref()
                    .is_ok_and(|c| c.branch == "chore/deps-bump-2026-10-24-2"),
                "{again:?}"
            );
        }

        #[test]
        fn a_failed_commit_leaves_the_bumps_in_place_on_main() {
            let Some(lab) = Lab::new("fail") else { return };
            lab.write("flake.lock", "lock 2");
            // A hook that refuses stands in for a signing failure.
            let hooks = lab.root.join(".git/hooks/pre-commit");
            assert!(std::fs::write(&hooks, "#!/bin/sh\nexit 1\n").is_ok());
            let _ = Command::new("chmod").arg("+x").arg(&hooks).status();
            let got = commit(
                &lab.dir(),
                "main",
                &Bumps {
                    lock: true,
                    ..Bumps::default()
                },
                "2026-10-24",
            );
            assert!(got.is_err(), "{got:?}");
            assert_eq!(lab.git(&["symbolic-ref", "--short", "HEAD"]), "main");
            assert_eq!(lab.read("flake.lock"), "lock 2");
            assert_eq!(lab.git(&["branch", "--list", "chore/*"]), "");
        }

        #[test]
        fn only_the_default_branch_is_a_base() {
            let Some(lab) = Lab::new("base") else { return };
            assert_eq!(base(&lab.dir()).ok().as_deref(), Some("main"));
            lab.git(&["switch", "--quiet", "-c", "pr"]);
            assert!(base(&lab.dir()).is_err());
        }
    }
}
