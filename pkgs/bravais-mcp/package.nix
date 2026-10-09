# SPDX-License-Identifier: GPL-3.0-or-later
{ lib, rustPlatform }:

let
  # Packages get no specialArgs, so read the identity file directly — the same
  # file flake.nix threads to modules as `steelboreIdentity`.
  identity = import ../../lib/identity.nix;
in
rustPlatform.buildRustPackage {
  pname = "bravais-mcp";
  version = "0.1.0";

  src = ../../bravais-mcp;

  cargoHash = "sha256-69rW1rKd95XRSlgGWBRAUB8bnzWDwipFc/co5HJHBGs=";

  # The OS name and URL the `env` command and MCP tool report. libbravais-mcp
  # reads them with `option_env!`; its fallbacks only serve a `cargo build`
  # outside Nix.
  env = {
    STEELBORE_OS_FULL_NAME = identity.fullName;
    STEELBORE_OS_URL = identity.urls.home;
  };

  meta = with lib; {
    description = "Rust Model Context Protocol server for ${identity.fullName}";
    homepage = "https://Bravais-MCP.SpacecraftSoftware.org/";
    license = licenses.gpl3Plus;
    maintainers = [ "Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>" ];
    platforms = platforms.linux;
    mainProgram = "bravais-cli";
  };
}
