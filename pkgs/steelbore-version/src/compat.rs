// SPDX-License-Identifier: GPL-3.0-or-later
//
// `nixos-version` compatibility: what this binary does when invoked under that
// name (the package installs `bin/nixos-version` as a symlink to it).
//
// It reproduces upstream's contract exactly -- nixpkgs
// nixos/modules/installer/tools/nixos-version.sh -- so scripts that parse
// `nixos-version` keep working on Steelbore OS: the same four modes, only `$1`
// consulted, upstream's messages and exit status 1, and upstream's camelCase
// JSON keys in `builtins.toJSON`'s (alphabetical) order. Two deliberate
// differences:
//
// - the codename is Steelbore OS's ("Altair"), which is the point of the alias;
// - `-h`/`--help` prints help instead of running `man nixos-version`, whose
//   page leaves the system together with upstream's script.
//
// None of the CLI Standard's machinery (envelope, agent detection, structured
// errors) applies here; that is `steelbore-version`'s surface. Callers of
// `nixos-version` expect `nixos-version`.

use serde::Serialize;

use crate::record::{LoadError, Record};

/// What one invocation writes and how it exits.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Reply {
    pub stdout: String,
    pub stderr: String,
    pub status: u8,
}

impl Reply {
    fn out(text: impl Into<String>) -> Self {
        Self {
            stdout: text.into(),
            stderr: String::new(),
            status: 0,
        }
    }

    /// Upstream's failure shape: `$0: <message>` on stderr, status 1.
    fn fail(prog: &str, message: impl std::fmt::Display) -> Self {
        Self {
            stdout: String::new(),
            stderr: format!("{prog}: {message}\n"),
            status: 1,
        }
    }
}

/// Upstream's `--json` object. Field order is `builtins.toJSON`'s, which sorts
/// keys; absent values are omitted, as upstream's `optionalAttrs` does.
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct UpstreamJson<'a> {
    #[serde(skip_serializing_if = "Option::is_none")]
    configuration_revision: Option<&'a str>,
    nixos_version: &'a str,
    #[serde(skip_serializing_if = "Option::is_none")]
    nixpkgs_revision: Option<&'a str>,
}

/// Help for the compatibility name. Upstream has none of its own (it defers
/// to the man page), so this says what the name now is and where the full
/// surface lives.
fn help(prog: &str) -> String {
    // The usage line names the command, not the store path it ran from.
    let prog = std::path::Path::new(prog)
        .file_name()
        .map_or(prog.into(), |n| n.to_string_lossy());
    format!(
        "Usage: {prog} [--hash | --revision | --configuration-revision | --json]\n\
         \n\
         On {os}, nixos-version is an alias for steelbore-version that keeps\n\
         upstream NixOS's output format, with the {os} release codename.\n\
         \n\
         \x20 (no option)               <version> (<codename>)\n\
         \x20 --hash, --revision        the nixpkgs commit\n\
         \x20 --configuration-revision  system.configurationRevision\n\
         \x20 --json                    nixosVersion, nixpkgsRevision, configurationRevision\n\
         \n\
         Run `steelbore-version --help` for the full interface.\n",
        os = env!("STEELBORE_OS_NAME"),
    )
}

/// Answer one `nixos-version` invocation. `prog` is `$0` as invoked (upstream
/// prints it in its messages); `first` is `$1`. The record is loaded lazily by
/// the caller and passed as a result, because `--help` must work without one.
pub fn respond(
    prog: &str,
    first: Option<&str>,
    record: impl FnOnce() -> Result<Record, LoadError>,
) -> Reply {
    if matches!(first, Some("-h" | "--help")) {
        return Reply::out(help(prog));
    }
    let record = match record() {
        Ok(r) => r,
        Err(e) => return Reply::fail(prog, e),
    };
    match first {
        Some("--hash" | "--revision") => match record.known_nixpkgs_revision() {
            Some(rev) => Reply::out(format!("{rev}\n")),
            None => Reply::fail(prog, "Nixpkgs commit hash is unknown"),
        },
        Some("--configuration-revision") => match record.configuration_revision.as_deref() {
            Some(rev) => Reply::out(format!("{rev}\n")),
            None => Reply::fail(prog, "configuration revision is unknown"),
        },
        Some("--json") => {
            let json = UpstreamJson {
                configuration_revision: record.configuration_revision.as_deref(),
                nixos_version: &record.version,
                nixpkgs_revision: record.nixpkgs_revision.as_deref(),
            };
            match serde_json::to_string(&json) {
                Ok(s) => Reply::out(format!("{s}\n")),
                Err(e) => Reply::fail(prog, e),
            }
        }
        // Upstream's `*)` arm: anything else, including no argument and
        // unknown options, prints the version line.
        _ => Reply::out(format!("{}\n", record.version_line())),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::record::tests::sample;

    fn run(first: Option<&str>, record: Record) -> Reply {
        respond("nixos-version", first, || Ok(record))
    }

    #[test]
    fn bare_and_unknown_options_print_the_version_line() {
        for first in [None, Some(""), Some("--bogus"), Some("extra")] {
            assert_eq!(
                run(first, sample()),
                Reply::out("26.05.20261007.2efa67f (Altair)\n")
            );
        }
    }

    #[test]
    fn json_matches_upstream_bytes() {
        // Captured from upstream nixos-version on this host, 2026-10-11, with
        // the configuration revision unset.
        let upstream = "{\"nixosVersion\":\"26.05.20261007.2efa67f\",\"nixpkgsRevision\":\"2efa67fd26b6df417c33e4603185c701f260dd83\"}\n";
        assert_eq!(run(Some("--json"), sample()).stdout, upstream);

        let mut r = sample();
        r.configuration_revision = Some("abc123".into());
        assert_eq!(
            run(Some("--json"), r).stdout,
            "{\"configurationRevision\":\"abc123\",\"nixosVersion\":\"26.05.20261007.2efa67f\",\"nixpkgsRevision\":\"2efa67fd26b6df417c33e4603185c701f260dd83\"}\n"
        );
    }

    #[test]
    fn hash_and_revision_print_or_fail_like_upstream() {
        for flag in ["--hash", "--revision"] {
            assert_eq!(
                run(Some(flag), sample()).stdout,
                "2efa67fd26b6df417c33e4603185c701f260dd83\n"
            );
        }
        let mut r = sample();
        r.nixpkgs_revision = None;
        let reply = run(Some("--hash"), r);
        assert_eq!(reply.status, 1);
        assert_eq!(
            reply.stderr,
            "nixos-version: Nixpkgs commit hash is unknown\n"
        );
    }

    #[test]
    fn configuration_revision_unknown_fails_like_upstream() {
        let reply = run(Some("--configuration-revision"), sample());
        assert_eq!(reply.status, 1);
        assert!(reply.stdout.is_empty());
        assert_eq!(
            reply.stderr,
            "nixos-version: configuration revision is unknown\n"
        );
    }

    #[test]
    fn help_needs_no_record() {
        let reply = respond("nixos-version", Some("--help"), || {
            Err(LoadError::Missing("/nowhere".into()))
        });
        assert_eq!(reply.status, 0);
        assert!(reply.stdout.starts_with("Usage: nixos-version"));
    }

    #[test]
    fn missing_record_fails_with_prog_prefix() {
        let reply = respond("/run/current-system/sw/bin/nixos-version", None, || {
            Err(LoadError::Missing("/nowhere.json".into()))
        });
        assert_eq!(reply.status, 1);
        assert_eq!(
            reply.stderr,
            "/run/current-system/sw/bin/nixos-version: no version record at /nowhere.json\n"
        );
    }
}

// Rust guideline compliant 2026-05-18
