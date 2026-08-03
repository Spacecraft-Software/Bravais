# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore palette family — the single canonical source (Standard §11).
#
# Standard v1.35 turned §11 from one palette into a family. This file selects
# one member by slug and resolves it to a complete role record, so no consumer
# ever names a brand color: §11.1 requires palette references to go through
# ROLE tokens (`foreground`, `accent`, …) precisely so the palette can be
# swapped without touching the ~430 sites that consume it.
#
# Values are READ, never retyped (§11.4) — straight out of the canonical
# `steelbore.toml` shipped by the `construct` flake input, so a palette fix
# upstream arrives with `nix flake update construct`.
#
# Imported by flake.nix as `steelborePalette` and threaded to every module and
# Home Manager via specialArgs / extraSpecialArgs.
#
# Usage:  import ./lib/palette.nix {
#           tomlFile = "${construct}/steelbore-color-palette/assets/steelbore.toml";
#           slug     = "steelbore";
#         }
#
# Only builtins are used — this is imported before nixpkgs' `lib` exists.
{
  tomlFile,
  slug ? "steelbore",
}:

let
  data = builtins.fromTOML (builtins.readFile tomlFile);
  themes = data.themes;
  family = data.meta."palette-family";
  fidelity = data.meta."fidelity-palettes";

  # ---------------------------------------------------------------------
  # Slug validation — fail at eval time with a message that names the fix.
  # ---------------------------------------------------------------------
  # A high-contrast sibling (§11.1.1) is selectable: each one binds a full
  # role set, so it resolves like any other member.
  baseSlug =
    let
      n = builtins.stringLength slug;
      suffix = "-high-contrast";
      sn = builtins.stringLength suffix;
    in
    if n > sn && builtins.substring (n - sn) sn slug == suffix then
      builtins.substring 0 (n - sn) slug
    else
      slug;

  selectable = builtins.filter (t: builtins.hasAttr t themes) (
    family ++ (map (s: "${s}-high-contrast") family)
  );

  theme =
    if builtins.elem baseSlug fidelity then
      throw ''
        Steelbore palette: "${slug}" is a §11.5 fidelity palette — registered for
        reference, explicitly NOT adoptable. Pick one of: ${builtins.concatStringsSep ", " family}
      ''
    else if slug == "steelbore-mono" then
      throw ''
        Steelbore palette: "steelbore-mono" binds 4-bit ANSI names ("bright-white",
        "reverse-video"), not hex, and exists so a terminal app can defer to the
        user's own palette. It cannot drive a system theme. Use NO_COLOR instead.
      ''
    else if !builtins.elem baseSlug family then
      throw ''
        Steelbore palette: unknown slug "${slug}". Selectable: ${builtins.concatStringsSep ", " selectable}
      ''
    else
      themes.${slug};

  # ---------------------------------------------------------------------
  # Role completion (§11.1).
  # ---------------------------------------------------------------------
  # Palettes bind different role sets — Modern and the alternates bind all
  # eleven, Classic keeps its legacy six (§11.2) and defines no surface class.
  # Every consumer-visible role resolves here so no consumer needs to know
  # which palette is active. `info` is Classic-only and lands on `structure`
  # elsewhere; `structure` is the links/borders role and the closest semantic
  # match to an informational accent.
  at = name: fallback: if theme ? ${name} then theme.${name} else fallback;

  background = theme.background;
  foreground = theme.foreground;
  accent = theme.accent;
  success = theme.success;
  error = theme.error;

  surface = at "surface" background;
  surfaceAlt = at "surface-alt" surface;
  structure = at "structure" accent;
  info = at "info" structure;
  warning = at "warning" error;
  focus = at "focus" success;
  border = at "border" structure;

  # ---------------------------------------------------------------------
  # Color notation converters (unchanged — pure, palette-independent).
  # ---------------------------------------------------------------------
  # No consumer ever restates a value in another notation (Konsole R,G,B
  # triples, COSMIC sRGBA floats, bare hex, xterm-256 indices). Every
  # converter is pure integer math on the hex string.
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
      at' = i: hexDigit.${builtins.substring i 1 hex};
    in
    {
      r = (at' 1) * 16 + at' 2;
      g = (at' 3) * 16 + at' 4;
      b = (at' 5) * 16 + at' 6;
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

  # ---------------------------------------------------------------------
  # xterm-256 index, computed from the hex.
  # ---------------------------------------------------------------------
  # Classic's six indices were hand-curated to preserve hue rather than
  # minimise distance (Void Navy is 17, not the nearest 16, to keep the navy
  # cast). Those picks are kept as an explicit by-hex override so the
  # documented intent survives; every other color is derived, since a
  # switchable family cannot carry a hand table per palette.
  curatedX256 = {
    "#000027" = 17; # Void Navy      — 17 over 16, keeps the navy cast
    "#D98E32" = 172; # Molten Amber
    "#4B7EB0" = 67; # Steel Blue
    "#50FA7B" = 84; # Radium Green
    "#FF5C5C" = 203; # Red Oxide
    "#8BE9FD" = 123; # Liquid Coolant
  };

  # The 6×6×6 cube (indices 16–231) samples each channel at these levels;
  # the thresholds below are the midpoints between adjacent levels.
  cubeLevels = [
    0
    95
    135
    175
    215
    255
  ];
  cubeIdx =
    v:
    if v < 48 then
      0
    else if v < 115 then
      1
    else if v < 155 then
      2
    else if v < 195 then
      3
    else if v < 235 then
      4
    else
      5;
  cubeVal = i: builtins.elemAt cubeLevels i;

  # The grayscale ramp (232–255) runs 8, 18, … 238 in steps of 10.
  grayIdx = v: if v < 8 then 0 else if v > 238 then 23 else (v - 8 + 5) / 10;
  grayVal = i: 8 + 10 * i;

  sq = n: n * n;

  x256Of =
    hex:
    if curatedX256 ? ${hex} then
      curatedX256.${hex}
    else
      let
        c = channels hex;
        ri = cubeIdx c.r;
        gi = cubeIdx c.g;
        bi = cubeIdx c.b;
        cubeDist = sq (c.r - cubeVal ri) + sq (c.g - cubeVal gi) + sq (c.b - cubeVal bi);
        # A gray candidate only makes sense as a single level for all three.
        avg = (c.r + c.g + c.b) / 3;
        gidx = grayIdx avg;
        gv = grayVal gidx;
        grayDist = sq (c.r - gv) + sq (c.g - gv) + sq (c.b - gv);
      in
      if grayDist < cubeDist then 232 + gidx else 16 + 36 * ri + 6 * gi + bi;
in
{
  # The active palette, as §11.1 role tokens. This is the whole contract —
  # consumers name roles, never brand colors, so the palette is swappable.
  inherit
    background
    surface
    surfaceAlt
    foreground
    accent
    structure
    success
    error
    warning
    info
    focus
    border
    ;

  # Which member is active, for docs, assertions and generated headers.
  meta = {
    inherit slug;
    inherit (data.meta) version;
    family = selectable;
    # Classic defines no surface class (§11.0.1 does not apply to it), so a
    # consumer that wants a genuinely distinct panel fill can test this.
    hasSurfaceClass = theme ? "surface";
  };

  # 16-color ANSI mapping, single-sourced here and consumed by both the
  # terminal theme (lib/terminal-theme.nix) and the TTY console
  # (modules/theme/default.nix), which used to carry duplicate copies.
  #
  # Brand-collapsed: magenta repeats blue and the bright row folds
  # blue/magenta/cyan onto one color — a six-token palette has no distinct
  # hue for them. Palettes that bind the full eleven roles do; see M4.
  ansi = {
    normal = [
      background # black
      error # red
      success # green
      foreground # yellow
      accent # blue
      accent # magenta
      info # cyan
      foreground # white
    ];
    bright = [
      accent # black
      error # red
      success # green
      foreground # yellow
      info # blue
      info # magenta
      info # cyan
      foreground # white
    ];
  };

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

    # Per-role xterm-256 indices, for 256-color-only consumers (tiny IRC).
    x256 = {
      background = x256Of background;
      surface = x256Of surface;
      surfaceAlt = x256Of surfaceAlt;
      foreground = x256Of foreground;
      accent = x256Of accent;
      structure = x256Of structure;
      success = x256Of success;
      error = x256Of error;
      warning = x256Of warning;
      info = x256Of info;
      focus = x256Of focus;
      border = x256Of border;
    };

    # Escape hatch for a computed color that is not a role token.
    inherit x256Of;
  };
}
