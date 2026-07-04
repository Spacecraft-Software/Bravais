# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Web Browsers
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # BrowserOS — agentic, Chromium-based browser shipped only as an x64 AppImage.
  # Wrapped with appimageTools.wrapType2 so it runs reproducibly from the Nix store
  # (FHS env + FUSE) instead of as a loose binfmt AppImage in ~/Applications/.
  # Update procedure: run `nu pkgs/update-vendored.nu browseros` (plan 5.1) —
  # or by hand: bump version, swap the URL, then refresh the hash with
  #   nix store prefetch-file --hash-type sha256 <url>
  browserosVersion = "0.46.0";
  browseros = pkgs.appimageTools.wrapType2 {
    pname = "browseros";
    version = browserosVersion;
    src = pkgs.fetchurl {
      url = "https://github.com/browseros-ai/BrowserOS/releases/download/v${browserosVersion}/BrowserOS_v${browserosVersion}_x64.AppImage";
      hash = "sha256-IV3Agg5i4TKDMQy+BjNbW6sqPsLfPcSOQkOADHhSmTw=";
    };
  };
in
{
  options.steelbore.packages.browsers = {
    enable = lib.mkEnableOption "Web browsers";
  };

  config = lib.mkIf config.steelbore.packages.browsers.enable {
    # Firefox (system-managed) → Flatpak: org.mozilla.firefox
    # programs.firefox.enable = true;

    environment.systemPackages = with pkgs; [
      browseros # Chromium/AppImage -- Agentic browser (appimageTools.wrapType2)

      # google-chrome → Flatpak: com.google.Chrome
      # brave → Flatpak: com.brave.Browser (Chromium source build, too large for march configs)
      # librewolf → Flatpak: io.gitlab.librewolf-community.librewolf (Firefox source build)
    ];
  };
}
