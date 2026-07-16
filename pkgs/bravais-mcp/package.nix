# SPDX-License-Identifier: GPL-3.0-or-later
{ lib, rustPlatform }:

rustPlatform.buildRustPackage {
  pname = "bravais-mcp";
  version = "0.1.0";

  src = ../../bravais-mcp;

  cargoHash = "sha256-hXcopCNFUlbhXiiBB2uU2Kg1HC221Hme/MpgNRUh1mE=";

  meta = with lib; {
    description = "Rust Model Context Protocol server for Steelbore OS Bravais";
    homepage = "https://Bravais-MCP.SpacecraftSoftware.org/";
    license = licenses.gpl3Plus;
    maintainers = [ "Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>" ];
    platforms = platforms.linux;
    mainProgram = "bravais-cli";
  };
}
