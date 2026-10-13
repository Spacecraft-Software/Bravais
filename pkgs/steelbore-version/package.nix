# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — steelbore-version, which also answers as nixos-version
{
  lib,
  rustPlatform,
}:

let
  # Packages get no specialArgs, so read the identity file directly — the same
  # file flake.nix threads to modules as `steelboreIdentity`.
  steelboreIdentity = import ../../lib/identity.nix;
in
rustPlatform.buildRustPackage {
  pname = "steelbore-version";
  version = "0.1.0";

  src = lib.cleanSource ./.;

  cargoLock.lockFile = ./Cargo.lock;

  # The OS name and URL that --help, --version and `describe` print. build.rs
  # re-exports them for `env!`. Nothing about a particular system is compiled
  # in: version, revisions and codename come from the version record that
  # modules/core/identity.nix writes, so this derivation does not change when
  # nixpkgs is bumped.
  env = {
    STEELBORE_OS_NAME = steelboreIdentity.name;
    STEELBORE_OS_URL = steelboreIdentity.urls.home;
  };

  # One binary, two names: invoked as nixos-version it keeps NixOS's output
  # contract (src/compat.rs). Installing this name requires upstream's own
  # nixos-version to be switched off, or the system path collides
  # (CONSTRAINTS.md #47; modules/core/identity.nix does both).
  postInstall = ''
    ln -s steelbore-version $out/bin/nixos-version
  '';

  meta = {
    description = "${steelboreIdentity.name} version reporter; also answers as nixos-version";
    homepage = steelboreIdentity.urls.home;
    license = lib.licenses.gpl3Plus;
    mainProgram = "steelbore-version";
    platforms = lib.platforms.linux;
  };
}
