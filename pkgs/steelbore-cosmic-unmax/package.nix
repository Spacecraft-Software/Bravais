# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — steelbore-cosmic-unmax daemon package
{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "steelbore-cosmic-unmax";
  version = "0.1.0";

  # `lib.cleanSource` and not a filtered subset: protocols/*.xml must reach the
  # builder. wayland-scanner reads them at COMPILE time (the `generate_*!`
  # macros expand against the files on disk), so leaving them out of the source
  # closure fails the build rather than the run.
  src = lib.cleanSource ./.;

  cargoLock.lockFile = ./Cargo.lock;

  # No buildInputs: wayland-client defaults to wayland-backend's pure-Rust
  # implementation, so neither libwayland nor pkg-config is needed at build or
  # run time. Adding the `client_system` feature would change that.

  meta = {
    description = "Un-maximize windows that maximize themselves on open under the COSMIC compositor";
    license = lib.licenses.gpl3Plus;
    mainProgram = "steelbore-cosmic-unmax";
    platforms = lib.platforms.linux;
  };
}
