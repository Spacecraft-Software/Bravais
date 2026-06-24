# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Office and Productivity Applications
{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.steelbore.packages.productivity = {
    enable = lib.mkEnableOption "Office and productivity applications";
  };

  config = lib.mkIf config.steelbore.packages.productivity.enable {
    environment.systemPackages = with pkgs; [
      # Knowledge Management (Rust preferred)
      # appflowy → Flatpak: io.appflowy.AppFlowy
      # affine → Flatpak: com.affine.AFFiNE
      nb # CLI note-taking & knowledge base

      # Office Suites — moved to Flatpak (libreoffice-fresh, onlyoffice-desktopeditors)
      # libreoffice-fresh → Flatpak: org.libreoffice.LibreOffice
      # onlyoffice-desktopeditors → Flatpak: org.onlyoffice.desktopeditors

      # Utilities
      # qalculate-gtk

      # Communication (Rust preferred)
      fractal # Rust — Matrix GUI
      newsflash # Rust — RSS reader
      # tutanota-desktop → Flatpak: de.tutao.tutanota
      onedriver # Go — OneDrive
    ];
  };
}
