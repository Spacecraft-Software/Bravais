# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Web Browsers
{
  config,
  lib,
  pkgs,
  unstablePkgs,
  ...
}:

let
  # BrowserOS — agentic, Chromium-based browser shipped only as an x64 AppImage.
  # Wrapped with appimageTools.wrapType2 so it runs reproducibly from the Nix store
  # (FHS env + FUSE) instead of as a loose binfmt AppImage in ~/Applications/.
  # Update procedure: run `nu pkgs/update-vendored.nu browseros` (plan 5.1) —
  # or by hand: bump version, swap the URL, then refresh the hash with
  #   nix store prefetch-file --hash-type sha256 <url>
  browserosVersion = "0.47.18";
  browseros = pkgs.appimageTools.wrapType2 {
    pname = "browseros";
    version = browserosVersion;
    src = pkgs.fetchurl {
      url = "https://github.com/browseros-ai/BrowserOS/releases/download/v${browserosVersion}/BrowserOS_v${browserosVersion}_x64.AppImage";
      hash = "sha256-j17ERzRxTx/0OaKtSjp02DXi132Rfz9qse5uI7auu7s=";
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

    environment.systemPackages =
      (with pkgs; [
        browseros # Chromium/AppImage -- Agentic browser (appimageTools.wrapType2)

        # google-chrome → Flatpak: com.google.Chrome
        # brave → Flatpak: com.brave.Browser (Chromium source build, too large for march configs)
        # librewolf → Flatpak: io.gitlab.librewolf-community.librewolf (Firefox source build)
      ])
      # Tor Browser is the one browser here that stays in nixpkgs rather than
      # going to Flatpak: the derivation repacks the Tor Project's official
      # prebuilt `tor-browser-linux-x86_64-*.tar.xz`, so it is not a Firefox
      # source build and substitutes from cache.nixos.org — the "too large for
      # march configs" exception simply does not apply.
      #
      # From `unstablePkgs` deliberately. Point releases carry the Firefox-ESR
      # security patches, and an out-of-date Tor Browser is an anonymity
      # problem, not just a stale app — so the usual "stable lags meaningfully"
      # rule binds harder here than anywhere else in this file.
      #
      # The bundled updater is off (`policies.DisableAppUpdate = true` upstream,
      # unavoidable for a read-only store), so `nix flake update
      # nixpkgs-unstable` is the ONLY thing that moves this version. It is not a
      # `pkgs/update-vendored.nu` package — there is no version/hash pinned in
      # this tree to bump.
      #
      # Not wired into `default-apps.nix`: making it the `webBrowser` role would
      # push every link click through Tor, which is a different product than
      # having Tor Browser installed.
      ++ (with unstablePkgs; [
        tor-browser # Firefox/bundle -- Anonymity browser over the Tor network
      ]);
  };
}
