# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Home Manager: Terminal emulator user configs (generated from lib/terminal-theme.nix)
# Split from home.nix in Phase D (elegance plan 3.1); zero behavior change.
{
  pkgs,
  steelborePalette,
  ...
}:

let
  # Shared terminal-theme record + per-format emitters (plan item 1.2)
  tt = import ../../lib/terminal-theme.nix steelborePalette;
in
{
  programs = {
    # Alacritty (Steelbore theme)
    alacritty = {
      enable = true;
      settings = {
        terminal.shell = {
          program = "${pkgs.nushell}/bin/nu";
        };
        window = {
          padding = {
            x = 10;
            y = 10;
          };
          dynamic_title = true;
          opacity = 0.95;
        };
        font = {
          normal = {
            family = "JetBrainsMono Nerd Font";
            style = "Regular";
          };
          size = 10.0;
        };
        colors = tt.alacrittyColors;
      };
    };
  };

  xdg.configFile = {
    # SwayOSD — on-screen-display bars for the dedicated brightness/volume
    # keys under Niri (binds + swayosd-server startup live in
    # modules/desktops/niri.nix). swayosd-server auto-reads both files from
    # this directory. Themed with the Steelbore palette.
    # cosmic-term shell + profile. cosmic-config layers per-key with the USER
    # file winning over /etc/cosmic, and cosmic-term writes a real `profiles`
    # file here (profile 0, empty command → $SHELL) that shadows the system
    # default in modules/packages/terminals.nix. Own it at the user level so
    # cosmic-term deterministically launches Nushell on the Steelbore scheme.
    # force = true overwrites the app-written file without a backup deadlock
    # (same treatment as the VSCode flatpak override and .gtkrc-2.0).
    "cosmic/com.system76.CosmicTerm/v1/profiles" = {
      force = true;
      text = ''
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
    };

    "cosmic/com.system76.CosmicTerm/v1/default_profile" = {
      force = true;
      text = "Some(0)\n";
    };

    # ═══════════════════════════════════════════════════════════════════════════
    # WEZTERM — User configuration
    # ═══════════════════════════════════════════════════════════════════════════
    "wezterm/wezterm.lua".text = tt.weztermLua {
      header = "Steelbore WezTerm User Configuration";
      shell = "${pkgs.nushell}/bin/nu";
    };

    # ═══════════════════════════════════════════════════════════════════════════
    # RIO — User configuration
    # ═══════════════════════════════════════════════════════════════════════════
    "rio/config.toml".text = tt.rioToml {
      shell = "${pkgs.nushell}/bin/nu";
    };

    # ═══════════════════════════════════════════════════════════════════════════
    # GHOSTTY — User configuration
    # ═══════════════════════════════════════════════════════════════════════════
    "ghostty/config".text = tt.ghostty {
      header = "Steelbore Ghostty User Configuration";
      shell = "${pkgs.nushell}/bin/nu";
    };

    # ═══════════════════════════════════════════════════════════════════════════
    # FOOT — User configuration
    # ═══════════════════════════════════════════════════════════════════════════
    "foot/foot.ini".text = tt.foot {
      header = "Steelbore Foot User Configuration";
      shell = "${pkgs.nushell}/bin/nu";
    };

    # ═══════════════════════════════════════════════════════════════════════════
    # XFCE4-TERMINAL — User configuration
    # ═══════════════════════════════════════════════════════════════════════════
    "xfce4/terminal/terminalrc".text = tt.xfce {
      shell = "${pkgs.nushell}/bin/nu";
    };

    "konsolerc".text = ''
      [Desktop Entry]
      DefaultProfile=Steelbore.profile

      [TabBar]
      CloseTabOnMiddleMouseButton=true
      NewTabButton=false
      TabBarPosition=Top
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # YAKUAKE — KDE drop-down terminal (uses Konsole as backend)
    # Inherits shell and colors from the Konsole Steelbore profile above
    # ═══════════════════════════════════════════════════════════════════════════
    "yakuakerc".text = ''
      [Desktop Entry]
      DefaultProfile=Steelbore.profile

      [Window]
      Height=50
      Width=100
      KeepOpen=false
      AnimationDuration=0
    '';
  };

  xdg.dataFile = {
    # ═══════════════════════════════════════════════════════════════════════════
    # KONSOLE — User profile and colorscheme
    # ═══════════════════════════════════════════════════════════════════════════
    "konsole/Steelbore.colorscheme".text = tt.konsoleColorschemePlain;

    "konsole/Steelbore.profile".text = tt.konsoleProfile {
      shell = "${pkgs.nushell}/bin/nu";
    };
  };

  # XTerm Xresources (loaded by xrdb on X session start)
  xresources.properties = tt.xresourcesProps;

  # dconf settings for GNOME-based terminals (Ptyxis, GNOME Console) +
  # system-wide dark-mode keys read by HM's gtk module, by Qt's adwaita
  # platform theme, and by xdg-desktop-portal-gtk when it serves
  # org.freedesktop.appearance.color-scheme to libadwaita apps under
  # Niri / LeftWM. Identical color-scheme value to the one HM writes
  # via `gtk.colorScheme = "dark"` — Nix attrset merge is a no-op when

  dconf.settings = {
    # ── Ptyxis ──────────────────────────────────────────────────────────────
    "org/gnome/Ptyxis" = {
      default-profile-uuid = "steelbore";
      font-name = "JetBrainsMono Nerd Font 12";
      use-system-font = false;
    };

    "org/gnome/Ptyxis/Profiles/steelbore" = {
      label = "Steelbore";
      palette = tt.ansi16;
      background-color = steelborePalette.voidNavy;
      foreground-color = steelborePalette.moltenAmber;
      use-theme-colors = false;
      opacity = 0.95;
    };

    # ── GNOME Console (kgx) ─────────────────────────────────────────────────
    # kgx has limited theming: fixed "night"/"day"/"auto" themes only.
    # Shell is inherited from $SHELL (nushell). Font can be customized.
    "org/gnome/Console" = {
      theme = "night";
      use-system-font = false;
      custom-font = "JetBrainsMono Nerd Font 12";
    };
  };
}
