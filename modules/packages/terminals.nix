# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Terminal Emulators (All with Steelbore Theme)
{ config, lib, pkgs, steelborePalette, ... }:

let
  # Foot requires hex colors without the '#' prefix
  h = c: builtins.substring 1 (builtins.stringLength c - 1) c;
in

{
  options.steelbore.packages.terminals = {
    enable = lib.mkEnableOption "Terminal emulators";
  };

  config = lib.mkIf config.steelbore.packages.terminals.enable {
    environment.systemPackages = with pkgs; [
      # Rust-based (preferred)
      alacritty
      wezterm
      rio
      ghostty                    # Zig, but memory-safe

      # Other terminals
      ptyxis                     # GNOME terminal (VTE-based)
      waveterm                   # AI-native terminal
      warp-terminal              # AI-powered terminal
      termius                    # SSH client
      cosmic-term                # COSMIC terminal

      # KDE terminals
      kdePackages.konsole        # KDE terminal emulator
      kdePackages.yakuake        # KDE drop-down terminal

      # GNOME terminals
      gnome-console              # GNOME Console (kgx)

      # Wayland/X11 terminals
      foot                       # Wayland terminal (C, lightweight)
      xterm                      # Classic X11 terminal

      # XFCE terminal — top-level on unstable, under `xfce.` on stable.
      # `or`-fallback evaluates clean on both channels.
      (pkgs.xfce4-terminal or pkgs.xfce.xfce4-terminal)
    ];

    # ═══════════════════════════════════════════════════════════════════════════
    # ALACRITTY — Rust-based GPU-accelerated terminal
    # ═══════════════════════════════════════════════════════════════════════════
    environment.etc."alacritty/alacritty.toml".text = ''
      # Steelbore Alacritty Configuration

      [window]
      padding = { x = 10, y = 10 }
      dynamic_title = true
      opacity = 0.95
      decorations = "full"

      [font]
      normal = { family = "Inconsolata Nerd Font", style = "Regular" }
      bold = { family = "Inconsolata Nerd Font", style = "Bold" }
      italic = { family = "Inconsolata Nerd Font", style = "Italic" }
      size = 10.0

      [colors.primary]
      background = "${steelborePalette.voidNavy}"
      foreground = "${steelborePalette.moltenAmber}"

      [colors.cursor]
      text = "${steelborePalette.voidNavy}"
      cursor = "${steelborePalette.moltenAmber}"

      [colors.vi_mode_cursor]
      text = "${steelborePalette.voidNavy}"
      cursor = "${steelborePalette.radiumGreen}"

      [colors.selection]
      text = "${steelborePalette.voidNavy}"
      background = "${steelborePalette.steelBlue}"

      [colors.search.matches]
      foreground = "${steelborePalette.voidNavy}"
      background = "${steelborePalette.liquidCool}"

      [colors.search.focused_match]
      foreground = "${steelborePalette.voidNavy}"
      background = "${steelborePalette.radiumGreen}"

      [colors.normal]
      black = "${steelborePalette.voidNavy}"
      red = "${steelborePalette.redOxide}"
      green = "${steelborePalette.radiumGreen}"
      yellow = "${steelborePalette.moltenAmber}"
      blue = "${steelborePalette.steelBlue}"
      magenta = "${steelborePalette.steelBlue}"
      cyan = "${steelborePalette.liquidCool}"
      white = "${steelborePalette.moltenAmber}"

      [colors.bright]
      black = "${steelborePalette.steelBlue}"
      red = "${steelborePalette.redOxide}"
      green = "${steelborePalette.radiumGreen}"
      yellow = "${steelborePalette.moltenAmber}"
      blue = "${steelborePalette.liquidCool}"
      magenta = "${steelborePalette.liquidCool}"
      cyan = "${steelborePalette.liquidCool}"
      white = "${steelborePalette.moltenAmber}"

      [terminal.shell]
      program = "${pkgs.nushell}/bin/nu"
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # WEZTERM — Rust-based GPU-accelerated terminal with Lua config
    # ═══════════════════════════════════════════════════════════════════════════
    environment.etc."wezterm/wezterm.lua".text = ''
      -- Steelbore WezTerm Configuration
      local wezterm = require 'wezterm'
      local config = {}

      -- Font configuration
      config.font = wezterm.font 'Inconsolata Nerd Font'
      config.font_size = 12.0

      -- Window configuration
      config.window_background_opacity = 0.95
      config.window_padding = { left = 10, right = 10, top = 10, bottom = 10 }
      config.enable_tab_bar = true
      config.hide_tab_bar_if_only_one_tab = true
      config.default_prog = { "${pkgs.nushell}/bin/nu" }

      -- Steelbore color scheme
      config.colors = {
        foreground = "${steelborePalette.moltenAmber}",
        background = "${steelborePalette.voidNavy}",
        cursor_bg = "${steelborePalette.moltenAmber}",
        cursor_fg = "${steelborePalette.voidNavy}",
        cursor_border = "${steelborePalette.moltenAmber}",
        selection_bg = "${steelborePalette.steelBlue}",
        selection_fg = "${steelborePalette.voidNavy}",
        scrollbar_thumb = "${steelborePalette.steelBlue}",
        split = "${steelborePalette.steelBlue}",

        ansi = {
          "${steelborePalette.voidNavy}",
          "${steelborePalette.redOxide}",
          "${steelborePalette.radiumGreen}",
          "${steelborePalette.moltenAmber}",
          "${steelborePalette.steelBlue}",
          "${steelborePalette.steelBlue}",
          "${steelborePalette.liquidCool}",
          "${steelborePalette.moltenAmber}"
        },
        brights = {
          "${steelborePalette.steelBlue}",
          "${steelborePalette.redOxide}",
          "${steelborePalette.radiumGreen}",
          "${steelborePalette.moltenAmber}",
          "${steelborePalette.liquidCool}",
          "${steelborePalette.liquidCool}",
          "${steelborePalette.liquidCool}",
          "${steelborePalette.moltenAmber}"
        },

        tab_bar = {
          background = "${steelborePalette.voidNavy}",
          active_tab = {
            bg_color = "${steelborePalette.steelBlue}",
            fg_color = "${steelborePalette.moltenAmber}",
          },
          inactive_tab = {
            bg_color = "${steelborePalette.voidNavy}",
            fg_color = "${steelborePalette.steelBlue}",
          },
          inactive_tab_hover = {
            bg_color = "${steelborePalette.steelBlue}",
            fg_color = "${steelborePalette.moltenAmber}",
          },
          new_tab = {
            bg_color = "${steelborePalette.voidNavy}",
            fg_color = "${steelborePalette.steelBlue}",
          },
          new_tab_hover = {
            bg_color = "${steelborePalette.steelBlue}",
            fg_color = "${steelborePalette.moltenAmber}",
          },
        },
      }

      return config
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # GHOSTTY — Zig-based GPU-accelerated terminal (memory-safe)
    # ═══════════════════════════════════════════════════════════════════════════
    environment.etc."ghostty/config".text = ''
      # Steelbore Ghostty Configuration

      font-family = Inconsolata Nerd Font
      font-size = 12

      background-opacity = 0.95
      window-padding-x = 10
      window-padding-y = 10

      # Steelbore color palette
      background = ${steelborePalette.voidNavy}
      foreground = ${steelborePalette.moltenAmber}
      cursor-color = ${steelborePalette.moltenAmber}
      cursor-text = ${steelborePalette.voidNavy}
      selection-background = ${steelborePalette.steelBlue}
      selection-foreground = ${steelborePalette.voidNavy}

      # Normal colors (0-7)
      palette = 0=${steelborePalette.voidNavy}
      palette = 1=${steelborePalette.redOxide}
      palette = 2=${steelborePalette.radiumGreen}
      palette = 3=${steelborePalette.moltenAmber}
      palette = 4=${steelborePalette.steelBlue}
      palette = 5=${steelborePalette.steelBlue}
      palette = 6=${steelborePalette.liquidCool}
      palette = 7=${steelborePalette.moltenAmber}

      # Bright colors (8-15)
      palette = 8=${steelborePalette.steelBlue}
      palette = 9=${steelborePalette.redOxide}
      palette = 10=${steelborePalette.radiumGreen}
      palette = 11=${steelborePalette.moltenAmber}
      palette = 12=${steelborePalette.liquidCool}
      palette = 13=${steelborePalette.liquidCool}
      palette = 14=${steelborePalette.liquidCool}
      palette = 15=${steelborePalette.moltenAmber}

      # Shell — launches ion
      command = ${pkgs.nushell}/bin/nu
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # COSMIC-TERM — COSMIC desktop terminal (Rust-based)
    # Config is typically managed by cosmic-settings, but we provide defaults
    # ═══════════════════════════════════════════════════════════════════════════
    environment.etc."cosmic/com.system76.CosmicTerm/v1/syntax_theme_dark".text = ''
      "Steelbore"
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # PTYXIS (GNOME Console) — VTE-based terminal
    # Uses dconf/gsettings, configured via GNOME module or home-manager
    # Providing a CSS override for theming
    # ═══════════════════════════════════════════════════════════════════════════
    environment.etc."gtk-4.0/gtk.css".text = ''
      /* Steelbore Ptyxis/VTE Terminal Theme Override */
      vte-terminal {
        padding: 10px;
      }
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # WAVETERM — AI-native terminal
    # Uses JSON configuration
    # ═══════════════════════════════════════════════════════════════════════════
    environment.etc."waveterm/config.json".text = builtins.toJSON {
      term = {
        fontfamily = "Inconsolata Nerd Font";
        fontsize = 12;
        theme = "custom";
      };
      themes = {
        custom = {
          display = {
            name = "Steelbore";
            order = 1;
          };
          terminal = {
            background = steelborePalette.voidNavy;
            foreground = steelborePalette.moltenAmber;
            cursor = steelborePalette.moltenAmber;
            selectionBackground = steelborePalette.steelBlue;
            black = steelborePalette.voidNavy;
            red = steelborePalette.redOxide;
            green = steelborePalette.radiumGreen;
            yellow = steelborePalette.moltenAmber;
            blue = steelborePalette.steelBlue;
            magenta = steelborePalette.steelBlue;
            cyan = steelborePalette.liquidCool;
            white = steelborePalette.moltenAmber;
            brightBlack = steelborePalette.steelBlue;
            brightRed = steelborePalette.redOxide;
            brightGreen = steelborePalette.radiumGreen;
            brightYellow = steelborePalette.moltenAmber;
            brightBlue = steelborePalette.liquidCool;
            brightMagenta = steelborePalette.liquidCool;
            brightCyan = steelborePalette.liquidCool;
            brightWhite = steelborePalette.moltenAmber;
          };
        };
      };
    };

    # ═══════════════════════════════════════════════════════════════════════════
    # WARP TERMINAL — AI-powered terminal
    # Uses YAML configuration
    # ═══════════════════════════════════════════════════════════════════════════
    environment.etc."warp/themes/steelbore.yaml".text = ''
      # Steelbore Theme for Warp Terminal
      accent: '${steelborePalette.steelBlue}'
      background: '${steelborePalette.voidNavy}'
      foreground: '${steelborePalette.moltenAmber}'
      details: darker
      terminal_colors:
        normal:
          black: '${steelborePalette.voidNavy}'
          red: '${steelborePalette.redOxide}'
          green: '${steelborePalette.radiumGreen}'
          yellow: '${steelborePalette.moltenAmber}'
          blue: '${steelborePalette.steelBlue}'
          magenta: '${steelborePalette.steelBlue}'
          cyan: '${steelborePalette.liquidCool}'
          white: '${steelborePalette.moltenAmber}'
        bright:
          black: '${steelborePalette.steelBlue}'
          red: '${steelborePalette.redOxide}'
          green: '${steelborePalette.radiumGreen}'
          yellow: '${steelborePalette.moltenAmber}'
          blue: '${steelborePalette.liquidCool}'
          magenta: '${steelborePalette.liquidCool}'
          cyan: '${steelborePalette.liquidCool}'
          white: '${steelborePalette.moltenAmber}'
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # TERMIUS — SSH client (theming limited, uses app settings)
    # No system-level theming available; users configure in-app
    # ═══════════════════════════════════════════════════════════════════════════

    # ═══════════════════════════════════════════════════════════════════════════
    # KONSOLE — KDE terminal emulator
    # Colorscheme + profile placed in system XDG data dir
    # ═══════════════════════════════════════════════════════════════════════════
    environment.etc."xdg/konsole/Steelbore.colorscheme".text = ''
      # Steelbore Konsole Color Scheme
      # Palette: Void Navy / Molten Amber / Steel Blue / Radium Green / Red Oxide / Liquid Coolant

      [Background]
      Color=0,0,39

      [BackgroundFaint]
      Color=0,0,39

      [BackgroundIntense]
      Bold=true
      Color=75,126,176

      [Color0]
      Color=0,0,39

      [Color0Faint]
      Color=0,0,39

      [Color0Intense]
      Bold=true
      Color=75,126,176

      [Color1]
      Color=255,92,92

      [Color1Faint]
      Color=255,92,92

      [Color1Intense]
      Bold=true
      Color=255,92,92

      [Color2]
      Color=80,250,123

      [Color2Faint]
      Color=80,250,123

      [Color2Intense]
      Bold=true
      Color=80,250,123

      [Color3]
      Color=217,142,50

      [Color3Faint]
      Color=217,142,50

      [Color3Intense]
      Bold=true
      Color=217,142,50

      [Color4]
      Color=75,126,176

      [Color4Faint]
      Color=75,126,176

      [Color4Intense]
      Bold=true
      Color=139,233,253

      [Color5]
      Color=75,126,176

      [Color5Faint]
      Color=75,126,176

      [Color5Intense]
      Bold=true
      Color=139,233,253

      [Color6]
      Color=139,233,253

      [Color6Faint]
      Color=139,233,253

      [Color6Intense]
      Bold=true
      Color=139,233,253

      [Color7]
      Color=217,142,50

      [Color7Faint]
      Color=217,142,50

      [Color7Intense]
      Bold=true
      Color=217,142,50

      [Foreground]
      Color=217,142,50

      [ForegroundFaint]
      Color=217,142,50

      [ForegroundIntense]
      Bold=true
      Color=217,142,50

      [General]
      Anchor=0.5,0.5
      Blur=false
      ColorRandomization=false
      Description=Steelbore
      FillStyle=Tile
      Opacity=0.95
      Spread=1.0
      Wallpaper=
    '';

    environment.etc."xdg/konsole/Steelbore.profile".text = ''
      # Steelbore Konsole Profile

      [Appearance]
      ColorScheme=Steelbore
      Font=Inconsolata Nerd Font,12,-1,5,50,0,0,0,0,0

      [General]
      Command=${pkgs.nushell}/bin/nu
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

    environment.etc."xdg/konsolerc".text = ''
      [Desktop Entry]
      DefaultProfile=Steelbore.profile

      [TabBar]
      CloseTabOnMiddleMouseButton=true
      NewTabButton=false
      TabBarPosition=Top
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # YAKUAKE — KDE drop-down terminal (uses Konsole as backend)
    # Shell and colors are inherited from the Konsole Steelbore profile above
    # ═══════════════════════════════════════════════════════════════════════════
    environment.etc."xdg/yakuakerc".text = ''
      [Desktop Entry]
      DefaultProfile=Steelbore.profile

      [Window]
      Height=50
      Width=100
      KeepOpen=false
      AnimationDuration=0
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # FOOT — Wayland terminal (C, lightweight)
    # System-level fallback config at /etc/xdg/foot/foot.ini
    # ═══════════════════════════════════════════════════════════════════════════
    environment.etc."xdg/foot/foot.ini".text = ''
      # Steelbore Foot Configuration

      [main]
      font=Inconsolata Nerd Font:size=12
      shell=${pkgs.nushell}/bin/nu
      term=xterm-256color

      [colors]
      background=${h steelborePalette.voidNavy}
      foreground=${h steelborePalette.moltenAmber}
      regular0=${h steelborePalette.voidNavy}
      regular1=${h steelborePalette.redOxide}
      regular2=${h steelborePalette.radiumGreen}
      regular3=${h steelborePalette.moltenAmber}
      regular4=${h steelborePalette.steelBlue}
      regular5=${h steelborePalette.steelBlue}
      regular6=${h steelborePalette.liquidCool}
      regular7=${h steelborePalette.moltenAmber}
      bright0=${h steelborePalette.steelBlue}
      bright1=${h steelborePalette.redOxide}
      bright2=${h steelborePalette.radiumGreen}
      bright3=${h steelborePalette.moltenAmber}
      bright4=${h steelborePalette.liquidCool}
      bright5=${h steelborePalette.liquidCool}
      bright6=${h steelborePalette.liquidCool}
      bright7=${h steelborePalette.moltenAmber}
      cursor=${h steelborePalette.voidNavy} ${h steelborePalette.moltenAmber}
      selection-foreground=${h steelborePalette.voidNavy}
      selection-background=${h steelborePalette.steelBlue}

      [scrollback]
      lines=10000
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # XTERM — Classic X11 terminal
    # System-level Xresources loaded by xrdb on X session start
    # ═══════════════════════════════════════════════════════════════════════════
    environment.etc."X11/Xresources".text = ''
      ! Steelbore XTerm Configuration

      XTerm*termName:              xterm-256color
      XTerm*faceName:              Inconsolata Nerd Font
      XTerm*faceSize:              12
      XTerm*loginShell:            true
      XTerm*scrollBar:             false
      XTerm*saveLines:             10000
      XTerm*bellIsUrgent:          true
      XTerm*internalBorder:        10

      XTerm*background:            ${steelborePalette.voidNavy}
      XTerm*foreground:            ${steelborePalette.moltenAmber}
      XTerm*cursorColor:           ${steelborePalette.moltenAmber}
      XTerm*pointerColorBackground:${steelborePalette.voidNavy}
      XTerm*pointerColorForeground:${steelborePalette.moltenAmber}
      XTerm*highlightColor:        ${steelborePalette.steelBlue}

      XTerm*color0:                ${steelborePalette.voidNavy}
      XTerm*color1:                ${steelborePalette.redOxide}
      XTerm*color2:                ${steelborePalette.radiumGreen}
      XTerm*color3:                ${steelborePalette.moltenAmber}
      XTerm*color4:                ${steelborePalette.steelBlue}
      XTerm*color5:                ${steelborePalette.steelBlue}
      XTerm*color6:                ${steelborePalette.liquidCool}
      XTerm*color7:                ${steelborePalette.moltenAmber}
      XTerm*color8:                ${steelborePalette.steelBlue}
      XTerm*color9:                ${steelborePalette.redOxide}
      XTerm*color10:               ${steelborePalette.radiumGreen}
      XTerm*color11:               ${steelborePalette.moltenAmber}
      XTerm*color12:               ${steelborePalette.liquidCool}
      XTerm*color13:               ${steelborePalette.liquidCool}
      XTerm*color14:               ${steelborePalette.liquidCool}
      XTerm*color15:               ${steelborePalette.moltenAmber}
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # XFCE4-TERMINAL — XFCE4 terminal
    # System-level fallback config
    # ═══════════════════════════════════════════════════════════════════════════
    environment.etc."xdg/xfce4/terminal/terminalrc".text = ''
      [Configuration]
      FontName=Inconsolata Nerd Font 12
      MiscDefaultGeometry=160x48
      RunCustomCommand=TRUE
      CustomCommand=${pkgs.nushell}/bin/nu
      BackgroundMode=TERMINAL_BACKGROUND_TRANSPARENT
      BackgroundDarkness=0.95
      ColorBackground=${steelborePalette.voidNavy}
      ColorForeground=${steelborePalette.moltenAmber}
      ColorCursor=${steelborePalette.moltenAmber}
      ColorBold=FALSE
      ColorPalette=${steelborePalette.voidNavy};${steelborePalette.redOxide};${steelborePalette.radiumGreen};${steelborePalette.moltenAmber};${steelborePalette.steelBlue};${steelborePalette.steelBlue};${steelborePalette.liquidCool};${steelborePalette.moltenAmber};${steelborePalette.steelBlue};${steelborePalette.redOxide};${steelborePalette.radiumGreen};${steelborePalette.moltenAmber};${steelborePalette.liquidCool};${steelborePalette.liquidCool};${steelborePalette.liquidCool};${steelborePalette.moltenAmber}
      MiscMenubarDefault=FALSE
      ScrollingBar=TERMINAL_SCROLLBAR_NONE
      ScrollingLines=10000
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # GNOME CONSOLE (kgx) — GNOME 4x minimal terminal
    # Color palette is fixed by theme; "night" is the closest dark option.
    # Shell is inherited from $SHELL (ion). Configured via dconf in home.
    # ═══════════════════════════════════════════════════════════════════════════
  };
}
