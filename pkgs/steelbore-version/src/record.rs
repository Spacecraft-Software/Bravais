// SPDX-License-Identifier: GPL-3.0-or-later
//
// The version record: the facts about the running system that only NixOS
// module evaluation knows (release, version, revisions, codenames), written as
// JSON by modules/core/identity.nix and read here at run time.
//
// Reading a file instead of compiling the values in keeps this binary generic:
// it is built once and reused across nixpkgs bumps, while the record is
// regenerated with every system.

use std::fmt;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

/// Where the current system's record lives.
///
/// Under `/run/current-system/sw` because modules/core/identity.nix installs
/// it as a package, so it always describes the system that is switched in --
/// the same answer upstream's `nixos-version` gives. Not `/etc`: bubblewrap
/// FHS sandboxes (`AppImage`s, agent shells) mount a private tmpfs over `/etc`
/// but bind `/run`, so a record there would be invisible inside them.
pub const DEFAULT_PATH: &str = "/run/current-system/sw/share/steelbore/version.json";

/// Overrides [`DEFAULT_PATH`]: for tests, and for reading a record from a
/// built but not yet switched system (`result/sw/share/steelbore/version.json`).
pub const PATH_ENV: &str = "STEELBORE_VERSION_FILE";

/// The record format this binary reads. modules/core/identity.nix writes the
/// same number; bump both together when a field changes meaning or goes away.
/// Adding a field does not need a bump: unknown fields are ignored.
pub const SCHEMA: u32 = 1;

/// One system's version facts. Field names are the JSON keys, `snake_case` as
/// the CLI Standard requires, and are also the names `--fields` accepts.
#[derive(Debug, Clone, PartialEq, Eq, Deserialize, Serialize)]
pub struct Record {
    pub schema: u32,
    /// "Steelbore OS".
    pub name: String,
    /// "Bravais", the edition (os-release `VARIANT`).
    pub variant: String,
    /// os-release `ID`, "steelbore".
    pub id: String,
    /// os-release `VARIANT_ID`, "bravais".
    pub variant_id: String,
    pub vendor: String,
    /// "Steelbore OS Bravais 26.05 (Altair)", as os-release `PRETTY_NAME`.
    pub pretty_name: String,
    /// "26.05".
    pub release: String,
    /// "26.05.20261007.2efa67f", the full NixOS version string.
    pub version: String,
    /// The Steelbore OS codename for `release`, "Altair".
    pub codename: String,
    /// NixOS's own codename for the same release, kept for reference.
    pub nixos_codename: String,
    /// The nixpkgs commit, or `None` when the build could not know it.
    pub nixpkgs_revision: Option<String>,
    /// `system.configurationRevision`, or `None` when unset.
    pub configuration_revision: Option<String>,
    pub home_url: String,
}

/// Every key of a serialized [`Record`], in output order. `--fields` is
/// checked against this list, and `schema` publishes it.
pub const FIELDS: [&str; 14] = [
    "schema",
    "name",
    "variant",
    "id",
    "variant_id",
    "vendor",
    "pretty_name",
    "release",
    "version",
    "codename",
    "nixos_codename",
    "nixpkgs_revision",
    "configuration_revision",
    "home_url",
];

impl Record {
    /// The line both names print with no arguments: `<version> (<codename>)`,
    /// upstream `nixos-version`'s format with the Steelbore codename.
    #[must_use]
    pub fn version_line(&self) -> String {
        format!("{} ({})", self.version, self.codename)
    }

    /// The nixpkgs revision, only if it is a commit hash. Mirrors upstream's
    /// `^[0-9a-f]+$` test, so both names agree on when it is "unknown".
    #[must_use]
    pub fn known_nixpkgs_revision(&self) -> Option<&str> {
        self.nixpkgs_revision.as_deref().filter(|rev| {
            !rev.is_empty()
                && rev
                    .bytes()
                    .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
        })
    }
}

/// Why a record could not be read.
#[derive(Debug)]
pub enum LoadError {
    /// No file at the path: not a Steelbore OS system, or not switched yet.
    Missing(PathBuf),
    /// The file exists but could not be read.
    Unreadable(PathBuf, std::io::Error),
    /// The file is not a valid record.
    Invalid(PathBuf, serde_json::Error),
    /// The record is newer than this binary understands.
    Schema(PathBuf, u32),
}

impl fmt::Display for LoadError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Missing(p) => write!(f, "no version record at {}", p.display()),
            Self::Unreadable(p, e) => write!(f, "cannot read {}: {e}", p.display()),
            Self::Invalid(p, e) => write!(f, "{} is not a valid version record: {e}", p.display()),
            Self::Schema(p, n) => write!(
                f,
                "{} uses record schema {n}; this binary reads schema {SCHEMA}",
                p.display()
            ),
        }
    }
}

impl std::error::Error for LoadError {}

/// The record path: [`PATH_ENV`] when set and non-empty, else [`DEFAULT_PATH`].
#[must_use]
pub fn path() -> PathBuf {
    std::env::var_os(PATH_ENV)
        .filter(|v| !v.is_empty())
        .map_or_else(|| PathBuf::from(DEFAULT_PATH), PathBuf::from)
}

/// Read and validate the record at `path`.
///
/// # Errors
///
/// Returns [`LoadError`] when the file is absent, unreadable, malformed, or of
/// a schema other than [`SCHEMA`].
pub fn load(path: &Path) -> Result<Record, LoadError> {
    let text = std::fs::read_to_string(path).map_err(|e| {
        if e.kind() == std::io::ErrorKind::NotFound {
            LoadError::Missing(path.to_owned())
        } else {
            LoadError::Unreadable(path.to_owned(), e)
        }
    })?;
    // Check the schema number before the shape: a newer record may have
    // dropped or renamed fields, and "missing field" would hide the real
    // cause, which is that the binary and the record come from two systems.
    let value: serde_json::Value =
        serde_json::from_str(&text).map_err(|e| LoadError::Invalid(path.to_owned(), e))?;
    let schema = value.get("schema").and_then(serde_json::Value::as_u64);
    if let Some(n) = schema.filter(|&n| n != u64::from(SCHEMA)) {
        return Err(LoadError::Schema(
            path.to_owned(),
            u32::try_from(n).unwrap_or(u32::MAX),
        ));
    }
    serde_json::from_value(value).map_err(|e| LoadError::Invalid(path.to_owned(), e))
}

#[cfg(test)]
pub(crate) mod tests {
    use super::*;

    pub(crate) fn sample() -> Record {
        Record {
            schema: SCHEMA,
            name: "Steelbore OS".into(),
            variant: "Bravais".into(),
            id: "steelbore".into(),
            variant_id: "bravais".into(),
            vendor: "Spacecraft Software".into(),
            pretty_name: "Steelbore OS Bravais 26.05 (Altair)".into(),
            release: "26.05".into(),
            version: "26.05.20261007.2efa67f".into(),
            codename: "Altair".into(),
            nixos_codename: "Yarara".into(),
            nixpkgs_revision: Some("2efa67fd26b6df417c33e4603185c701f260dd83".into()),
            configuration_revision: None,
            home_url: "https://Bravais.SpacecraftSoftware.org/".into(),
        }
    }

    #[test]
    fn version_line_uses_steelbore_codename() {
        assert_eq!(sample().version_line(), "26.05.20261007.2efa67f (Altair)");
    }

    #[test]
    fn revision_must_be_lowercase_hex() {
        let mut r = sample();
        assert!(r.known_nixpkgs_revision().is_some());
        r.nixpkgs_revision = Some("2EFA67".into());
        assert_eq!(r.known_nixpkgs_revision(), None);
        r.nixpkgs_revision = Some(String::new());
        assert_eq!(r.known_nixpkgs_revision(), None);
        r.nixpkgs_revision = None;
        assert_eq!(r.known_nixpkgs_revision(), None);
    }

    #[test]
    fn fields_match_serialized_keys_in_order() {
        let value = serde_json::to_value(sample()).expect("a record always serializes");
        let keys: Vec<&str> = value
            .as_object()
            .expect("a record serializes to an object")
            .keys()
            .map(String::as_str)
            .collect();
        let mut sorted_fields = FIELDS.to_vec();
        sorted_fields.sort_unstable();
        let mut sorted_keys = keys.clone();
        sorted_keys.sort_unstable();
        assert_eq!(sorted_keys, sorted_fields);
    }

    #[test]
    fn load_reports_missing_and_schema() {
        let dir =
            std::env::temp_dir().join(format!("steelbore-version-test-{}", std::process::id()));
        std::fs::create_dir_all(&dir).expect("temp dir is writable");
        let missing = dir.join("absent.json");
        assert!(matches!(load(&missing), Err(LoadError::Missing(_))));

        // A future record that also lost a field must still report the schema.
        let future = dir.join("future.json");
        std::fs::write(&future, format!("{{\"schema\":{}}}", SCHEMA + 1))
            .expect("temp file is writable");
        assert!(matches!(load(&future), Err(LoadError::Schema(_, n)) if n == SCHEMA + 1));

        let good = dir.join("good.json");
        std::fs::write(&good, serde_json::to_string(&sample()).expect("serializes"))
            .expect("temp file is writable");
        assert_eq!(load(&good).expect("valid record loads"), sample());
        std::fs::remove_dir_all(&dir).expect("temp dir is removable");
    }
}

// Rust guideline compliant 2026-05-18
