# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Margo tag-based tiling compositor (Wayland, Rust/Smithay)
#
# margo is a Rust port of mango (dwl): mango's tags, layouts and fluid
# animations, rebuilt on Smithay with niri-style spring physics for window
# movement. The package is in-tree (pkgs/margo) and builds the compositor
# half only — the session reuses the Niri companion stack (eww, anyrun,
# dunst, gtklock, swayidle, swayosd), so this module installs the same set.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  margo = (import ../../pkgs { inherit pkgs; }).margo;
  wallpaperPkg = pkgs.awww or pkgs.swww;
in
{
  options.steelbore.desktops.margo = {
    enable = lib.mkEnableOption "Margo tag-based tiling compositor (Wayland, Rust port of mango)";
  };

  config = lib.mkIf config.steelbore.desktops.margo.enable {
    environment.systemPackages = [
      margo
    ]
    ++ (with pkgs; [
      eww # Status bar (Rust)
      anyrun # Launcher (Rust)
      rofi # App menu on Super+Shift+D, as under LeftWM (C; Wayland since 2.0)
      dunst # Notifications
      gtklock # Screen locker (ext-session-lock)
      swayidle # Idle management
      swayosd # Brightness/volume OSD
      wl-clipboard-rs # Clipboard (Rust)
      grim # Screenshot
      slurp # Region selection
      polkit_gnome # Polkit agent; margo ships none without mshell
    ])
    ++ [ wallpaperPkg ];

    # Registers share/wayland-sessions/margo.desktop (Exec=start-margo) with
    # tuigreet's --sessions list (modules/login).
    services.displayManager.sessionPackages = [ margo ];

    # margo implements the org.gnome.Mutter.ScreenCast shim, the same way
    # niri does, so screen sharing routes through xdg-desktop-portal-gnome
    # (registered by gnome.nix). Everything else goes to the gtk backend.
    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gnome
        pkgs.xdg-desktop-portal-gtk
      ];
      config.margo = {
        default = [
          "gnome"
          "gtk"
        ];
        "org.freedesktop.impl.portal.Access" = [ "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        "org.freedesktop.impl.portal.Notification" = [ "gtk" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
    };

    programs.xwayland.enable = lib.mkDefault true;
    security.polkit.enable = lib.mkDefault true;

    # The compositor config is user-level: users/mj/margo.nix writes
    # ~/.config/margo/config.conf from the palette.
  };
}
