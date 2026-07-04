# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Terminal Emulators (All with Steelbore Theme)
{
  config,
  lib,
  pkgs,
  steelborePalette,
  ...
}:

let
  # Palette format converters from lib/colors.nix (single source, Standard §11)
  h = steelborePalette.convert.bareHex; # Foot needs hex without the '#'
  t = steelborePalette.convert.rgbTriple; # Konsole INI needs decimal R,G,B
  # Shared terminal-theme record + per-format emitters (plan item 1.2)
  tt = import ../../lib/terminal-theme.nix steelborePalette;
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
      ghostty # Zig, but memory-safe

      # Other terminals
      ptyxis
      # GNOME terminal (VTE-based) — host install so
      #   distrobox/container integration works out-of-box.
      waveterm # AI-native terminal
      warp-terminal # AI-powered terminal
      termius # SSH client
      cosmic-term # COSMIC terminal

      # KDE terminals
      kdePackages.konsole # KDE terminal emulator
      kdePackages.yakuake # KDE drop-down terminal

      # GNOME terminals
      gnome-console # GNOME Console (kgx)

      # Wayland/X11 terminals
      foot # Wayland terminal (C, lightweight)
      xterm # Classic X11 terminal

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
      normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }
      bold = { family = "JetBrainsMono Nerd Font", style = "Bold" }
      italic = { family = "JetBrainsMono Nerd Font", style = "Italic" }
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
      config.font = wezterm.font 'JetBrainsMono Nerd Font'
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
    environment.etc."ghostty/config".text = tt.ghostty {
      shell = "${pkgs.nushell}/bin/nu";
    };

    # ═══════════════════════════════════════════════════════════════════════════
    # COSMIC-TERM — COSMIC desktop terminal (Rust-based)
    # cosmic-config reads per-key .ron files; system defaults live in /etc/cosmic
    # ═══════════════════════════════════════════════════════════════════════════
    environment.etc."cosmic/com.system76.CosmicTerm/v1/syntax_theme_dark".text = ''
      "Steelbore"
    '';

    environment.etc."cosmic/com.system76.CosmicTerm/v1/color_schemes_dark".text = ''
      {
          1: (
              name: "Steelbore",
              foreground: "${steelborePalette.moltenAmber}",
              background: "${steelborePalette.voidNavy}",
              cursor: "${steelborePalette.moltenAmber}",
              bright_foreground: "${steelborePalette.moltenAmber}",
              dim_foreground: "${steelborePalette.steelBlue}",
              normal: (
                  black: "${steelborePalette.voidNavy}",
                  red: "${steelborePalette.redOxide}",
                  green: "${steelborePalette.radiumGreen}",
                  yellow: "${steelborePalette.moltenAmber}",
                  blue: "${steelborePalette.steelBlue}",
                  magenta: "${steelborePalette.steelBlue}",
                  cyan: "${steelborePalette.liquidCool}",
                  white: "${steelborePalette.moltenAmber}",
              ),
              bright: (
                  black: "${steelborePalette.steelBlue}",
                  red: "${steelborePalette.redOxide}",
                  green: "${steelborePalette.radiumGreen}",
                  yellow: "${steelborePalette.moltenAmber}",
                  blue: "${steelborePalette.liquidCool}",
                  magenta: "${steelborePalette.liquidCool}",
                  cyan: "${steelborePalette.liquidCool}",
                  white: "${steelborePalette.moltenAmber}",
              ),
              dim: (
                  black: "${steelborePalette.voidNavy}",
                  red: "${steelborePalette.redOxide}",
                  green: "${steelborePalette.radiumGreen}",
                  yellow: "${steelborePalette.moltenAmber}",
                  blue: "${steelborePalette.steelBlue}",
                  magenta: "${steelborePalette.steelBlue}",
                  cyan: "${steelborePalette.liquidCool}",
                  white: "${steelborePalette.moltenAmber}",
              ),
          ),
      }
    '';

    # Default profile → launch Nushell, matching every other terminal here.
    # cosmic-term shlex-splits profile.command for the PTY (main.rs); a single
    # /nix/store path (no spaces) yields one program token, no args. Pins the
    # profile to the Steelbore color scheme too. `default_profile` selects it.
    environment.etc."cosmic/com.system76.CosmicTerm/v1/profiles".text = ''
      {
          0: (
              name: "Steelbore",
              command: "${pkgs.nushell}/bin/nu",
              syntax_theme_dark: "Steelbore",
              syntax_theme_light: "Steelbore",
              tab_title: "",
              working_directory: "",
              drain_on_exit: false,
          ),
      }
    '';

    environment.etc."cosmic/com.system76.CosmicTerm/v1/default_profile".text = ''
      Some(0)
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
        fontfamily = "JetBrainsMono Nerd Font";
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
    environment.etc."warp/themes/steelbore.yaml".text = tt.warpYaml;

    # ═══════════════════════════════════════════════════════════════════════════
    # TERMIUS — SSH client (theming limited, uses app settings)
    # No system-level theming available; users configure in-app
    # ═══════════════════════════════════════════════════════════════════════════

    # ═══════════════════════════════════════════════════════════════════════════
    # KONSOLE — KDE terminal emulator
    # Colorscheme + profile placed in system XDG data dir
    # ═══════════════════════════════════════════════════════════════════════════
    environment.etc."xdg/konsole/Steelbore.colorscheme".text = tt.konsoleColorscheme;

    environment.etc."xdg/konsole/Steelbore.profile".text = tt.konsoleProfile {
      shell = "${pkgs.nushell}/bin/nu";
    };

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
    environment.etc."xdg/foot/foot.ini".text = tt.foot {
      header = "Steelbore Foot Configuration";
      shell = "${pkgs.nushell}/bin/nu";
    };

    # ═══════════════════════════════════════════════════════════════════════════
    # XTERM — Classic X11 terminal
    # System-level Xresources loaded by xrdb on X session start
    # ═══════════════════════════════════════════════════════════════════════════
    environment.etc."X11/Xresources".text = tt.xresources;

    # ═══════════════════════════════════════════════════════════════════════════
    # XFCE4-TERMINAL — XFCE4 terminal
    # System-level fallback config
    # ═══════════════════════════════════════════════════════════════════════════
    environment.etc."xdg/xfce4/terminal/terminalrc".text = tt.xfce {
      shell = "${pkgs.nushell}/bin/nu";
    };

    # ═══════════════════════════════════════════════════════════════════════════
    # GNOME CONSOLE (kgx) — GNOME 4x minimal terminal
    # Color palette is fixed by theme; "night" is the closest dark option.
    # Shell is inherited from $SHELL (Nushell login shell). Configured via dconf in home.
    # ═══════════════════════════════════════════════════════════════════════════
  };
}
