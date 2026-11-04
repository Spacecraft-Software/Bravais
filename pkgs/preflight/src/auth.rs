// SPDX-License-Identifier: GPL-3.0-or-later
//! Select privilege escalation and authenticate before starting expensive work.
//!
//! Credentials and their lifetime belong to sudo, doas, or polkit. Preflight
//! never reads passwords, refreshes timestamps in the background, or changes
//! policy. Later commands may authenticate again when that policy requires it.
// Rust guideline compliant 2026-05-18

use std::os::unix::fs::PermissionsExt;
use std::process::Command;

use crate::git_sync::Refusal;
use crate::output::Exit;

pub const TOOL_ENV: &str = "PREFLIGHT_PRIVILEGE_TOOL";

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Privilege {
    Sudo,
    Doas,
    Run0,
}

impl Privilege {
    pub const fn name(self) -> &'static str {
        match self {
            Self::Sudo => "sudo",
            Self::Doas => "doas",
            Self::Run0 => "run0",
        }
    }

    /// Ask the helper to authenticate using its own configured policy.
    pub fn authenticate(self, interactive: bool) -> Command {
        let mut cmd = Command::new(self.name());
        if !interactive {
            cmd.arg(if self == Self::Run0 {
                "--no-ask-password"
            } else {
                "-n"
            });
        }
        // doas has no portable validate-only flag; older run0 releases do
        // not have one either. A privileged no-op uses their normal policy.
        // Their policy must allow `true` as well as the maintenance commands;
        // permission for nixos-rebuild alone cannot authorize this probe.
        cmd.arg(if self == Self::Sudo { "-v" } else { "true" });
        cmd
    }

    pub fn command(self, program: &str) -> Command {
        let mut cmd = Command::new(self.name());
        cmd.arg(program);
        cmd
    }
}

/// Resolve one helper for the entire run; never fall back after a refusal.
///
/// # Errors
/// Returns a usage error for an invalid selector, or not-found when the
/// requested helper (or every automatic candidate) is unavailable.
pub fn resolve() -> Result<Privilege, Refusal> {
    let requested = match std::env::var(TOOL_ENV) {
        Ok(value) => value,
        Err(std::env::VarError::NotPresent) => "auto".to_owned(),
        Err(std::env::VarError::NotUnicode(_)) => return Err(invalid_selector()),
    };
    select(&requested, executable_on_path)
}

fn select(requested: &str, available: impl Fn(&str) -> bool) -> Result<Privilege, Refusal> {
    let candidates: &[Privilege] = match requested {
        "auto" => &[Privilege::Sudo, Privilege::Doas, Privilege::Run0],
        "sudo" => &[Privilege::Sudo],
        "doas" => &[Privilege::Doas],
        "run0" => &[Privilege::Run0],
        _ => return Err(invalid_selector()),
    };
    candidates
        .iter()
        .copied()
        .find(|tool| available(tool.name()))
        .ok_or_else(|| Refusal {
            code: "NO_PRIVILEGE_TOOL",
            exit: Exit::NotFound,
            message: format!("no available privilege helper for {TOOL_ENV}={requested}"),
            hint: "env PREFLIGHT_PRIVILEGE_TOOL=auto preflight".to_owned(),
        })
}

fn invalid_selector() -> Refusal {
    Refusal {
        code: "INVALID_PRIVILEGE_TOOL",
        exit: Exit::Usage,
        message: format!("{TOOL_ENV} must be auto, sudo, doas, or run0"),
        hint: "env PREFLIGHT_PRIVILEGE_TOOL=auto preflight".to_owned(),
    }
}

fn executable_on_path(program: &str) -> bool {
    std::env::var_os("PATH").is_some_and(|path| {
        std::env::split_paths(&path).any(|dir| {
            dir.join(program)
                .metadata()
                .is_ok_and(|meta| meta.is_file() && meta.permissions().mode() & 0o111 != 0)
        })
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn automatic_selection_preserves_sudo_preference_and_supports_fallbacks() {
        assert_eq!(select("auto", |_| true).unwrap(), Privilege::Sudo);
        assert_eq!(select("auto", |p| p != "sudo").unwrap(), Privilege::Doas);
        assert_eq!(select("auto", |p| p == "run0").unwrap(), Privilege::Run0);
    }

    #[test]
    fn explicit_selection_never_falls_back() {
        let err = select("doas", |p| p == "sudo").unwrap_err();
        assert_eq!(err.code, "NO_PRIVILEGE_TOOL");
        assert!(matches!(err.exit, Exit::NotFound));
        assert_eq!(
            select("sudo -v", |_| true).unwrap_err().code,
            "INVALID_PRIVILEGE_TOOL"
        );
    }

    #[test]
    fn helper_specific_authentication_keeps_policy_with_the_helper() {
        for (tool, interactive, expected) in [
            (Privilege::Sudo, true, vec!["-v"]),
            (Privilege::Sudo, false, vec!["-n", "-v"]),
            (Privilege::Doas, true, vec!["true"]),
            (Privilege::Doas, false, vec!["-n", "true"]),
            (Privilege::Run0, true, vec!["true"]),
            (Privilege::Run0, false, vec!["--no-ask-password", "true"]),
        ] {
            let cmd = tool.authenticate(interactive);
            assert_eq!(cmd.get_program(), tool.name());
            assert_eq!(cmd.get_args().collect::<Vec<_>>(), expected);
        }
    }
}
