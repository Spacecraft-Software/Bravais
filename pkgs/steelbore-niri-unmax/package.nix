# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — steelbore-niri-unmax daemon package
{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "steelbore-niri-unmax";
  version = "0.1.0";

  src = lib.cleanSource ./.;

  cargoLock.lockFile = ./Cargo.lock;

  meta = {
    description = "Un-maximize windows that open maximized-to-edges under the niri compositor";
    license = lib.licenses.gpl3Plus;
    mainProgram = "steelbore-niri-unmax";
    platforms = lib.platforms.linux;
  };
}
