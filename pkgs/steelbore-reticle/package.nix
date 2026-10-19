# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — steelbore-reticle (console mouse, Rust gpm replacement) package
{
  lib,
  rustPlatform,
}:

let
  # Packages get no specialArgs, so read the identity file directly — the same
  # file flake.nix threads to modules as `steelboreIdentity`.
  identity = import ../../lib/identity.nix;
in
rustPlatform.buildRustPackage {
  pname = "steelbore-reticle";
  version = "0.1.0";

  src = lib.cleanSource ./.;

  cargoLock.lockFile = ./Cargo.lock;

  # The project URL --version, --help, describe and the JSON envelope print.
  # build.rs re-exports it for `env!`; its fallback only serves a `cargo build`
  # outside Nix. (STEELBORE_OS_NAME is unused here but kept so build.rs stays
  # identical to preflight's.)
  env = {
    STEELBORE_OS_NAME = identity.name;
    STEELBORE_OS_URL = identity.urls.home;
  };

  # No nativeBuildInputs and no buildInputs: every dependency is pure Rust, and
  # `rustix` talks to the kernel through linux-raw-sys rather than libc.
  meta = {
    description = "Mouse selection, paste and mouse reporting on the Linux virtual consoles (a Rust gpm replacement)";
    license = lib.licenses.gpl3Plus;
    mainProgram = "steelbore-reticle";
    platforms = lib.platforms.linux;
  };
}
