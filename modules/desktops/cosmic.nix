# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — COSMIC Desktop Environment (Wayland)
{
  config,
  lib,
  pkgs,
  steelborePalette,
  ...
}:

let
  # cosmic-theme stores colors as Srgba with 0.0–1.0 floats. Pre-converted
  # from the canonical Steelbore palette (Standard §8). Eight-digit
  # precision matches what cosmic-settings writes itself, so user-facing
  # diffs stay clean.
  rgb = {
    voidNavy = "(red: 0.0, green: 0.0, blue: 0.15294118)"; # #000027
    moltenAmber = "(red: 0.85098039, green: 0.55686275, blue: 0.19607843)"; # #D98E32
    steelBlue = "(red: 0.29411765, green: 0.49411765, blue: 0.69019608)"; # #4B7EB0
    radiumGreen = "(red: 0.31372549, green: 0.98039216, blue: 0.48235294)"; # #50FA7B
    redOxide = "(red: 1.0, green: 0.36078431, blue: 0.36078431)"; # #FF5C5C
    liquidCool = "(red: 0.54509804, green: 0.91372549, blue: 0.99215686)"; # #8BE9FD

    # Light-mode-only derived shades — NOT in Spacecraft Software Standard §8.
    # Scoped to cosmic.nix; do not propagate to flake.nix steelborePalette,
    # lib/default.nix, or modules/theme. Promote in the Standard first if
    # they ever need to become canonical.
    paper = "(red: 0.94117647, green: 0.94901961, blue: 0.97254902)"; # #F0F2F8 — Light bg
    radiumGreenDeep = "(red: 0.18039216, green: 0.67058824, blue: 0.32941176)"; # #2EAB54 — success on Paper
    redOxideDeep = "(red: 0.83921569, green: 0.21960784, blue: 0.21960784)"; # #D63838 — destructive on Paper
  };

  # bg_color is the only Builder field that carries an alpha channel.
  bgColorDark = ''
    Some((
        red: 0.0,
        green: 0.0,
        blue: 0.15294118,
        alpha: 1.0,
    ))'';

  bgColorLight = ''
    Some((
        red: 0.94117647,
        green: 0.94901961,
        blue: 0.97254902,
        alpha: 1.0,
    ))'';

  someRgb = body: "Some(${body})";

  darkBuilderDir = ".config/cosmic/com.system76.CosmicTheme.Dark.Builder/v1";
  lightBuilderDir = ".config/cosmic/com.system76.CosmicTheme.Light.Builder/v1";
  modeDir = ".config/cosmic/com.system76.CosmicTheme.Mode/v1";
in

{
  options.steelbore.desktops.cosmic = {
    enable = lib.mkEnableOption "COSMIC Desktop Environment (Wayland)";
  };

  config = lib.mkIf config.steelbore.desktops.cosmic.enable {
    services.desktopManager.cosmic.enable = true;
    services.displayManager.cosmic-greeter.enable = false; # Use greetd

    # NixOS's services.desktopManager.cosmic.enable already wires up
    # xdg.portal (cosmic + gtk backends), programs.dconf, cosmic-screenshot,
    # and dbus services for COSMIC. We add only the explicit per-DE portal
    # routing — without it, when GNOME and Plasma are also enabled their
    # configPackages can merge ambiguously and Screenshot/Inhibit/FileChooser
    # interfaces may resolve to the wrong backend, which is what the dbus
    # popup and PrtSc "server crash" reflect.
    xdg.portal.config.cosmic = {
      default = [
        "cosmic"
        "gtk"
      ];
      "org.freedesktop.impl.portal.Screenshot" = [ "cosmic" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "cosmic" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };

    # Steelbore-themed Builder overrides for cosmic-theme. cosmic-settings-daemon
    # watches these via inotify, so changes apply without logout. palette /
    # corner_radii / spacing / gaps / active_hint / is_frosted / window_hint /
    # primary_container_bg / secondary_container_bg are intentionally left to
    # defaults — they render correctly once the top-level colors below are set.
    home-manager.users.mj.xdg.configFile = {
      # Dark Builder — active at night via auto_switch.
      "${darkBuilderDir}/bg_color".text = bgColorDark;
      "${darkBuilderDir}/accent".text = someRgb rgb.moltenAmber;
      "${darkBuilderDir}/success".text = someRgb rgb.radiumGreen;
      "${darkBuilderDir}/warning".text = someRgb rgb.moltenAmber;
      "${darkBuilderDir}/destructive".text = someRgb rgb.redOxide;
      "${darkBuilderDir}/text_tint".text = someRgb rgb.moltenAmber;
      "${darkBuilderDir}/neutral_tint".text = someRgb rgb.steelBlue;

      # Light Builder — active during the day via auto_switch. Uses derived
      # Paper bg + deep success/destructive shades that read on a light surface.
      "${lightBuilderDir}/bg_color".text = bgColorLight;
      "${lightBuilderDir}/accent".text = someRgb rgb.moltenAmber;
      "${lightBuilderDir}/success".text = someRgb rgb.radiumGreenDeep;
      "${lightBuilderDir}/warning".text = someRgb rgb.moltenAmber;
      "${lightBuilderDir}/destructive".text = someRgb rgb.redOxideDeep;
      "${lightBuilderDir}/text_tint".text = someRgb rgb.voidNavy;
      "${lightBuilderDir}/neutral_tint".text = someRgb rgb.steelBlue;

      # Auto-switch dark/light by time of day. We deliberately do NOT manage
      # is_dark — cosmic-settings-daemon needs to flip it on schedule, which
      # it can't do if the file is a read-only Nix store symlink.
      "${modeDir}/auto_switch".text = "true";
    };
  };
}
