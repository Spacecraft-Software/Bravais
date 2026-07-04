# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore color palette — the single canonical source (Standard §11).
# Imported by flake.nix as `steelborePalette` and threaded to every module
# and Home Manager via specialArgs / extraSpecialArgs.
#
# Besides the six hex tokens, this file exports `convert`, a tiny color
# library so no consumer ever restates a palette value in another notation
# (Konsole R,G,B triples, COSMIC sRGBA floats, bare hex, xterm-256 indices).
# Every converter is pure integer math on the hex string — palette edits
# propagate everywhere by construction.
let
  hexDigit = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
    "A" = 10;
    "B" = 11;
    "C" = 12;
    "D" = 13;
    "E" = 14;
    "F" = 15;
  };

  # "#RRGGBB" -> { r; g; b; } as 0–255 integers.
  channels =
    hex:
    let
      at = i: hexDigit.${builtins.substring i 1 hex};
    in
    {
      r = (at 1) * 16 + at 2;
      g = (at 3) * 16 + at 4;
      b = (at 5) * 16 + at 6;
    };

  # 0–255 -> sRGBA float string exactly as cosmic-settings writes it:
  # "0.0" and "1.0" for the endpoints, otherwise 8 decimals (zero-padded),
  # round-half-up. NOTE: a value whose 8-decimal form ends in trailing
  # zeros would render padded (e.g. "0.50000000"); no palette value does.
  floatChannel =
    v:
    if v == 0 then
      "0.0"
    else if v == 255 then
      "1.0"
    else
      let
        # round(v * 1e8 / 255) via integer round-half-up
        scaled = (v * 200000000 + 255) / 510;
        pad = s: if builtins.stringLength s >= 8 then s else pad ("0" + s);
      in
      "0.${pad (toString scaled)}";
in
{
  voidNavy = "#000027";
  moltenAmber = "#D98E32";
  steelBlue = "#4B7EB0";
  radiumGreen = "#50FA7B";
  redOxide = "#FF5C5C";
  liquidCool = "#8BE9FD";

  convert = {
    # "#000027" -> "000027" (Foot INI, TTY colors, awww clear, …)
    bareHex = hex: builtins.substring 1 (builtins.stringLength hex - 1) hex;

    # "#000027" -> "0,0,39" (Konsole colorscheme INI)
    rgbTriple =
      hex:
      let
        c = channels hex;
      in
      "${toString c.r},${toString c.g},${toString c.b}";

    # "#000027" -> "(red: 0.0, green: 0.0, blue: 0.15294118)"
    # (COSMIC theme Builder RON; matches cosmic-settings' own formatting)
    srgbaFloat =
      hex:
      let
        c = channels hex;
      in
      "(red: ${floatChannel c.r}, green: ${floatChannel c.g}, blue: ${floatChannel c.b})";

    # Individual sRGBA float channels, for multi-line RON bodies.
    srgbaChannels =
      hex:
      let
        c = channels hex;
      in
      {
        red = floatChannel c.r;
        green = floatChannel c.g;
        blue = floatChannel c.b;
      };

    # Hand-curated xterm-256 index per palette token (hue-preserving picks,
    # not strict nearest-distance — voidNavy uses 17, not 16, to keep the
    # navy cast). Used by 256-color-only consumers like the tiny IRC client.
    x256 = {
      voidNavy = 17;
      moltenAmber = 172;
      steelBlue = 67;
      radiumGreen = 84;
      redOxide = 203;
      liquidCool = 123;
    };
  };
}
