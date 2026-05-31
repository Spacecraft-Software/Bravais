# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Web Browsers
{ config, lib, pkgs, ... }:

{
  options.steelbore.packages.browsers = {
    enable = lib.mkEnableOption "Web browsers";
  };

  config = lib.mkIf config.steelbore.packages.browsers.enable {
    # Firefox (system-managed)
    programs.firefox.enable = true;

    environment.systemPackages = with pkgs; [
      google-chrome
      # brave → Flatpak: com.brave.Browser (Chromium source build, too large for march configs)
      # librewolf → Flatpak: io.gitlab.librewolf-community.librewolf (Firefox source build)
    ];
  };
}
