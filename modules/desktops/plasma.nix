# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — KDE Plasma 6 Desktop Environment (Wayland)
{ config, lib, pkgs, ... }:

{
  options.steelbore.desktops.plasma = {
    enable = lib.mkEnableOption "KDE Plasma 6 Desktop Environment (Wayland)";
  };

  config = lib.mkIf config.steelbore.desktops.plasma.enable {
    # Enable Plasma 6
    services.desktopManager.plasma6.enable = true;
    services.displayManager.sddm.enable = lib.mkDefault false; # Use greetd instead
    services.displayManager.sddm.wayland.enable = lib.mkDefault false;

    # X server required for XWayland support
    services.xserver.enable = true;

    # Avoid askpass conflicts when multiple desktop modules are enabled.
    programs.ssh.askPassword = lib.mkForce "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";

    environment.systemPackages = with pkgs; [
      # kdePackages.plasma-browser-integration
      kdePackages.kdeconnect-kde
      kdePackages.plasma-systemmonitor
      kdePackages.filelight
      kdePackages.kcalc
      kdePackages.ark
      kdePackages.kate
      # kdePackages.xdg-desktop-portal-kde

      # Wallet
      kdePackages.kwalletmanager  # Wallet management GUI
      kdePackages.kwallet         # KWallet daemon
      pinentry-qt                 # GPG pinentry for KDE dialogs

      # Tiling
      kdePackages.krohnkite       # KWin tiling script
    ];

    # Exclude KDE bloat
    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      oxygen
      elisa
      khelpcenter
    ];
  };
}
