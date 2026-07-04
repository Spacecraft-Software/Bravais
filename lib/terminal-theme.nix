# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore terminal theme — single data record + per-format emitters.
#
# THE terminal theme exists once, here (elegance plan item 1.2). Every
# terminal emulator's config derives from this record through a small
# per-format emitter, so all ~15 terminals stay in lockstep by
# construction: a palette, font, opacity, or shell change is a one-file
# edit that propagates everywhere.
#
# Emitters reproduce the legacy hand-written configs byte-for-byte (the
# migration was gated on an unchanged system-toplevel store path), so
# formatting quirks below are deliberate.
#
# Usage:  tt = import ../../lib/terminal-theme.nix steelborePalette;
#         tt.theme            — the raw data record
#         tt.foot { … }       — render a foot.ini body
palette:

let
  p = palette;
  b = p.convert.bareHex;

  theme = {
    # 16-color ANSI mapping (brand-collapsed: magenta==steelBlue,
    # bright blue/magenta/cyan==liquidCool, white==moltenAmber — same
    # deliberate trade-off as the TTY console, plan §5.6).
    ansi = {
      normal = [
        p.voidNavy # black
        p.redOxide # red
        p.radiumGreen # green
        p.moltenAmber # yellow
        p.steelBlue # blue
        p.steelBlue # magenta
        p.liquidCool # cyan
        p.moltenAmber # white
      ];
      bright = [
        p.steelBlue # black
        p.redOxide # red
        p.radiumGreen # green
        p.moltenAmber # yellow
        p.liquidCool # blue
        p.liquidCool # magenta
        p.liquidCool # cyan
        p.moltenAmber # white
      ];
    };
    background = p.voidNavy;
    foreground = p.moltenAmber;
    cursor = {
      text = p.voidNavy;
      cursor = p.moltenAmber;
    };
    selection = {
      text = p.voidNavy;
      background = p.steelBlue;
    };
    font = "JetBrainsMono Nerd Font";
    opacity = "0.95";
    scrollback = 10000;
  };

  at = list: i: builtins.elemAt list i;
in
{
  inherit theme;

  # ── foot (INI; bare hex, no '#') ─────────────────────────────────────────
  # header: the leading comment line; shell: absolute path to the shell.
  foot =
    { header, shell }:
    let
      n = i: b (at theme.ansi.normal i);
      br = i: b (at theme.ansi.bright i);
    in
    ''
      # ${header}

      [main]
      font=${theme.font}:size=12
      shell=${shell}
      term=xterm-256color

      [colors]
      background=${b theme.background}
      foreground=${b theme.foreground}
      regular0=${n 0}
      regular1=${n 1}
      regular2=${n 2}
      regular3=${n 3}
      regular4=${n 4}
      regular5=${n 5}
      regular6=${n 6}
      regular7=${n 7}
      bright0=${br 0}
      bright1=${br 1}
      bright2=${br 2}
      bright3=${br 3}
      bright4=${br 4}
      bright5=${br 5}
      bright6=${br 6}
      bright7=${br 7}
      cursor=${b theme.cursor.text} ${b theme.cursor.cursor}
      selection-foreground=${b theme.selection.text}
      selection-background=${b theme.selection.background}

      [scrollback]
      lines=${toString theme.scrollback}
    '';

  # ── XTerm (Xresources; full hex) ─────────────────────────────────────────
  xresources =
    let
      c = i: at theme.ansi.normal i;
      cb = i: at theme.ansi.bright i;
    in
    ''
      ! Steelbore XTerm Configuration

      XTerm*termName:              xterm-256color
      XTerm*faceName:              ${theme.font}
      XTerm*faceSize:              12
      XTerm*loginShell:            true
      XTerm*scrollBar:             false
      XTerm*saveLines:             ${toString theme.scrollback}
      XTerm*bellIsUrgent:          true
      XTerm*internalBorder:        10

      XTerm*background:            ${theme.background}
      XTerm*foreground:            ${theme.foreground}
      XTerm*cursorColor:           ${theme.cursor.cursor}
      XTerm*pointerColorBackground:${theme.background}
      XTerm*pointerColorForeground:${theme.foreground}
      XTerm*highlightColor:        ${theme.selection.background}

      XTerm*color0:                ${c 0}
      XTerm*color1:                ${c 1}
      XTerm*color2:                ${c 2}
      XTerm*color3:                ${c 3}
      XTerm*color4:                ${c 4}
      XTerm*color5:                ${c 5}
      XTerm*color6:                ${c 6}
      XTerm*color7:                ${c 7}
      XTerm*color8:                ${cb 0}
      XTerm*color9:                ${cb 1}
      XTerm*color10:               ${cb 2}
      XTerm*color11:               ${cb 3}
      XTerm*color12:               ${cb 4}
      XTerm*color13:               ${cb 5}
      XTerm*color14:               ${cb 6}
      XTerm*color15:               ${cb 7}
    '';

  # ── Xfce Terminal (INI; full hex; 16-color semicolon palette) ────────────
  xfce =
    { shell }:
    let
      pal = builtins.concatStringsSep ";" (theme.ansi.normal ++ theme.ansi.bright);
    in
    ''
      [Configuration]
      FontName=${theme.font} 12
      MiscDefaultGeometry=160x48
      RunCustomCommand=TRUE
      CustomCommand=${shell}
      BackgroundMode=TERMINAL_BACKGROUND_TRANSPARENT
      BackgroundDarkness=${theme.opacity}
      ColorBackground=${theme.background}
      ColorForeground=${theme.foreground}
      ColorCursor=${theme.cursor.cursor}
      ColorBold=FALSE
      ColorPalette=${pal}
      MiscMenubarDefault=FALSE
      ScrollingBar=TERMINAL_SCROLLBAR_NONE
      ScrollingLines=${toString theme.scrollback}
    '';

  # ── Ghostty (key-value; full hex) ────────────────────────────────────────
  ghostty =
    { shell }:
    let
      c = i: at theme.ansi.normal i;
      cb = i: at theme.ansi.bright i;
    in
    ''
      # Steelbore Ghostty Configuration

      font-family = ${theme.font}
      font-size = 12

      background-opacity = ${theme.opacity}
      window-padding-x = 10
      window-padding-y = 10

      # Steelbore color palette
      background = ${theme.background}
      foreground = ${theme.foreground}
      cursor-color = ${theme.cursor.cursor}
      cursor-text = ${theme.cursor.text}
      selection-background = ${theme.selection.background}
      selection-foreground = ${theme.selection.text}

      # Normal colors (0-7)
      palette = 0=${c 0}
      palette = 1=${c 1}
      palette = 2=${c 2}
      palette = 3=${c 3}
      palette = 4=${c 4}
      palette = 5=${c 5}
      palette = 6=${c 6}
      palette = 7=${c 7}

      # Bright colors (8-15)
      palette = 8=${cb 0}
      palette = 9=${cb 1}
      palette = 10=${cb 2}
      palette = 11=${cb 3}
      palette = 12=${cb 4}
      palette = 13=${cb 5}
      palette = 14=${cb 6}
      palette = 15=${cb 7}

      # Shell — launches Nushell
      command = ${shell}
    '';
}
