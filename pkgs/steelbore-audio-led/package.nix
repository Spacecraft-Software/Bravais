# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — steelbore-audio-led daemon package
{
  lib,
  rustPlatform,
  pkg-config,
  libpulseaudio,
}:

rustPlatform.buildRustPackage {
  pname = "steelbore-audio-led";
  version = "0.1.0";

  src = lib.cleanSource ./.;

  cargoLock.lockFile = ./Cargo.lock;

  # libpulse-sys locates libpulse via pkg-config at build time.
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libpulseaudio ];

  meta = {
    description = "Mirror audio sink/source mute state onto ThinkPad mute / mic-mute keyboard LEDs";
    license = lib.licenses.gpl3Plus;
    mainProgram = "steelbore-audio-led";
    platforms = lib.platforms.linux;
  };
}
