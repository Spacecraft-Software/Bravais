// SPDX-License-Identifier: GPL-3.0-or-later
//
// The AI tools installed outside Nix, and the command each one updates
// itself with.
//
// These live in the out-of-band bin dirs (users/mj/shell.nix `outOfBandDirs`)
// precisely because they release faster than nixpkgs and update themselves
// (constraint #4), so no flake update or vendored bump ever touches them.
// `--update-ai-tools` (and `--update-all`, which implies it) runs each
// updater in turn.
//
// Programs are resolved by bare name on the PATH preflight inherits from the
// login shell, never by a path written here: that is the whole point of the
// out-of-band dirs, and the same rule package.nix states for every tool
// preflight drives. A tool that is not installed is skipped, not failed, so
// this list can name tools a given machine never installed.

// Rust guideline compliant 2026-05-18

use std::path::{Path, PathBuf};
use std::time::Duration;

/// How a tool's update command relates to the binary it is found as.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    /// The program replaces itself (`claude update`). If the name resolves
    /// into the Nix store, the tool has since moved into Nix and asking it
    /// to overwrite itself would fail, so it is skipped instead.
    SelfUpdater,
    /// A package manager updating what it installed elsewhere (`uv tool
    /// upgrade --all`). Resolving into the Nix store is the normal case.
    PackageManager,
}

/// One updater: the step it reports as, and the command to run.
#[derive(Debug, Clone, Copy)]
pub struct Tool {
    pub step: &'static str,
    pub program: &'static str,
    pub args: &'static [&'static str],
    pub kind: Kind,
}

const fn updater(step: &'static str, program: &'static str, args: &'static [&'static str]) -> Tool {
    Tool {
        step,
        program,
        args,
        kind: Kind::SelfUpdater,
    }
}

/// Every updater, run in this order. Adding a tool is one line here.
///
/// Each command was read off the tool's own `--help` on 2026-10-13. None may
/// prompt: preflight gives every updater a null stdin, so a prompt reads EOF
/// and the tool declines (the `OpenCode` family asks "Install anyways?" when it
/// cannot tell how it was installed, and a null stdin answers no). `kiro-cli`
/// is the one that needs a flag to stay quiet.
pub const TOOLS: &[Tool] = &[
    updater("ai-claude", "claude", &["update"]),
    updater("ai-codex", "codex", &["update"]),
    updater("ai-opencode", "opencode", &["upgrade"]),
    updater("ai-kilo", "kilo", &["upgrade"]),
    updater("ai-mimo", "mimo", &["upgrade"]),
    updater("ai-qwen", "qwen", &["update"]),
    updater("ai-grok", "grok", &["update"]),
    updater("ai-kimi", "kimi", &["upgrade"]),
    updater("ai-cursor-agent", "cursor-agent", &["update"]),
    updater("ai-copilot", "copilot", &["update"]),
    updater("ai-kiro", "kiro-cli", &["update", "--non-interactive"]),
    updater("ai-goose", "goose", &["update"]),
    updater("ai-antigravity", "agy", &["update"]),
    updater("ai-omp", "omp", &["update"]),
    updater("ai-pool", "pool", &["update"]),
    // uv-installed tools: kimi-cli, llm, mistral-vibe, specify-cli, graphify.
    Tool {
        step: "ai-uv-tools",
        program: "uv",
        args: &["tool", "upgrade", "--all"],
        kind: Kind::PackageManager,
    },
    // npm globals under ~/.npm-packages (the prefix ~/.npmrc names).
    Tool {
        step: "ai-npm-globals",
        program: "npm",
        args: &["update", "--global"],
        kind: Kind::PackageManager,
    },
];

/// How long one updater may run before it is killed.
///
/// These are single-binary downloads, normally well under a minute; ten
/// minutes covers a slow mirror without letting a hung download hold
/// preflight open indefinitely -- the failure the detached Flatpak update
/// exists to avoid. Only the updater itself is killed, not any helper it
/// spawned: putting it in its own process group would also stop a Ctrl-C at
/// the terminal from reaching it.
pub const TIMEOUT: Duration = Duration::from_mins(10);

/// How often a running updater is polled for exit.
pub const POLL: Duration = Duration::from_millis(250);

impl Tool {
    /// The command as a person would type it, for reports.
    pub fn command_line(&self) -> String {
        std::iter::once(self.program)
            .chain(self.args.iter().copied())
            .collect::<Vec<_>>()
            .join(" ")
    }
}

/// Where `program` resolves on `path` (a `PATH`-style list), as a shell
/// would: the first directory holding an executable file of that name.
pub fn resolve(program: &str, path: &std::ffi::OsStr) -> Option<PathBuf> {
    std::env::split_paths(path)
        .map(|dir| dir.join(program))
        .find(|candidate| is_executable(candidate))
}

fn is_executable(path: &Path) -> bool {
    use std::os::unix::fs::PermissionsExt;
    std::fs::metadata(path).is_ok_and(|m| m.is_file() && m.permissions().mode() & 0o111 != 0)
}

/// Whether `path` is, after following symlinks, a Nix store path.
pub fn in_nix_store(path: &Path) -> bool {
    std::fs::canonicalize(path).is_ok_and(|p| p.starts_with("/nix/store"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn step_names_are_unique() {
        let mut names: Vec<_> = TOOLS.iter().map(|t| t.step).collect();
        names.sort_unstable();
        names.dedup();
        assert_eq!(names.len(), TOOLS.len());
    }

    #[test]
    fn command_line_joins_program_and_args() {
        let t = updater("x", "kiro-cli", &["update", "--non-interactive"]);
        assert_eq!(t.command_line(), "kiro-cli update --non-interactive");
    }

    #[test]
    fn a_missing_program_does_not_resolve() {
        assert!(resolve(
            "surely-not-a-real-program",
            std::ffi::OsStr::new("/nonexistent")
        )
        .is_none());
    }

    #[test]
    fn resolve_takes_the_first_match_on_path() {
        let dir = std::env::temp_dir().join(format!("preflight-resolve-{}", std::process::id()));
        let (a, b) = (dir.join("a"), dir.join("b"));
        for d in [&a, &b] {
            std::fs::create_dir_all(d).unwrap();
            let f = d.join("tool");
            std::fs::write(&f, b"").unwrap();
            let mut perm = std::fs::metadata(&f).unwrap().permissions();
            std::os::unix::fs::PermissionsExt::set_mode(&mut perm, 0o755);
            std::fs::set_permissions(&f, perm).unwrap();
        }
        let path = std::env::join_paths([&a, &b]).unwrap();
        assert_eq!(resolve("tool", &path), Some(a.join("tool")));
        std::fs::remove_dir_all(&dir).unwrap();
    }
}
