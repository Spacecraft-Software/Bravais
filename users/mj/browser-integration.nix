# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Home Manager: Plasma Browser Integration and GNOME
# Browser Connector hosts for Flatpak and AppImage browsers
#
# Both desktop browser extensions talk to the host through a native-messaging
# host manifest in that browser's NativeMessagingHosts folder:
#   - KDE Plasma: org.kde.plasma.browser_integration.json
#   - GNOME Shell: org.gnome.browser_connector.json (plus legacy
#     org.gnome.chrome_gnome_shell.json)
#
# Firefox from nixpkgs gets the system-wide Mozilla manifests from both
# modules. For Chromium-family browsers:
#   - Plasma's kded FlatpakIntegrator writes manifests for a fixed list of
#     Flatpaks (Chrome, Chrome Dev, Chromium, Ungoogled Chromium, Firefox,
#     LibreWolf, Waterfox), leaving Brave, Edge and Opera (Flatpak) and
#     BrowserOS (AppImage) uncovered.
#   - GNOME's gnome-browser-connector only writes /etc/opt/chrome and
#     /etc/chromium on the host and has no FlatpakIntegrator at all, so NONE of
#     the four Flatpak browsers (Chrome, Brave, Edge, Opera) or BrowserOS find
#     it ("Although GNOME Shell integration extension is running, native host
#     connector is not detected").
#
# Flatpaks: the sandbox cannot run the host binary (and lacks /nix/store and
# the org.gnome.shell GSettings schema), so the manifest points at a relay
# inside the app's ~/.var/app/<id> folder. The relay hands its stdio fds (3/4/5)
# over D-Bus to FlatpakIntegrator.Link on the host:
#   - Plasma: org.kde.plasma.browser.integration (built into kded)
#   - GNOME:  org.gnome.BrowserConnector.FlatpakIntegrator (D-Bus-activated
#     host service defined below, which spawns gnome-browser-connector-host)
# The matching `=talk` session-bus permissions are in
# modules/packages/flatpak.nix. Both files are copied, not linked: the
# sandbox has no /nix/store, so a Home Manager symlink would dangle there.
#
# Tor Browser is left out on purpose: desktop integration hands tabs, history
# and media to the desktop, which is what Tor Browser exists to prevent.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # ── KDE Plasma Browser Integration ─────────────────────────────────────────
  plasmaHostName = "org.kde.plasma.browser_integration";

  # The Chrome Web Store and the self-hosted builds of the extension, as
  # Plasma's own Chrome manifest lists them.
  plasmaAllowedOrigins = [
    "chrome-extension://cimiefiiaegbelhefglklhhakcgmhkai/"
    "chrome-extension://dnnckbejblnejeabhcmhklcaljjpdjeh/"
  ];

  plasmaManifest =
    path:
    builtins.toJSON {
      name = plasmaHostName;
      description = "Native connector for KDE Plasma";
      inherit path;
      type = "stdio";
      allowed_origins = plasmaAllowedOrigins;
    };

  # Runs inside the Flatpak, so it uses the runtime's /bin/sh and gdbus.
  # Chromium passes the extension origin as $1. gdbus forwards fds 3/4/5
  # (our stdin/stdout/stderr) to Plasma; its own stdout is discarded so the
  # call's return value never lands on the browser's pipe. The relay then
  # stays alive, because the browser treats its exit as the host closing.
  plasmaRelay = pkgs.writeText "plasma-browser-integration-relay" ''
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
  plasmaFlatpakBrowsers = {
    "com.brave.Browser" = [ "BraveSoftware/Brave-Browser" ];
    "com.microsoft.Edge" = [ "microsoft-edge" ];
    "com.opera.Opera" = [
      "opera"
      "google-chrome"
    ];
  };

  plasmaFlatpakManifest =
    appId:
    pkgs.writeText "${plasmaHostName}-${appId}.json" (
      plasmaManifest "${config.home.homeDirectory}/.var/app/${appId}/plasma-browser-integration-host"
    );

  installPlasmaFlatpak =
    appId: folders:
    let
      app = "${config.home.homeDirectory}/.var/app/${appId}";
    in
    ''
      # Only once the browser has run: its ~/.var/app folder is created by
      # Flatpak on first launch, and the next activation picks it up.
      if [ -d "${app}" ]; then
        run install -Dm755 ${plasmaRelay} "${app}/plasma-browser-integration-host"
        ${lib.concatMapStrings (folder: ''
          run install -Dm644 ${plasmaFlatpakManifest appId} "${app}/config/${folder}/NativeMessagingHosts/${plasmaHostName}.json"
        '') folders}
      fi
    '';

  # ── GNOME Browser Connector ────────────────────────────────────────────────
  # Upstream ships both manifest names (current + legacy Chrome Web Store ID).
  gnomeHostNames = [
    "org.gnome.browser_connector"
    "org.gnome.chrome_gnome_shell"
  ];

  gnomeAllowedOrigins = [
    "chrome-extension://gphhapmejobijbbhgpjhcjognlahblep/"
  ];

  gnomeBusName = "org.gnome.BrowserConnector.FlatpakIntegrator";
  gnomeObjectPath = "/org/gnome/BrowserConnector/FlatpakIntegrator";
  gnomeHostBin = lib.getExe' pkgs.gnome-browser-connector "gnome-browser-connector-host";

  gnomeManifest =
    name: path:
    builtins.toJSON {
      inherit name path;
      description = "OS-native connector counterpart for GNOME Shell browser extension";
      type = "stdio";
      allowed_origins = gnomeAllowedOrigins;
    };

  gnomeRelay = pkgs.writeText "gnome-browser-connector-relay" ''
    #!/bin/sh
    # Written by Bravais (users/mj/browser-integration.nix). Do not edit.
    set -eu
    [ $# -ge 1 ] || { echo "expected the extension origin as \$1" >&2; exit 1; }
    gdbus call --session \
      --dest ${gnomeBusName} \
      --object-path ${gnomeObjectPath} \
      --method ${gnomeBusName}.Link \
      "['$1']" 3 4 5 3<&0 4>&1 5>&2 1>/dev/null
    exec sleep infinity </dev/null >/dev/null 2>&1
  '';

  gnomeIntegratorPy = pkgs.writeText "gnome-browser-connector-integrator.py" ''
    # SPDX-License-Identifier: GPL-3.0-or-later
    from __future__ import annotations

    import os
    import subprocess
    import sys
    from typing import Any

    from gi.repository import Gio, GLib

    BUS_NAME: str = "${gnomeBusName}"
    OBJECT_PATH: str = "${gnomeObjectPath}"
    HOST_BIN: str = "${gnomeHostBin}"
    ALLOWED_ORIGINS: frozenset[str] = frozenset(${builtins.toJSON gnomeAllowedOrigins})

    INTERFACE_XML: str = """
    <node>
      <interface name="${gnomeBusName}">
        <method name="Link">
          <arg type="as" name="args" direction="in"/>
          <arg type="h" name="stdin" direction="in"/>
          <arg type="h" name="stdout" direction="in"/>
          <arg type="h" name="stderr" direction="in"/>
        </method>
      </interface>
    </node>
    """


    class IntegratorService:
        __slots__ = ("_children", "_idle_source", "_loop", "_node_info")

        def __init__(self) -> None:
            self._loop: GLib.MainLoop = GLib.MainLoop()
            self._node_info: Gio.DBusNodeInfo = Gio.DBusNodeInfo.new_for_xml(INTERFACE_XML)
            self._children: list[subprocess.Popen[bytes]] = []
            self._idle_source: int | None = None
            self._reset_idle_timer()

        def _reset_idle_timer(self) -> None:
            if self._idle_source is not None:
                GLib.source_remove(self._idle_source)
            self._idle_source = GLib.timeout_add_seconds(60, self._on_idle_timeout)

        def _on_idle_timeout(self) -> bool:
            self._children = [proc for proc in self._children if proc.poll() is None]
            if not self._children:
                self._idle_source = None
                self._loop.quit()
                return GLib.SOURCE_REMOVE
            return GLib.SOURCE_CONTINUE

        def on_bus_acquired(self, conn: Gio.DBusConnection, _name: str) -> None:
            conn.register_object(
                OBJECT_PATH,
                self._node_info.interfaces[0],
                self.on_method_call,
                None,
                None,
            )

        def on_name_lost(self, _conn: Gio.DBusConnection | None, _name: str) -> None:
            self._loop.quit()

        def on_method_call(
            self,
            _conn: Gio.DBusConnection,
            _sender: str,
            _object_path: str,
            _interface_name: str,
            method_name: str,
            parameters: GLib.Variant,
            invocation: Gio.DBusMethodInvocation,
        ) -> None:
            if method_name != "Link":
                invocation.return_dbus_error(
                    "org.freedesktop.DBus.Error.UnknownMethod",
                    f"Unknown method: {method_name}",
                )
                return

            fd_list: Gio.UnixFDList | None = invocation.get_message().get_unix_fd_list()
            if fd_list is None:
                invocation.return_dbus_error(
                    "org.freedesktop.DBus.Error.InvalidArgs",
                    "Missing UnixFDList",
                )
                return

            unpacked: tuple[list[str], int, int, int] = parameters.unpack()
            args, in_idx, out_idx, err_idx = unpacked
            if not args or args[0] not in ALLOWED_ORIGINS:
                invocation.return_dbus_error(
                    "org.freedesktop.DBus.Error.AccessDenied",
                    "Disallowed extension origin",
                )
                return

            fd_in: int = fd_list.get(in_idx)
            fd_out: int = fd_list.get(out_idx)
            fd_err: int = fd_list.get(err_idx)
            try:
                proc: subprocess.Popen[bytes] = subprocess.Popen(
                    [HOST_BIN, args[0]],
                    stdin=fd_in,
                    stdout=fd_out,
                    stderr=fd_err,
                    close_fds=True,
                )
                self._children.append(proc)
                self._reset_idle_timer()
            except OSError as exc:
                invocation.return_dbus_error(
                    "org.freedesktop.DBus.Error.Spawn.Failed",
                    str(exc),
                )
                return
            finally:
                os.close(fd_in)
                os.close(fd_out)
                os.close(fd_err)

            invocation.return_value(None)

        def run(self) -> int:
            owner_id: int = Gio.bus_own_name(
                Gio.BusType.SESSION,
                BUS_NAME,
                Gio.BusNameOwnerFlags.NONE,
                self.on_bus_acquired,
                None,
                self.on_name_lost,
            )
            try:
                self._loop.run()
            finally:
                Gio.bus_unown_name(owner_id)
            return 0


    if __name__ == "__main__":
        sys.exit(IntegratorService().run())
  '';

  gnomeIntegrator = pkgs.writeShellScript "gnome-browser-connector-integrator" ''
    export GI_TYPELIB_PATH="${pkgs.glib.out}/lib/girepository-1.0:${pkgs.gobject-introspection}/lib/girepository-1.0"
    exec ${pkgs.python3.withPackages (ps: [ ps.pygobject3 ])}/bin/python3 ${gnomeIntegratorPy}
  '';

  # Chrome is included here because GNOME has no kded-style FlatpakIntegrator
  # writing into ~/.var/app/com.google.Chrome on its own.
  gnomeFlatpakBrowsers = {
    "com.google.Chrome" = [ "google-chrome" ];
    "com.brave.Browser" = [ "BraveSoftware/Brave-Browser" ];
    "com.microsoft.Edge" = [ "microsoft-edge" ];
    "com.opera.Opera" = [
      "opera"
      "google-chrome"
    ];
  };

  gnomeFlatpakManifest =
    name: appId:
    pkgs.writeText "${name}-${appId}.json" (
      gnomeManifest name "${config.home.homeDirectory}/.var/app/${appId}/gnome-browser-connector-host"
    );

  installGnomeFlatpak =
    appId: folders:
    let
      app = "${config.home.homeDirectory}/.var/app/${appId}";
    in
    ''
      if [ -d "${app}" ]; then
        run install -Dm755 ${gnomeRelay} "${app}/gnome-browser-connector-host"
        ${lib.concatMapStrings (
          folder:
          lib.concatMapStrings (name: ''
            run install -Dm644 ${gnomeFlatpakManifest name appId} "${app}/config/${folder}/NativeMessagingHosts/${name}.json"
          '') gnomeHostNames
        ) folders}
      fi
    '';
in
{
  home.activation.plasmaBrowserIntegrationFlatpak = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    lib.concatStrings (lib.mapAttrsToList installPlasmaFlatpak plasmaFlatpakBrowsers)
    + lib.concatStrings (lib.mapAttrsToList installGnomeFlatpak gnomeFlatpakBrowsers)
  );

  xdg.dataFile."dbus-1/services/${gnomeBusName}.service".text = ''
    [D-BUS Service]
    Name=${gnomeBusName}
    Exec=${gnomeIntegrator}
  '';

  # BrowserOS runs in a bubblewrap FHS environment that bind-mounts /nix, so
  # its manifests can point straight at the store paths and stay plain links.
  # Its profile is ~/.config/browser-os, which is where Chromium-family
  # browsers look for their user-level NativeMessagingHosts folder.
  xdg.configFile = {
    "browser-os/NativeMessagingHosts/${plasmaHostName}.json".text = plasmaManifest (
      lib.getExe' pkgs.kdePackages.plasma-browser-integration "plasma-browser-integration-host"
    );
    "browser-os/NativeMessagingHosts/org.gnome.browser_connector.json".text =
      gnomeManifest "org.gnome.browser_connector" gnomeHostBin;
    "browser-os/NativeMessagingHosts/org.gnome.chrome_gnome_shell.json".text =
      gnomeManifest "org.gnome.chrome_gnome_shell" gnomeHostBin;
  };
}
