# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — GNOME Desktop Environment (Wayland)
{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.steelbore.desktops.gnome = {
    enable = lib.mkEnableOption "GNOME Desktop Environment (Wayland)";
  };

  config = lib.mkIf config.steelbore.desktops.gnome.enable {
    # Enable GNOME
    services.xserver.enable = true;
    services.displayManager.gdm.enable = lib.mkDefault false; # Use greetd instead
    # services.displayManager.gdm.wayland removed in GNOME 50 (always Wayland)
    services.desktopManager.gnome.enable = true;

    # GNOME packages
    environment.systemPackages = with pkgs; [
      # Core GNOME utilities
      gnome-tweaks
      dconf-editor

      # Extension management
      gnome-extension-manager
      gnome-browser-connector

      # Extensions
      gnomeExtensions.caffeine
      gnomeExtensions.just-perfection
      gnomeExtensions.window-gestures
      gnomeExtensions.wayland-or-x11
      gnomeExtensions.toggler
      gnomeExtensions.vim-alt-tab
      gnomeExtensions.open-bar
      gnomeExtensions.tweaks-in-system-menu
      gnomeExtensions.launcher
      gnomeExtensions.window-title-is-back
      gnomeExtensions.yakuake
      gnomeExtensions.forge
      # Tiling: forge is THE tiling extension — the three below overlap and
      # conflict when enabled together (elegance plan 4.3). Re-enable one by
      # uncommenting, but disable forge first.
      # gnomeExtensions.tiling-shell   # DISABLED — overlaps forge
      # gnomeExtensions.smart-tiling   # DISABLED — overlaps forge
      # gnomeExtensions.ollama-indicator   # DISABLED — re-enable by uncommenting (Ollama status indicator)
      # gnomeExtensions.simple-tiling   # DISABLED — overlaps forge
      gnomeExtensions.warp-toggle
      gnomeExtensions.resource-monitor
    ];

    # Portal routing — NixOS's services.desktopManager.gnome.enable already
    # registers xdg-desktop-portal-gnome + -gtk in xdg.portal.extraPortals.
    # We add only the explicit per-DE config so multi-DE installs route
    # interfaces deterministically (avoids spillover from another DE's
    # configPackages when GNOME is the active session).
    xdg.portal.config.gnome.default = [
      "gnome"
      "gtk"
    ];

    # Exclude bloat
    environment.gnome.excludePackages = with pkgs; [
      gnome-tour
      gnome-music
      epiphany
      geary
      totem
    ];
  };
}
