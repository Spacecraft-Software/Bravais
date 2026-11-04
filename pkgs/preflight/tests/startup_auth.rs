// SPDX-License-Identifier: GPL-3.0-or-later
//! Exercise startup authorization with fake helpers, never host credentials.

use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::PathBuf;
use std::process::{Command, Output, Stdio};
use std::sync::atomic::{AtomicUsize, Ordering};

static NEXT: AtomicUsize = AtomicUsize::new(0);

struct Fixture(PathBuf);

impl Fixture {
    fn new() -> Self {
        let dir = std::env::temp_dir().join(format!(
            "preflight-startup-auth-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&dir).unwrap();
        // Nix builders have sh on PATH, although /bin/sh is absent there.
        let shell = std::env::split_paths(&std::env::var_os("PATH").unwrap())
            .map(|p| p.join("sh"))
            .find(|p| p.is_file())
            .and_then(|p| fs::canonicalize(p).ok())
            .expect("tests require a POSIX shell");
        for tool in [
            "sudo",
            "doas",
            "run0",
            "gitway-add",
            "git",
            "nix",
            "nu",
            "nixos-rebuild",
        ] {
            let status = if matches!(tool, "sudo" | "doas" | "run0") {
                "${PREFLIGHT_TEST_AUTH_EXIT:-1}"
            } else {
                "1"
            };
            let script = format!(
                "#!{}\nprintf '%s' '{tool}' >> \"$PREFLIGHT_TEST_LOG\"\nprintf ' <%s>' \"$@\" >> \"$PREFLIGHT_TEST_LOG\"\nprintf '\\n' >> \"$PREFLIGHT_TEST_LOG\"\nexit {status}\n",
                shell.display()
            );
            let path = dir.join(tool);
            fs::write(&path, script).unwrap();
            fs::set_permissions(path, fs::Permissions::from_mode(0o755)).unwrap();
        }
        Self(dir)
    }

    fn run(&self, tool: &str, auth_exit: &str, args: &[&str]) -> Output {
        Command::new(env!("CARGO_BIN_EXE_preflight"))
            .args(args)
            .env("PATH", &self.0)
            .env("PREFLIGHT_PRIVILEGE_TOOL", tool)
            .env("PREFLIGHT_TEST_AUTH_EXIT", auth_exit)
            .env("PREFLIGHT_TEST_LOG", self.0.join("calls"))
            .env("AI_AGENT", "startup-auth-test")
            .env_remove("DBUS_SESSION_BUS_ADDRESS")
            .stdin(Stdio::null())
            .output()
            .unwrap()
    }

    fn calls(&self) -> String {
        fs::read_to_string(self.0.join("calls")).unwrap_or_default()
    }
}

impl Drop for Fixture {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

#[test]
fn denied_authentication_stops_before_ssh_updates_or_other_helpers() {
    for (tool, expected) in [
        ("sudo", "sudo <-n> <-v>\n"),
        ("doas", "doas <-n> <true>\n"),
        ("run0", "run0 <--no-ask-password> <true>\n"),
    ] {
        let fixture = Fixture::new();
        let output = fixture.run(tool, "1", &["--json", "--no-notify"]);
        assert_eq!(output.status.code(), Some(4));
        assert!(output.stdout.is_empty());
        assert!(String::from_utf8_lossy(&output.stderr).contains("AUTHENTICATION_FAILED"));
        assert_eq!(fixture.calls(), expected);
    }
}

#[test]
fn authentication_happens_before_checkout_work() {
    let fixture = Fixture::new();
    let output = fixture.run("sudo", "0", &["--json", "--no-notify"]);
    // The fake git rejects checkout operations (or the fixed checkout path
    // does not exist in a Nix sandbox). Neither case may precede authentication.
    assert!(!output.status.success());
    assert!(fixture.calls().starts_with("sudo <-n> <-v>\n"));
    assert!(!fixture.calls().contains("nixos-rebuild"));
}

#[test]
fn read_only_commands_do_not_resolve_or_invoke_privilege_helpers() {
    let fixture = Fixture::new();
    let output = fixture.run("invalid", "1", &["schema", "--json"]);
    assert!(output.status.success());
    assert!(fixture.calls().is_empty());
}

#[test]
fn dry_build_uses_the_unprivileged_rebuild_command() {
    let fixture = Fixture::new();
    let output = fixture.run(
        "invalid",
        "1",
        &[
            "--dry",
            "--no-sync",
            "--no-update",
            "--no-gc",
            "--no-appimages",
            "--no-flatpak",
            "--no-commit",
            "--no-notify",
            "--update-vendored",
            "--json",
        ],
    );
    assert_eq!(output.status.code(), Some(1)); // the fake rebuild deliberately fails
    let report: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    let steps = report["data"]["steps"].as_array().unwrap();
    assert!(steps.iter().any(|s| s["name"] == "nixos-rebuild"));
    assert!(!steps.iter().any(|s| s["name"] == "authenticate"));
    let calls = fixture.calls();
    // In Nix builders the fixed host checkout is absent: the rebuild is
    // attempted, but chdir fails before the fake command can run.
    if std::path::Path::new("/spacecraft-software/bravais").is_dir() {
        assert!(calls.contains("nixos-rebuild <dry-build>"), "{calls}");
    }
    assert!(!calls.lines().any(|line| {
        ["sudo", "doas", "run0"]
            .iter()
            .any(|tool| line.starts_with(tool))
    }));
}
