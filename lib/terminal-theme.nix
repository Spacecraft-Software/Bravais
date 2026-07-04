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
}
