# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Theme Module Entry Point
{
  steelborePalette,
  ...
}:

{
  imports = [
    ./fonts.nix
    ./dark-mode.nix
  ];

  # Environment variables for theme-aware applications
  environment.variables = {
    SPACECRAFT_BACKGROUND = steelborePalette.background;
    SPACECRAFT_TEXT = steelborePalette.foreground;
    SPACECRAFT_ACCENT = steelborePalette.accent;
    SPACECRAFT_SUCCESS = steelborePalette.success;
    SPACECRAFT_WARNING = steelborePalette.error;
    SPACECRAFT_INFO = steelborePalette.info;
  };

  # TTY / Virtual Console Colors — the 16-color ANSI mapping is single-sourced
  # in lib/palette.nix and shared with every terminal emulator via
  # lib/terminal-theme.nix. This file used to carry a second copy of the same
  # table, which had to be kept in step by hand.
  console.colors =
    let
      b = steelborePalette.convert.bareHex;
      a = steelborePalette.ansi;
    in
    map b (a.normal ++ a.bright);
}
