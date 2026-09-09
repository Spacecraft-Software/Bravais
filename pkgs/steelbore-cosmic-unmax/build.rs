// SPDX-License-Identifier: GPL-3.0-or-later
//
// Rebuild the generated protocol bindings whenever a vendored XML changes.
// The XMLs are vendored (see protocols/README rationale in src/main.rs) rather
// than pulled from the `cosmic-protocols` git repository, so this crate builds
// from crates.io alone and needs no `cargoLock.outputHashes` entry in Nix.

fn main() {
    println!("cargo:rerun-if-changed=protocols/cosmic-toplevel-info-unstable-v1.xml");
    println!("cargo:rerun-if-changed=protocols/cosmic-toplevel-management-unstable-v1.xml");
}
