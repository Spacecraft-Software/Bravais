# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — COSMIC Desktop Environment (Wayland)
{
  primaryUser,
  config,
  lib,
  steelborePalette,
  ...
}:

let
  # cosmic-theme stores colors as Srgba with 0.0–1.0 floats. Derived from the
  # canonical palette via lib/palette.nix `convert.srgbaFloat` — the converter
  # reproduces cosmic-settings' own eight-digit formatting, so user-facing
  # diffs stay clean and the values can never drift from the palette.
  toRgb = steelborePalette.convert.srgbaFloat;

  # COSMIC switches between a Dark and a Light Builder by time of day, so it
  # needs BOTH polarities from one build. Each comes from a registered
  # palette's role tokens: the active theme for its own polarity, and its
  # Standard §11.6.2 counterpart (`meta.pair`, resolved as `counterpart`) for
  # the other. Every value — and its verified contrast — is read from
  # steelbore.toml; nothing is typed here (Standard §11.4).
  dark =
    if steelborePalette.meta.polarity == "dark" then steelborePalette else steelborePalette.counterpart;
  light =
    if steelborePalette.meta.polarity == "light" then
      steelborePalette
    else
      steelborePalette.counterpart;

  rgbOf = p: {
    background = toRgb p.background;
    foreground = toRgb p.foreground;
    accent = toRgb p.accent;
    structure = toRgb p.structure;
    success = toRgb p.success;
    warning = toRgb p.warning;
    error = toRgb p.error;
  };
  rgb = rgbOf dark;
  rgbLight = rgbOf light;

  # bg_color is the only Builder field that carries an alpha channel.
  mkBgColor =
    hex:
    let
      ch = steelborePalette.convert.srgbaChannels hex;
    in
    ''
      Some((
          red: ${ch.red},
          green: ${ch.green},
          blue: ${ch.blue},
          alpha: 1.0,
      ))'';

  bgColorDark = mkBgColor dark.background;

  bgColorLight = mkBgColor light.background;

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
    home-manager.users.${primaryUser}.xdg.configFile = {
      # Dark Builder — active at night via auto_switch.
      "${darkBuilderDir}/bg_color".text = bgColorDark;
      "${darkBuilderDir}/accent".text = someRgb rgb.foreground;
      "${darkBuilderDir}/success".text = someRgb rgb.success;
      "${darkBuilderDir}/warning".text = someRgb rgb.foreground;
      "${darkBuilderDir}/destructive".text = someRgb rgb.error;
      "${darkBuilderDir}/text_tint".text = someRgb rgb.foreground;
      "${darkBuilderDir}/neutral_tint".text = someRgb rgb.accent;

      # Light Builder — active during the day via auto_switch. Every field is
      # the light counterpart's own role, measured against its own canvas in
      # steelbore.toml, so nothing here needs a hand-picked "on paper" shade.
      "${lightBuilderDir}/bg_color".text = bgColorLight;
      "${lightBuilderDir}/accent".text = someRgb rgbLight.accent;
      "${lightBuilderDir}/success".text = someRgb rgbLight.success;
      "${lightBuilderDir}/warning".text = someRgb rgbLight.warning;
      "${lightBuilderDir}/destructive".text = someRgb rgbLight.error;
      "${lightBuilderDir}/text_tint".text = someRgb rgbLight.foreground;
      "${lightBuilderDir}/neutral_tint".text = someRgb rgbLight.structure;

      # Auto-switch dark/light by time of day. We deliberately do NOT manage
      # is_dark — cosmic-settings-daemon needs to flip it on schedule, which
      # it can't do if the file is a read-only Nix store symlink.
      "${modeDir}/auto_switch".text = "true";
    };
  };
}
