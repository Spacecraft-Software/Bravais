# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Niri Scrolling Tiling Compositor (Wayland)
{
  config,
  lib,
  pkgs,
  ...
}:

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
    in
    {
      # Enable Niri
      programs.niri.enable = true;

      # Niri and companion packages.
      # Stack matches LeftWM where cross-platform (eww, dunst, gtklock) and
      # uses Wayland-only tools where the X11 alternatives don't exist.
      environment.systemPackages =
        (with pkgs; [
          niri
          xwayland-satellite # X11 app support inside Niri

          # Status bar — Eww (Rust, X11 + Wayland; shared with LeftWM)
          eww

          # Launcher — Anyrun (Rust, Wayland)
          anyrun

          # Notifications — dunst (cross-platform with LeftWM)
          dunst

          # Screen locker — gtklock (cross-platform with LeftWM)
          gtklock
          swayidle # Idle management

          # Clipboard / screenshot
          wl-clipboard
          wl-clipboard-rs # (Rust)
          grim # Screenshot
          slurp # Region selection

          # Dedicated/multimedia key handling (Niri has no built-in daemon for
          # XF86 keys, unlike GNOME/Plasma/COSMIC). The binds that drive these
          # live in the Niri config in users/mj/niri.nix.
          swayosd # On-screen-display bars for brightness/volume

          # Polkit authentication agent — shows auth dialogs for privileged
          # operations (fingerprint enrollment, Flatpak installs, etc.).
          # GNOME/Plasma start their own agent; Niri needs this explicitly.
          polkit_gnome
        ])
        ++ [
          # Wallpaper daemon — awww (renamed from swww upstream).
          wallpaperPkg
        ];

      # The Niri config itself is the SINGLE SOURCE at the user level:
      # users/mj/niri.nix → xdg.configFile."niri/config.kdl". niri reads
      # ~/.config/niri/config.kdl in preference to /etc/niri/config.kdl, so a
      # second copy here would be dead (and previously drifted — brightness
      # binds added here never took effect). Layout, startup (incl.
      # swayosd-server), and all key binds — including the XF86 keys that call
      # the packages and wrapper scripts above — live in niri.nix. This module
      # only enables Niri, installs companion packages, and ships the
      # wallpaper daemon.
      #
      # rfkill toggles, caffeine, keyboard-backlight cycle, X11 OSD wrapper,
      # brightnessctl udev rule, and dunst config live in
      # modules/desktops/shared.nix — shared with LeftWM so disabling either
      # WM can't strip the other's config.
      #
      # Status bar / launcher / notifications / wallpaper / lock are likewise
      # configured at the home-manager level. Eww config lives in
      # users/mj/eww.nix (xdg.configFile."eww/...").
    }
  );
}
