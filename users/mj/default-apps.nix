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

  # App-private deep-link schemes. These are NOT handler roles and must not
  # become ones: a role owns a MIME list that several apps could fill, whereas
  # `x-scheme-handler/claude` has exactly one possible handler by construction
  # — the app that minted the scheme. The apps self-register these at launch by
  # rewriting mimeapps.list; declaring them here means the `force = true` below
  # overwrites that file with a superset rather than dropping working deep
  # links on every rebuild. Add an entry only for a scheme whose owning app is
  # installed by a modules/packages bundle.
  selfRegisteredSchemes = {
    "x-scheme-handler/antigravity" = "antigravity.desktop";
    "x-scheme-handler/claude" = "com.anthropic.Claude.desktop";
    "x-scheme-handler/codex" = "chatgpt.desktop";
  };

  mimeBindings = steelboreApps.mimeDefaults // selfRegisteredSchemes;
in
{
  # ═══════════════════════════════════════════════════════════════════════════
  # MIME defaults — ~/.config/mimeapps.list
  # ═══════════════════════════════════════════════════════════════════════════
  # Read by desktop-agnostic xdg-open / xdg-mime and by the portals, so this
  # holds regardless of which of the six session desktops is active. Home
  # Manager owns the file — do NOT hand-edit it, and do not add a second
  # xdg.mimeApps block elsewhere: they merge silently until the day two of
  # them name the same type, which is an evaluation conflict.
  #
  # To change a handler:  app set <role> <slug>   (then `rebuild`)
  # To see the options:   app candidates <role>
  #
  # The bindings are generated from the ROLE's MIME list, never from the
  # application's own MimeType= line. That is the whole point — see the
  # header of lib/default-apps.nix for the x-zerosize case that forced it.
  #
  # `force = true` is load-bearing, not tidiness. Desktop apps rewrite
  # ~/.config/mimeapps.list at runtime through GIO to register their own URL
  # schemes, which replaces HM's symlink with a real file. Without `force`,
  # the next activation displaces that file to mimeapps.list.backup, and the
  # activation AFTER that aborts with "Existing file
  # '…/mimeapps.list.backup' would be clobbered" — a two-rebuild fuse that
  # strands EVERY Home Manager change while `nixos-rebuild` still reports
  # success (see AGENTS.md constraint #30). Same treatment as the cosmic-term
  # profiles, the VSCode Flatpak override and .gtkrc-2.0.
  xdg.configFile."mimeapps.list".force = true;

  xdg.mimeApps = {
    enable = true;
    defaultApplications = mimeBindings;

    # Also register the active handler as an association, so it ranks first
    # in "Open with" menus instead of merely winning silently as the default.
    associations.added = lib.mapAttrs (_: id: [ id ]) mimeBindings;
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
