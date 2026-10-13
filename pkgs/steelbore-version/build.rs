// SPDX-License-Identifier: GPL-3.0-or-later
//
// Re-export the OS identity into the compile as `env!`-readable variables.
//
// Nix supplies STEELBORE_OS_NAME and STEELBORE_OS_URL from lib/identity.nix
// (pkgs/steelbore-version/package.nix), so the name in `--help`, `--version`
// and `describe` is the one the rest of the system uses, stated once. A build
// script rather than `option_env!` because clap's `about`, `long_version` and
// `after_help` are composed with `concat!`, which takes only literals and
// `env!`, and `env!` fails the compile when the variable is unset.
//
// Only these two static strings are compiled in. Everything that changes with
// the system -- version, revisions, codename -- is read at run time from the
// version record (src/record.rs), so a nixpkgs bump never rebuilds this crate.
//
// The fallbacks serve a plain `cargo build` outside Nix only; the packaged
// binary never sees them.

// Rust guideline compliant 2026-05-18

/// `(variable, fallback for a build outside Nix)`.
const IDENTITY: [(&str, &str); 2] = [
    ("STEELBORE_OS_NAME", "Steelbore OS"),
    (
        "STEELBORE_OS_URL",
        "https://Bravais.SpacecraftSoftware.org/",
    ),
];

fn main() {
    for (var, fallback) in IDENTITY {
        println!("cargo:rerun-if-env-changed={var}");
        let value = std::env::var(var).unwrap_or_else(|_| fallback.to_owned());
        println!("cargo:rustc-env={var}={value}");
    }
}
