# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Home Manager: Plasma Browser Integration hosts for the
# browsers Plasma does not register itself
#
# The extension in each browser talks to Plasma through a native-messaging
# host, found by a manifest named org.kde.plasma.browser_integration.json in
# that browser's NativeMessagingHosts folder. Plasma covers some on its own:
# Firefox from nixpkgs gets the system-wide Mozilla manifest, and Plasma's
# kded FlatpakIntegrator writes manifests for a fixed list of Flatpaks
# (Chrome, Chrome Dev, Chromium, Ungoogled Chromium, Firefox, LibreWolf,
# Waterfox). Brave, Edge and Opera (Flatpak) and BrowserOS (AppImage) are on
# no list, so this file registers them.
#
# Flatpaks: the sandbox cannot run the host binary, so the manifest points at
# a relay inside the app's ~/.var/app/<id> folder. The relay hands its stdio to
# FlatpakIntegrator.Link over D-Bus, and Plasma runs
# plasma-browser-integration-host on the host with those descriptors — the
# same path Plasma's own Chrome relay uses. Verified 2026-10-09 from Brave's
# sandbox: Link started a host process for an app Plasma does not list. The
# matching `org.kde.plasma.browser.integration=talk` permission is in
# modules/packages/flatpak.nix. Both files are copied, not linked: the
# sandbox has no /nix/store, so a Home Manager symlink would dangle there.
#
# Tor Browser is left out on purpose: the integration hands tabs, history and
# media to the desktop, which is exactly what Tor Browser exists to prevent.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  hostName = "org.kde.plasma.browser_integration";

  # The Chrome Web Store and the self-hosted builds of the extension, as
  # Plasma's own Chrome manifest lists them.
  allowedOrigins = [
    "chrome-extension://cimiefiiaegbelhefglklhhakcgmhkai/"
    "chrome-extension://dnnckbejblnejeabhcmhklcaljjpdjeh/"
  ];

  manifest =
    path:
    builtins.toJSON {
      name = hostName;
      description = "Native connector for KDE Plasma";
      inherit path;
      type = "stdio";
      allowed_origins = allowedOrigins;
    };

  # Runs inside the Flatpak, so it uses the runtime's /bin/sh and gdbus.
  # Chromium passes the extension origin as $1. gdbus forwards fds 3/4/5
  # (our stdin/stdout/stderr) to Plasma; its own stdout is discarded so the
  # call's return value never lands on the browser's pipe. The relay then
  # stays alive, because the browser treats its exit as the host closing.
  relay = pkgs.writeText "plasma-browser-integration-relay" ''
    #!/bin/sh
    # Written by Bravais (users/mj/browser-integration.nix). Do not edit.
    set -eu
    [ $# -ge 1 ] || { echo "expected the extension origin as \$1" >&2; exit 1; }
    gdbus call --session \
      --dest org.kde.plasma.browser.integration \
      --object-path /org/kde/plasma/browser/integration \
      --method org.kde.plasma.browser.integration.FlatpakIntegrator.Link \
      "['$1']" 3 4 5 3<&0 4>&1 5>&2 1>/dev/null
    exec sleep infinity
  '';

  # App id → the config folders (under ~/.var/app/<id>/config) whose
  # NativeMessagingHosts the browser reads. Opera gets two: it created
  # config/google-chrome/NativeMessagingHosts itself on first run, which marks
  # Chrome's folder as one it reads, alongside its own `opera` one.
  flatpakBrowsers = {
    "com.brave.Browser" = [ "BraveSoftware/Brave-Browser" ];
    "com.microsoft.Edge" = [ "microsoft-edge" ];
    "com.opera.Opera" = [
      "opera"
      "google-chrome"
    ];
  };

  flatpakManifest =
    appId:
    pkgs.writeText "${hostName}-${appId}.json" (
      manifest "${config.home.homeDirectory}/.var/app/${appId}/plasma-browser-integration-host"
    );

  installFlatpak =
    appId: folders:
    let
      app = "${config.home.homeDirectory}/.var/app/${appId}";
    in
    ''
      # Only once the browser has run: its ~/.var/app folder is created by
      # Flatpak on first launch, and the next activation picks it up.
      if [ -d "${app}" ]; then
        run install -Dm755 ${relay} "${app}/plasma-browser-integration-host"
        ${lib.concatMapStrings (folder: ''
          run install -Dm644 ${flatpakManifest appId} "${app}/config/${folder}/NativeMessagingHosts/${hostName}.json"
        '') folders}
      fi
    '';
in
{
  home.activation.plasmaBrowserIntegrationFlatpak = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    lib.concatStrings (lib.mapAttrsToList installFlatpak flatpakBrowsers)
  );

  # BrowserOS runs in a bubblewrap FHS environment that bind-mounts /nix, so
  # its manifest can point straight at the store path and stay a plain link.
  # Its profile is ~/.config/browser-os, which is where Chromium-family
  # browsers look for their user-level NativeMessagingHosts folder.
  xdg.configFile."browser-os/NativeMessagingHosts/${hostName}.json".text = manifest (
    lib.getExe' pkgs.kdePackages.plasma-browser-integration "plasma-browser-integration-host"
  );
}
