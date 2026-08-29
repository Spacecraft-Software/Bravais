# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — preflight rebuild-orchestrator package
{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "preflight";
  version = "0.1.0";

  src = lib.cleanSource ./.;

  cargoLock.lockFile = ./Cargo.lock;

  # No nativeBuildInputs and no buildInputs: every dependency is pure Rust.
  # `rustix` talks to the kernel through linux-raw-sys rather than libc here, so
  # there is nothing for pkg-config to find.

  # The tools preflight drives -- nixos-rebuild, nix, sudo, rsync, vacuum,
  # gitway-add, mcpctl, flatpak -- are deliberately NOT wrapped onto PATH.
  # Every one is expected to be the user's own, resolved at run time: pinning
  # them into a store closure here would freeze `vacuum` and `mcpctl` at
  # whatever revision this derivation last built, which is exactly the drift the
  # mcpctl probe exists to report on (AGENTS.md constraint #23 makes the same
  # point about resolving MCP binaries by bare name).
  meta = {
    description = "Steelbore OS rebuild orchestrator: preflight checks, the switch, postflight disk accounting";
    license = lib.licenses.gpl3Plus;
    mainProgram = "preflight";
    platforms = lib.platforms.linux;
  };
}
