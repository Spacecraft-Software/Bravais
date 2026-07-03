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
    SPACECRAFT_BACKGROUND = steelborePalette.voidNavy;
    SPACECRAFT_TEXT = steelborePalette.moltenAmber;
    SPACECRAFT_ACCENT = steelborePalette.steelBlue;
    SPACECRAFT_SUCCESS = steelborePalette.radiumGreen;
    SPACECRAFT_WARNING = steelborePalette.redOxide;
    SPACECRAFT_INFO = steelborePalette.liquidCool;
  };

  # TTY / Virtual Console Colors (Steelbore Palette)
  console.colors = [
    # Normal: Black Red Green Yellow Blue Magenta Cyan White
    "000027"
    "FF5C5C"
    "50FA7B"
    "D98E32"
    "4B7EB0"
    "4B7EB0"
    "8BE9FD"
    "D98E32"
    # Bright: Black Red Green Yellow Blue Magenta Cyan White
    "4B7EB0"
    "FF5C5C"
    "50FA7B"
    "D98E32"
    "8BE9FD"
    "8BE9FD"
    "8BE9FD"
    "D98E32"
  ];
}
