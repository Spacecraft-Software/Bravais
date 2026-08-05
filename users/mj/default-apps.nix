# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Home Manager: default applications
# The consumer side of lib/default-apps.nix; the active choice is one word per
# role in the repo-root default-apps.nix. Nothing here names an application.
{
  lib,
  pkgs,
  steelboreApps,
  ...
}:

let
  roles = steelboreApps.roles;
  fm = roles.fileManager;

  # Roles whose app is not already carried by a modules/packages bundle
  # install themselves, so a drop-in (apps/majestic.nix) needs no second
  # edit. Built-in catalog entries leave `package` null precisely because a
  # bundle owns them.
  activePackages = map (r: r.package pkgs) (
    builtins.filter (r: r.package != null) (builtins.attrValues roles)
  );
in
{
  # ═══════════════════════════════════════════════════════════════════════════
  # MIME defaults — ~/.config/mimeapps.list
  # ═══════════════════════════════════════════════════════════════════════════
  # Read by desktop-agnostic xdg-open / xdg-mime and by the portals, so this
  # holds regardless of which of the six session desktops is active. Home
  # Manager owns the file (a pre-existing one is displaced to
  # mimeapps.list.backup) — do NOT hand-edit it, and do not add a second
  # xdg.mimeApps block elsewhere: they merge silently until the day two of
  # them name the same type, which is an evaluation conflict.
  #
  # To change a handler:  app set <role> <slug>   (then `rebuild`)
  # To see the options:   app candidates <role>
  #
  # The bindings are generated from the ROLE's MIME list, never from the
  # application's own MimeType= line. That is the whole point — see the
  # header of lib/default-apps.nix for the x-zerosize case that forced it.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = steelboreApps.mimeDefaults;

    # Also register the active handler as an association, so it ranks first
    # in "Open with" menus instead of merely winning silently as the default.
    associations.added = lib.mapAttrs (_: id: [ id ]) steelboreApps.mimeDefaults;
  };

  home.packages = activePackages;

  xdg.dataFile = {
    # ═══════════════════════════════════════════════════════════════════════════
    # D-BUS — org.freedesktop.FileManager1
    # "Show in folder" in Chromium apps (Opera, Chrome, …) — and the portal's
    # OpenURI.OpenDirectory fallback — resolve the file manager by D-Bus
    # activation of org.freedesktop.FileManager1, NOT via the inode/directory
    # mimeapps default above. The GNOME module ships Nautilus's activation file
    # in the system profile, so Nautilus opened instead.
    # dbus-broker scans $XDG_DATA_HOME/dbus-1/services before XDG_DATA_DIRS
    # (first file claiming a name wins), so this user-level file shadows it.
    # cosmic-files-applet claims the bus name and spawns `cosmic-files <uri>`
    # on ShowItems/ShowFolders; it also renders COSMIC desktop icons for
    # ~/Desktop as a transparent layer — invisible while ~/Desktop stays empty.
    # Reload dbus-broker (or re-login) after switch:
    #   systemctl --user reload dbus-broker.service
    # ═══════════════════════════════════════════════════════════════════════════
    "dbus-1/services/org.freedesktop.FileManager1.service" = lib.mkIf (fm.dbusExec != null) {
      text = ''
        [D-BUS Service]
        Name=org.freedesktop.FileManager1
        Exec=${fm.dbusExec pkgs}
      '';
    };
  };
}
