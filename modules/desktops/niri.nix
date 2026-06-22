# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Niri Scrolling Tiling Compositor (Wayland)
{ config, lib, pkgs, steelborePalette, ... }:

{
  options.steelbore.desktops.niri = {
    enable = lib.mkEnableOption "Niri scrolling tiling compositor (Wayland)";
  };

  config = lib.mkIf config.steelbore.desktops.niri.enable (
    let
      # Wallpaper daemon: upstream renamed swww → awww. On unstable both
      # exist (swww is a deprecation alias that warns); on stable only swww
      # exists. The `or`-fallback picks the right package per channel.
      # (The daemon is spawned from the Niri config in users/mj/home.nix,
      # which derives its own wallpaperBin; here we only install the package.)
      wallpaperPkg = pkgs.awww or pkgs.swww;

      # Radio toggles for the dedicated Bluetooth / airplane-mode keys.
      # rfkill works rootless here: /dev/rfkill carries a systemd `uaccess`
      # ACL for the active-session user. Feedback goes through dunstify
      # (dunst is already in the package set below), since swayosd has no
      # OSD for radio state. `-r` reuses a fixed notification id so repeated
      # presses replace rather than stack.
      btToggle = pkgs.writeShellScriptBin "steelbore-bt-toggle" ''
        ${pkgs.util-linux}/bin/rfkill toggle bluetooth
        if ${pkgs.util-linux}/bin/rfkill list bluetooth | grep -q "Soft blocked: yes"; then
          ${pkgs.dunst}/bin/dunstify -a Bluetooth -r 9911 -i bluetooth-disabled "Bluetooth Off"
        else
          ${pkgs.dunst}/bin/dunstify -a Bluetooth -r 9911 -i bluetooth-active "Bluetooth On"
        fi
      '';
      airplaneToggle = pkgs.writeShellScriptBin "steelbore-airplane-toggle" ''
        ${pkgs.util-linux}/bin/rfkill toggle all
        if ${pkgs.util-linux}/bin/rfkill list wlan | grep -q "Soft blocked: yes"; then
          ${pkgs.dunst}/bin/dunstify -a Airplane -r 9912 -i airplane-mode "Airplane Mode On"
        else
          ${pkgs.dunst}/bin/dunstify -a Airplane -r 9912 -i network-wireless "Airplane Mode Off"
        fi
      '';
    in
    {
    # Enable Niri
    programs.niri.enable = true;

    # Niri and companion packages.
    # Stack matches LeftWM where cross-platform (eww, dunst, gtklock) and
    # uses Wayland-only tools where the X11 alternatives don't exist.
    environment.systemPackages = (with pkgs; [
      niri
      xwayland-satellite        # X11 app support inside Niri

      # Status bar — Eww (Rust, X11 + Wayland; shared with LeftWM)
      eww

      # Launcher — Anyrun (Rust, Wayland)
      anyrun

      # Notifications — dunst (cross-platform with LeftWM)
      dunst

      # Screen locker — gtklock (cross-platform with LeftWM)
      gtklock
      swayidle                  # Idle management

      # Clipboard / screenshot
      wl-clipboard
      wl-clipboard-rs           # (Rust)
      grim                      # Screenshot
      slurp                     # Region selection

      # Dedicated/multimedia key handling (Niri has no built-in daemon for
      # XF86 keys, unlike GNOME/Plasma/COSMIC). The binds that drive these
      # live in the Niri config in users/mj/home.nix.
      swayosd                   # On-screen-display bars for brightness/volume
      brightnessctl             # C — display + keyboard backlight control
      playerctl                 # MPRIS media control (was only transitive)
    ]) ++ [
      # Wallpaper daemon — awww (renamed from swww upstream).
      wallpaperPkg
      # Radio-toggle wrappers for the Bluetooth / airplane-mode keys.
      btToggle
      airplaneToggle
    ];

    # brightnessctl ships udev rules that make /sys/class/backlight (group
    # `video`) and /sys/class/leds (group `input`) group-writable, so the
    # display + keyboard backlight are controllable rootless. User `mj` is
    # in both groups. swayosd-server's brightness backend also relies on
    # the backlight being `video`-writable.
    services.udev.packages = [ pkgs.brightnessctl ];

    # The Niri config itself is the SINGLE SOURCE at the user level:
    # users/mj/home.nix → xdg.configFile."niri/config.kdl". niri reads
    # ~/.config/niri/config.kdl in preference to /etc/niri/config.kdl, so a
    # second copy here would be dead (and previously drifted — brightness
    # binds added here never took effect). Layout, startup (incl.
    # swayosd-server), and all key binds — including the XF86 keys that call
    # the packages and wrapper scripts above — live in home.nix. This module
    # only enables Niri, installs companion packages, ships the backlight
    # udev rule, and provides the rfkill toggle wrappers.
    #
    # Status bar / launcher / notifications / wallpaper / lock are likewise
    # configured at the home-manager level. Eww config lives in
    # users/mj/home.nix (xdg.configFile."eww/..."); dunst remains at
    # /etc/dunst/dunstrc (set in modules/desktops/leftwm.nix).
  });
}
