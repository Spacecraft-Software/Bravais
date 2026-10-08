# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — steelbore-quantize: pure-Rust PNG palette quantizer
# (imagequant + png), replacing pngquant's C front end and libpng in the
# build-time asset pipeline (pkgs/steelbore-plymouth).
{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "steelbore-quantize";
  version = "0.1.0";

  src = lib.cleanSource ./.;

  cargoLock.lockFile = ./Cargo.lock;

  # Every dependency is pure Rust (imagequant, png and their deflate/rayon
  # trees), so no pkg-config or C libraries are needed.

  meta = {
    description = "Palette-quantize a PNG with the Rust imagequant crate";
    license = lib.licenses.gpl3Plus;
    mainProgram = "steelbore-quantize";
    platforms = lib.platforms.unix;
  };
}
