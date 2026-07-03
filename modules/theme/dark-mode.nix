# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — System-Wide Dark Mode (Niri + LeftWM)
#
# Provides the system-level plumbing for an always-on dark GTK/Qt theme
# under bare WM sessions (Niri, LeftWM) where no DE control center is
# present to drive xdg-desktop-portal-gtk's appearance interface or to
# set gsettings keys.
#
# Per-user theme selection (gtk.*, qt.*, home.pointerCursor) lives in
# users/mj/home.nix — this module only ships the packages, enables
# dconf, and routes the portal so the HM layer's dconf writes are
# visible to xdg-desktop-portal-gtk.
#
# DE sessions (GNOME, COSMIC, Plasma) are deliberately untouched — they
# carry their own appearance controllers; the dconf keys this module's
# HM counterpart writes only take effect when those DEs' own theme
# system is not overriding (i.e. under Niri / LeftWM).
{
  pkgs,
  ...
}:

{
  # dconf is the storage backend HM's gtk module writes to (and what
  # xdg-desktop-portal-gtk reads from to serve
  # org.freedesktop.appearance.color-scheme). NixOS enables dconf
  # implicitly when services.desktopManager.{gnome,cosmic}.enable is
  # set; the explicit toggle keeps the dependency visible and makes
  # dark-mode work for hosts that disable those DEs.
  programs.dconf.enable = true;

  # Theme + icon + cursor packages, plus the Adwaita-Qt platform theme
  # and qadwaitadecorations (Qt window decorations matching libadwaita).
  # HM's gtk/qt modules also pull these into ~/.local/share, but the
  # system-wide path is the safety net for non-HM contexts (root Qt
  # apps, system services with a GUI, .desktop entries from
  # /run/current-system/sw/share/applications).
  environment.systemPackages = with pkgs; [
    adw-gtk3 # GTK3 theme matching libadwaita / GTK4
    papirus-icon-theme # Icon theme (provides Papirus-Dark)
    bibata-cursors # Cursor theme (Bibata-Modern-Classic)
    adwaita-qt # Qt5 Adwaita platform theme
    adwaita-qt6 # Qt6 Adwaita platform theme
    qadwaitadecorations # Qt5 window decorations
    qadwaitadecorations-qt6 # Qt6 window decorations
    xdg-desktop-portal-gtk # Appearance backend for bare WMs
  ];

  # xdg-desktop-portal-gtk is the appearance backend that serves
  # org.freedesktop.appearance.color-scheme to libadwaita apps under
  # bare WMs. The GNOME module already pulls -gnome (which depends on
  # -gtk), but Niri/LeftWM sessions don't trigger that chain — list
  # explicitly so it's present even with GNOME disabled.
  #
  # Routing notes:
  # - niri: upstream `services.programs.wayland.niri` already sets
  #   `xdg.portal.config.niri.default = "gnome;gtk"` — an ordered
  #   fallback. Both -gnome and -gtk read color-scheme from the same
  #   `org.gnome.desktop.interface.color-scheme` dconf key, so leaving
  #   that default alone gives correct dark-mode behavior. Setting our
  #   own value here would conflict at eval time.
  # - leftwm: not in nixpkgs (we ship our own xsession), so no upstream
  #   default. Set explicitly to the gtk backend.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.leftwm.default = [ "gtk" ];
  };
}
