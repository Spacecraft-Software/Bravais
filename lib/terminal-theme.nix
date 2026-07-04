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

  at = builtins.elemAt;

  # Canonical ANSI slot names, shared by every named-color emitter.
  ansiNames = [ "black" "red" "green" "yellow" "blue" "magenta" "cyan" "white" ];

  konsoleColorschemeWith =
    withPaletteComment:
    let
      rt = p.convert.rgbTriple;
      slot = i: ''
        [Color${toString i}]
        Color=${rt (at theme.ansi.normal i)}

        [Color${toString i}Faint]
        Color=${rt (at theme.ansi.normal i)}

        [Color${toString i}Intense]
        Bold=true
        Color=${rt (at theme.ansi.bright i)}
      '';
      slots = builtins.concatStringsSep "\n" (builtins.genList slot 8);
    in
    ''
      # Steelbore Konsole Color Scheme
      ${
        if withPaletteComment then
          "# Palette: Void Navy / Molten Amber / Steel Blue / Radium Green / Red Oxide / Liquid Coolant
"
        else
          ""
      }
      [Background]
      Color=${rt theme.background}

      [BackgroundFaint]
      Color=${rt theme.background}

      [BackgroundIntense]
      Bold=true
      Color=${rt (at theme.ansi.bright 0)}

      ${slots}
      [Foreground]
      Color=${rt theme.foreground}

      [ForegroundFaint]
      Color=${rt theme.foreground}

      [ForegroundIntense]
      Bold=true
      Color=${rt theme.foreground}

      [General]
      Anchor=0.5,0.5
      Blur=false
      ColorRandomization=false
      Description=Steelbore
      FillStyle=Tile
      Opacity=${theme.opacity}
      Spread=1.0
      Wallpaper=
    '';
in
{
  inherit theme;

  # Flat 16-entry ANSI list (normal ++ bright) for list-shaped consumers
  # (Ptyxis dconf palette, etc.).
  ansi16 = theme.ansi.normal ++ theme.ansi.bright;

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
    { header, shell }:
    let
      c = i: at theme.ansi.normal i;
      cb = i: at theme.ansi.bright i;
    in
    ''
      # ${header}

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

  # ── Warp (YAML; full hex, single-quoted) ─────────────────────────────────
  warpYaml =
    let
      row = list: i: "    ${at ansiNames i}: '${at list i}'";
      rows = list: builtins.concatStringsSep "\n" (builtins.genList (row list) 8);
    in
    ''
      # Steelbore Theme for Warp Terminal
      accent: '${theme.selection.background}'
      background: '${theme.background}'
      foreground: '${theme.foreground}'
      details: darker
      terminal_colors:
        normal:
      ${rows theme.ansi.normal}
        bright:
      ${rows theme.ansi.bright}
    '';

  # ── Konsole colorscheme (INI; decimal R,G,B; Intense == bright) ─────────
  konsoleColorscheme = konsoleColorschemeWith true;
  konsoleColorschemePlain = konsoleColorschemeWith false;

  # ── Konsole profile (INI) ────────────────────────────────────────────────
  konsoleProfile =
    { shell }:
    ''
      # Steelbore Konsole Profile

      [Appearance]
      ColorScheme=Steelbore
      Font=${theme.font},12,-1,5,50,0,0,0,0,0

      [General]
      Command=${shell}
      Name=Steelbore
      Parent=FALLBACK/
      TerminalColumns=160
      TerminalRows=48

      [Scrolling]
      HistoryMode=2
      ScrollFullPage=false

      [Terminal Features]
      BlinkingCursorEnabled=true
    '';

  # ── WezTerm (Lua; full hex). ONE canonical body for both the /etc and the
  # user config — the old user copy had drifted (lost comments,
  # scrollbar_thumb/split, and three tab_bar states); unified deliberately
  # in the Phase C migration. ──────────────────────────────────────────────
  weztermLua =
    { header, shell }:
    let
      # First line bare (inherits the literal prefix of the interpolation
      # site); continuation lines carry the final rendered indent themselves.
      luaList =
        list:
        builtins.concatStringsSep ",\n" (
          builtins.genList (i: (if i == 0 then "" else "    ") + "\"${at list i}\"") 8
        );
    in
    ''
      -- ${header}
      local wezterm = require 'wezterm'
      local config = {}

      -- Font configuration
      config.font = wezterm.font '${theme.font}'
      config.font_size = 12.0

      -- Window configuration
      config.window_background_opacity = ${theme.opacity}
      config.window_padding = { left = 10, right = 10, top = 10, bottom = 10 }
      config.enable_tab_bar = true
      config.hide_tab_bar_if_only_one_tab = true
      config.default_prog = { "${shell}" }

      -- Steelbore color scheme
      config.colors = {
        foreground = "${theme.foreground}",
        background = "${theme.background}",
        cursor_bg = "${theme.cursor.cursor}",
        cursor_fg = "${theme.cursor.text}",
        cursor_border = "${theme.cursor.cursor}",
        selection_bg = "${theme.selection.background}",
        selection_fg = "${theme.selection.text}",
        scrollbar_thumb = "${theme.selection.background}",
        split = "${theme.selection.background}",

        ansi = {
          ${luaList theme.ansi.normal}
        },
        brights = {
          ${luaList theme.ansi.bright}
        },

        tab_bar = {
          background = "${theme.background}",
          active_tab = {
            bg_color = "${theme.selection.background}",
            fg_color = "${theme.foreground}",
          },
          inactive_tab = {
            bg_color = "${theme.background}",
            fg_color = "${theme.selection.background}",
          },
          inactive_tab_hover = {
            bg_color = "${theme.selection.background}",
            fg_color = "${theme.foreground}",
          },
          new_tab = {
            bg_color = "${theme.background}",
            fg_color = "${theme.selection.background}",
          },
          new_tab_hover = {
            bg_color = "${theme.selection.background}",
            fg_color = "${theme.foreground}",
          },
        },
      }

      return config
    '';

  # ── COSMIC Term (RON) ────────────────────────────────────────────────────
  cosmicTermScheme =
    let
      ronGroup =
        list:
        let
          names = ansiNames;
          # First line bare (inherits the interpolation site's literal
          # prefix after ''-dedent); continuations carry the rendered indent.
          row = i: (if i == 0 then "" else "            ") + "${at names i}: \"${at list i}\",";
        in
        builtins.concatStringsSep "\n" (builtins.genList row 8);
    in
    ''
      {
          1: (
              name: "Steelbore",
              foreground: "${theme.foreground}",
              background: "${theme.background}",
              cursor: "${theme.cursor.cursor}",
              bright_foreground: "${theme.foreground}",
              dim_foreground: "${theme.selection.background}",
              normal: (
                  ${ronGroup theme.ansi.normal}
              ),
              bright: (
                  ${ronGroup theme.ansi.bright}
              ),
              dim: (
                  ${ronGroup theme.ansi.normal}
              ),
          ),
      }
    '';

  # ── Waveterm (JSON attrset; render with builtins.toJSON) ────────────────
  wavetermConfig = {
    term = {
      fontfamily = theme.font;
      fontsize = 12;
      theme = "custom";
    };
    themes.custom = {
      display = {
        name = "Steelbore";
        order = 1;
      };
      terminal = {
        background = theme.background;
        foreground = theme.foreground;
        cursor = theme.cursor.cursor;
        selectionBackground = theme.selection.background;
        black = at theme.ansi.normal 0;
        red = at theme.ansi.normal 1;
        green = at theme.ansi.normal 2;
        yellow = at theme.ansi.normal 3;
        blue = at theme.ansi.normal 4;
        magenta = at theme.ansi.normal 5;
        cyan = at theme.ansi.normal 6;
        white = at theme.ansi.normal 7;
        brightBlack = at theme.ansi.bright 0;
        brightRed = at theme.ansi.bright 1;
        brightGreen = at theme.ansi.bright 2;
        brightYellow = at theme.ansi.bright 3;
        brightBlue = at theme.ansi.bright 4;
        brightMagenta = at theme.ansi.bright 5;
        brightCyan = at theme.ansi.bright 6;
        brightWhite = at theme.ansi.bright 7;
      };
    };
  };

  # ── Alacritty (HM settings attrset; named-color records) ────────────────
  alacrittyColors =
    let
      names = ansiNames;
      group = list: builtins.listToAttrs (builtins.genList (i: {
        name = at names i;
        value = at list i;
      }) 8);
    in
    {
      primary = {
        background = theme.background;
        foreground = theme.foreground;
      };
      cursor = {
        text = theme.cursor.text;
        cursor = theme.cursor.cursor;
      };
      selection = {
        text = theme.selection.text;
        background = theme.selection.background;
      };
      normal = group theme.ansi.normal;
      bright = group theme.ansi.bright;
    };

  # ── Rio (TOML; Mono font variant + Symbols fallback, constraint #11) ────
  rioToml =
    { shell }:
    let
      names = ansiNames;
      row = list: i: "${at names i} = '${at list i}'";
      rows = list: builtins.concatStringsSep "\n" (builtins.genList (row list) 8);
    in
    ''
      # Steelbore Rio User Configuration

      [window]
      opacity = ${theme.opacity}

      [fonts]
      size = 14

      [fonts.regular]
      family = "${theme.font} Mono"
      weight = 400

      [fonts.bold]
      family = "${theme.font} Mono"
      weight = 700

      [fonts.italic]
      family = "${theme.font} Mono"
      weight = 400

      [fonts.bold-italic]
      family = "${theme.font} Mono"
      weight = 700

      [[fonts.extras]]
      family = "Symbols Nerd Font"

      [[fonts.extras]]
      family = "Symbols Nerd Font Mono"

      [colors]
      background = '${theme.background}'
      foreground = '${theme.foreground}'
      cursor = '${theme.cursor.cursor}'
      selection-background = '${theme.selection.background}'
      selection-foreground = '${theme.selection.text}'

      [colors.regular]
      ${rows theme.ansi.normal}

      [colors.bright]
      ${rows theme.ansi.bright}

      [shell]
      program = "${shell}"
      args = []
    '';

  # ── Alacritty system TOML (/etc fallback; the HM copy uses
  # alacrittyColors attrs). vi_mode/search accents are Alacritty-specific
  # theme extensions, kept here with palette tokens. ───────────────────────
  alacrittyToml =
    { shell }:
    let
      group =
        list:
        builtins.concatStringsSep "\n" (
          builtins.genList (i: "${at ansiNames i} = \"${at list i}\"") 8
        );
    in
    ''
      # Steelbore Alacritty Configuration

      [window]
      padding = { x = 10, y = 10 }
      dynamic_title = true
      opacity = ${theme.opacity}
      decorations = "full"

      [font]
      normal = { family = "${theme.font}", style = "Regular" }
      bold = { family = "${theme.font}", style = "Bold" }
      italic = { family = "${theme.font}", style = "Italic" }
      size = 10.0

      [colors.primary]
      background = "${theme.background}"
      foreground = "${theme.foreground}"

      [colors.cursor]
      text = "${theme.cursor.text}"
      cursor = "${theme.cursor.cursor}"

      [colors.vi_mode_cursor]
      text = "${theme.cursor.text}"
      cursor = "${p.radiumGreen}"

      [colors.selection]
      text = "${theme.selection.text}"
      background = "${theme.selection.background}"

      [colors.search.matches]
      foreground = "${theme.cursor.text}"
      background = "${p.liquidCool}"

      [colors.search.focused_match]
      foreground = "${theme.cursor.text}"
      background = "${p.radiumGreen}"

      [colors.normal]
      ${group theme.ansi.normal}

      [colors.bright]
      ${group theme.ansi.bright}

      [terminal.shell]
      program = "${shell}"
    '';

  # ── XTerm attrset twin of `xresources` (HM xresources.properties) ──────
  xresourcesProps =
    let
      color = i: {
        name = "XTerm*color${toString i}";
        value = if i < 8 then at theme.ansi.normal i else at theme.ansi.bright (i - 8);
      };
    in
    {
      "XTerm*termName" = "xterm-256color";
      "XTerm*faceName" = theme.font;
      "XTerm*faceSize" = 12;
      "XTerm*loginShell" = true;
      "XTerm*scrollBar" = false;
      "XTerm*saveLines" = theme.scrollback;
      "XTerm*bellIsUrgent" = true;
      "XTerm*internalBorder" = 10;
      "XTerm*background" = theme.background;
      "XTerm*foreground" = theme.foreground;
      "XTerm*cursorColor" = theme.cursor.cursor;
      "XTerm*pointerColorBackground" = theme.background;
      "XTerm*pointerColorForeground" = theme.foreground;
      "XTerm*highlightColor" = theme.selection.background;
    }
    // builtins.listToAttrs (builtins.genList color 16);
}
