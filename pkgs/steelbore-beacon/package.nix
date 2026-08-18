# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — steelbore-beacon status-feed daemon package
{
  lib,
  rustPlatform,
  pkg-config,
  libpulseaudio,
}:

rustPlatform.buildRustPackage {
  pname = "steelbore-beacon";
  version = "0.1.0";

  src = lib.cleanSource ./.;

  cargoLock.lockFile = ./Cargo.lock;

  # libpulse-sys locates libpulse via pkg-config at build time. `evdev` and
  # `rustix` are pure Rust and need nothing here.
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libpulseaudio ];

  meta = {
    description = "Publish audio, mic, backlight and lock-key state as JSON lines for the status bar";
    license = lib.licenses.gpl3Plus;
    mainProgram = "steelbore-beacon";
    platforms = lib.platforms.linux;
  };
}
