# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Home Manager: GNOME Shell keybindings (Super alone,
# Super+D search, workspace switching)
{
  lib,
  pkgs,
  ...
}:

let
  # Super alone opens the app grid instead of the window overview. GNOME has
  # no setting for this: mutter's `overlay-key` only names the key, and the
  # shell always answers it with Overview.toggle(). This extension replaces
  # toggle() so a closed overview opens straight into the app grid
  # (showApps()); an open one still closes. The same path serves the
  # Activities button and the hot corner, so they open the grid too.
  # Super+D (FocusSearch) calls show(), not toggle(), so it is unaffected.
  # Installed by modules/desktops/gnome.nix.
  appGridUuid = pkgs.gnomeExtensions.start-overlay-in-application-view.extensionUuid;

  dconf = lib.getExe pkgs.dconf;
in
{
  dconf.settings = {
    # ── Super+D → search, as Mod+D is the launcher under Niri, LeftWM, Margo
    # and (PR #151) Plasma. This is Settings › Keyboard › Shortcuts ›
    # Launchers › Search: gnome-settings-daemon opens the overview with the
    # search entry focused. Unbound by default (only the XF86Search key is),
    # and nothing else in GNOME 50 claims Super+D (show-desktop is unbound).
    "org/gnome/settings-daemon/plugins/media-keys" = {
      search = [ "<Super>d" ];
    };

    # ── GNOME: accept the combo the side-button remap emits ─────────────────
    # modules/desktops/mouse-workspace-nav.nix turns BTN_SIDE/BTN_EXTRA into
    # Super+Ctrl+Left/Right. Plasma and COSMIC already bind exactly that for
    # this action out of the box; GNOME does not, so it is added here ALONGSIDE
    # the stock accelerators rather than replacing them — these keys are lists,
    # so every stock entry (gsettings-desktop-schemas 50) is restated before
    # the addition.
    "org/gnome/desktop/wm/keybindings" = {
      switch-to-workspace-left = [
        "<Super>Page_Up"
        "<Super>KP_Prior"
        "<Super><Alt>Left"
        "<Control><Alt>Left"
        "<Super><Control>Left"
      ];
      switch-to-workspace-right = [
        "<Super>Page_Down"
        "<Super>KP_Next"
        "<Super><Alt>Right"
        "<Control><Alt>Right"
        "<Super><Control>Right"
      ];
    };
  };

  # The app-grid extension has to be listed in `enabled-extensions` to load.
  # That list also holds every extension enabled by hand in Extension Manager,
  # so it cannot be a dconf.settings value (which would replace the whole
  # list): this appends the one UUID when it is missing and leaves the rest
  # alone. Turning the extension off in Extension Manager lasts until the next
  # rebuild. A write goes through the session bus when there is one and
  # dbus-run-session otherwise, as HM's own dconfSettings step does; a read
  # needs no bus, as dconf reads the database file directly.
  home.activation.gnomeAppGridExtension = lib.hm.dag.entryAfter [ "dconfSettings" ] ''
    if [[ -v DBUS_SESSION_BUS_ADDRESS ]]; then
      appGridDbus=""
    else
      appGridDbus="${pkgs.dbus}/bin/dbus-run-session --dbus-daemon=${pkgs.dbus}/bin/dbus-daemon"
    fi
    appGridKey=/org/gnome/shell/enabled-extensions
    appGridList=$(${dconf} read "$appGridKey" || true)
    case "$appGridList" in
      *"'${appGridUuid}'"*) ;;
      "" | "@as []" | "[]")
        run $appGridDbus ${dconf} write "$appGridKey" "['${appGridUuid}']" ;;
      *)
        run $appGridDbus ${dconf} write "$appGridKey" "''${appGridList%]}, '${appGridUuid}']" ;;
    esac
    unset appGridDbus appGridKey appGridList
  '';
}
