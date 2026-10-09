# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — preflight rebuild-orchestrator package
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
  pname = "preflight";
  version = "0.1.0";

  src = lib.cleanSource ./.;

  cargoLock.lockFile = ./Cargo.lock;

  # The OS name and URL the binary prints (--help, --version, describe, schema,
  # the JSON envelope). build.rs re-exports them for `env!`; its fallbacks only
  # serve a `cargo build` outside Nix.
  env = {
    STEELBORE_OS_NAME = identity.name;
    STEELBORE_OS_URL = identity.urls.home;
  };

  # No nativeBuildInputs and no buildInputs: every dependency is pure Rust.
  # `rustix` talks to the kernel through linux-raw-sys rather than libc here, so
  # there is nothing for pkg-config to find.

  # The tools preflight drives -- nixos-rebuild, nix, sudo, rsync, vacuum,
  # gitway-add, mcpctl, flatpak -- are deliberately NOT wrapped onto PATH.
  # Every one is expected to be the user's own, resolved at run time: pinning
  # them into a store closure here would freeze `vacuum` and `mcpctl` at
  # whatever revision this derivation last built, which is exactly the drift the
  # mcpctl probe exists to report on (CONSTRAINTS.md #23 makes the same
  # point about resolving MCP binaries by bare name).
  meta = {
    description = "${identity.name} rebuild orchestrator: preflight checks, the switch, postflight disk accounting";
    license = lib.licenses.gpl3Plus;
    mainProgram = "preflight";
    platforms = lib.platforms.linux;
  };
}
