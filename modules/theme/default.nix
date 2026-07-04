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

  # TTY / Virtual Console Colors (Steelbore palette via convert.bareHex).
  # Brand mapping deliberately collapses colors: magenta==blue (steelBlue),
  # bright blue/magenta/cyan==liquidCool, white==moltenAmber — there is no
  # true magenta or white on the console (documented trade-off, plan §5.6).
  console.colors =
    let
      b = steelborePalette.convert.bareHex;
      p = steelborePalette;
    in
    [
      # Normal: Black Red Green Yellow Blue Magenta Cyan White
      (b p.voidNavy)
      (b p.redOxide)
      (b p.radiumGreen)
      (b p.moltenAmber)
      (b p.steelBlue)
      (b p.steelBlue)
      (b p.liquidCool)
      (b p.moltenAmber)
      # Bright: Black Red Green Yellow Blue Magenta Cyan White
      (b p.steelBlue)
      (b p.redOxide)
      (b p.radiumGreen)
      (b p.moltenAmber)
      (b p.liquidCool)
      (b p.liquidCool)
      (b p.liquidCool)
      (b p.moltenAmber)
    ];
}
