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
  localThemes ? { },
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

  registered = builtins.filter (t: builtins.hasAttr t themes) (
    family ++ (map (s: "${s}-high-contrast") family)
  );
  localNames = builtins.attrNames localThemes;
  selectable = localNames ++ (builtins.filter (s: !builtins.elem s localNames) registered);

  # ---------------------------------------------------------------------
  # Local themes (./themes/<slug>.nix).
  # ---------------------------------------------------------------------
  # A local theme either derives from a registered palette (`base`) or binds
  # its roles outright. Either way it resolves through the same path as a
  # registered palette below, so it inherits role completion, the hue-derived
  # ANSI map and xterm-256 handling for free.
  #
  # These checks exist because the failure mode without them is awful: a
  # typo'd role name is silently ignored (the theme just does not apply), and
  # a malformed hex surfaces as an "attribute 'F' missing" deep inside the
  # channel converter, naming neither the file nor the token.
  roleNames = [
    "background"
    "surface"
    "surface-alt"
    "surfaceAlt"
    "foreground"
    "accent"
    "structure"
    "success"
    "error"
    "warning"
    "info"
    "focus"
    "border"
  ];
  requiredRoles = [
    "background"
    "foreground"
    "accent"
    "success"
    "error"
  ];

  isHex =
    v:
    builtins.isString v
    && builtins.stringLength v == 7
    && builtins.substring 0 1 v == "#"
    && builtins.all (c: hexDigit ? ${c}) (builtins.genList (i: builtins.substring (i + 1) 1 v) 6);

  # `base` resolves against the REGISTERED set only. A local theme deriving
  # from another local theme would need cycle detection to be safe, and buys
  # nothing a second `base` line cannot express.
  baseTheme =
    name: s:
    if builtins.elem s registered then
      themes.${s}
    else
      throw ''
        Steelbore palette: themes/${name}.nix has `base = "${s}"`, which is not a
        registered palette. Pick one of: ${builtins.concatStringsSep ", " registered}
      '';

  resolveLocal =
    name: def:
    let
      inherited = if def ? base then baseTheme name def.base else { };
      raw = builtins.removeAttrs def [ "base" ];

      badKeys = builtins.filter (k: !builtins.elem k roleNames) (builtins.attrNames raw);
      badHex = builtins.filter (k: !isHex raw.${k}) (builtins.attrNames raw);

      # The TOML spells it `surface-alt`; accept the camelCase form consumers
      # see and normalise, so it cannot be set-but-silently-ignored.
      given =
        if raw ? surfaceAlt then
          (builtins.removeAttrs raw [ "surfaceAlt" ]) // { "surface-alt" = raw.surfaceAlt; }
        else
          raw;

      merged = inherited // given;
      missing = builtins.filter (r: !merged ? ${r}) requiredRoles;
    in
    if badKeys != [ ] then
      throw ''
        Steelbore palette: themes/${name}.nix sets unknown role(s): ${builtins.concatStringsSep ", " badKeys}
        Valid roles: ${builtins.concatStringsSep ", " roleNames}
      ''
    else if badHex != [ ] then
      throw ''
        Steelbore palette: themes/${name}.nix has malformed color(s) for ${builtins.concatStringsSep ", " badHex}
        Each must be a "#RRGGBB" string — a leading '#' and exactly six hex digits.
      ''
    else if missing != [ ] then
      throw ''
        Steelbore palette: themes/${name}.nix is missing required role(s): ${builtins.concatStringsSep ", " missing}
        A theme without `base` must bind all of: ${builtins.concatStringsSep ", " requiredRoles}
        Add `base = "steelbore";` to inherit them from a registered palette instead.
      ''
    else
      merged;

  theme =
    if localThemes ? ${slug} then
      resolveLocal slug localThemes.${slug}
    else if builtins.elem baseSlug fidelity then
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
        Local themes live in ./themes/<slug>.nix.
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
  grayIdx =
    v:
    if v < 8 then
      0
    else if v > 238 then
      23
    else
      (v - 8 + 5) / 10;
  grayVal = i: 8 + 10 * i;

  sq = n: n * n;
  max2 = a: b: if a > b then a else b;
  min2 = a: b: if a < b then a else b;
  abs = n: if n < 0 then -n else n;

  # ---------------------------------------------------------------------
  # Hue, for the 16-color ANSI mapping.
  # ---------------------------------------------------------------------
  # ANSI slots are named by HUE ("red", "cyan"); role tokens are named by
  # FUNCTION ("error", "structure"). The two do not correspond: Classic's
  # `accent` is Steel Blue, Modern's is Plasma Orange, so any fixed
  # role -> slot table is hue-correct for exactly one palette and wrong for
  # the rest. Assigning by measured hue instead keeps every palette's
  # terminal honest, which is the whole point of a switchable family.
  #
  # `chroma` doubles as the achromatic guard — a near-gray token has no
  # meaningful hue and must never win a color slot.
  chromaOf =
    hex:
    let
      c = channels hex;
    in
    max2 c.r (max2 c.g c.b) - min2 c.r (min2 c.g c.b);

  hueOf =
    hex:
    let
      c = channels hex;
      mx = max2 c.r (max2 c.g c.b);
      d = chromaOf hex;
      h =
        if mx == c.r then
          (60 * (c.g - c.b)) / d
        else if mx == c.g then
          120 + (60 * (c.b - c.r)) / d
        else
          240 + (60 * (c.r - c.g)) / d;
    in
    if h < 0 then h + 360 else h;

  hueDist =
    a: b:
    let
      x = abs (a - b);
    in
    min2 x (360 - x);

  # `red` and `green` are not hue decisions — every terminal in existence
  # reads them as error and success, and a status color that disagrees with
  # its slot is worse than one that is a few degrees off. They are pinned;
  # only the remaining four slots are matched by hue, over the tokens those
  # two did not take.
  #
  # `foreground` is a candidate because in some palettes it carries the
  # brand hue (Classic's Molten Amber is the yellow slot). The chroma floor
  # drops it where it is a near-neutral that would win a color slot on a
  # technicality — Modern's Platinum Mist (chroma 12) and Tokyo Night's
  # #C0CAF5 (53), the latter of which otherwise out-competes the actual
  # blue accent for the blue slot by eleven degrees.
  #
  # Roles that fell back onto `error` or `success` (Classic binds no
  # `warning`, so it resolves to `error`) are dropped too: those hexes are
  # already spoken for by the pinned slots, and letting them back in is how
  # `yellow` ends up identical to `green`.
  hueCandidates = builtins.filter (hex: chromaOf hex >= 80 && hex != error && hex != success) [
    accent
    structure
    warning
    info
    focus
    foreground
  ];

  # Nearest candidate to a canonical ANSI hue; falls back to `foreground`
  # only if the palette is entirely achromatic.
  nearestHue =
    target:
    if hueCandidates == [ ] then
      foreground
    else
      builtins.head (
        builtins.sort (a: b: hueDist (hueOf a) target < hueDist (hueOf b) target) hueCandidates
      );

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

  # ---------------------------------------------------------------------
  # §11.6.2 — canvas polarity and the light/dark counterpart.
  # ---------------------------------------------------------------------
  # steelbore.toml carries [resolution.*] from v3.2.0 (Standard v1.45). The
  # `construct` flake input is PINNED, so this has to keep working before
  # `nix flake update construct` lands that version — otherwise a Bravais
  # rebuild breaks in the window between the two merges. Where the table is
  # absent, polarity is derived from the canvas and the counterpart falls back
  # to the family defaults §11.6.2 states.
  hasResolution = data ? resolution;

  # Rec. 601 luma on the raw channels, integer math like every other converter
  # in this file. This is a light/dark CLASSIFICATION, not a contrast ratio —
  # no WCAG number is being claimed here. Every registered canvas sits nowhere
  # near the boundary (Void Navy 4, Pearl Silver 229), so the cheap form agrees
  # with the exact relative-luminance answer for all nine, and Nix has no `pow`
  # to compute the exact one with anyway.
  lumaOf =
    hex:
    let
      c = channels hex;
    in
    (299 * c.r + 587 * c.g + 114 * c.b) / 1000;
  polarityOfHex = hex: if lumaOf hex > 127 then "light" else "dark";

  darkDefault =
    if data.meta ? "default-dark-theme" then data.meta."default-dark-theme" else "steelbore";
  lightDefault =
    if data.meta ? "default-light-theme" then
      data.meta."default-light-theme"
    else
      "steelbore-navywhite";

  # Base palettes only — a high-contrast sibling shares its base's canvas, and
  # steelbore-mono binds ANSI names ("default", "bright-white") rather than hex,
  # so `channels` must never be handed it.
  polarityTable =
    if hasResolution then
      data.resolution.polarity
    else
      builtins.listToAttrs (
        map (s: {
          name = s;
          value = polarityOfHex themes.${s}.background;
        }) (family ++ fidelity)
      );

  pairTable =
    if hasResolution then
      data.resolution.pair
    else
      builtins.mapAttrs (_: pol: if pol == "light" then darkDefault else lightDefault) polarityTable;
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
    # §11.6.2. Derived from the resolved canvas rather than looked up, so a
    # local theme in ./themes/ gets a correct answer for free.
    polarity = polarityOfHex background;
    # The counterpart in the other polarity. A local theme with no registered
    # entry falls back on its own polarity.
    pair =
      if pairTable ? ${baseSlug} then
        pairTable.${baseSlug}
      else if polarityOfHex background == "light" then
        darkDefault
      else
        lightDefault;
  };

  # §11.6 resolution contract, for the modules that render the system
  # declaration (modules/theme/declaration.nix) and the theme registry
  # (flake.nix). Slugs and paths only — never a color value, because an OS
  # declares WHICH theme and never supplies the hex (§11.6.4).
  resolution = {
    envVar = if hasResolution then data.resolution."env-var" else "SPACECRAFT_THEME";
    systemFile = if hasResolution then data.resolution."system-file" else "/etc/steelbore/theme.toml";
    userFile =
      if hasResolution then data.resolution."user-file" else "$XDG_CONFIG_HOME/steelbore/theme.toml";
    registry = if hasResolution then data.resolution.registry else "/etc/steelbore/themes.json";
    polarity = polarityTable;
    pair = pairTable;
    inherit darkDefault lightDefault;
    # True once the construct input carries steelbore.toml >= 3.2.0. Useful in
    # an assertion if a consumer ever needs the real table rather than a
    # derived one.
    fromCanonicalFile = hasResolution;
  };

  # 16-color ANSI mapping, single-sourced here and consumed by both the
  # terminal theme (lib/terminal-theme.nix) and the TTY console
  # (modules/theme/default.nix), which used to carry duplicate copies.
  #
  # Each color slot goes to whichever role token sits nearest its canonical
  # hue, so the mapping stays honest under every palette instead of being
  # tuned to one. Slots may still collide where a palette genuinely has no
  # such hue — Modern has no cyan — but nothing is collapsed by hand.
  ansi = {
    normal = [
      background # black
      error # red
      success # green
      (nearestHue 60) # yellow
      (nearestHue 240) # blue
      (nearestHue 300) # magenta
      (nearestHue 180) # cyan
      foreground # white
    ];
    # Bright black is the conventional "dim text" slot (comments, inactive
    # UI), so it must stay legible: `structure` is 5.51:1 on Modern's canvas.
    # Not `surface`, tempting as an elevated dark is here — §11.0.1 forbids
    # surface tokens as text colors outright (Quantum Blue is 1.40:1), and
    # every ANSI slot is a text color.
    bright = [
      structure # black
      error # red
      success # green
      (nearestHue 60) # yellow
      (nearestHue 240) # blue
      (nearestHue 300) # magenta
      (nearestHue 180) # cyan
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
