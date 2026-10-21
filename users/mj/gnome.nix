# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Home Manager: GNOME Shell keybindings (Super alone,
# Super+D search, and the keys every Bravais session shares —
# docs/keybindings.md)
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

  # Super+Return → terminal, as Mod+Return under Niri, LeftWM and Margo. A
  # custom shortcut lives at its own dconf path, which GNOME finds only
  # through the `custom-keybindings` list — appended below, like the
  # extension, so shortcuts made in Settings survive.
  terminalPath = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/steelbore-terminal/";

  dconf = lib.getExe pkgs.dconf;

  digits = lib.range 1 9;
  perDigit = f: lib.listToAttrs (map f digits);

  # Appends ITEM to the string-list key KEY unless it is already there,
  # leaving every other entry alone.
  appendToList = key: item: ''
    stbList=$(${dconf} read "${key}" || true)
    case "$stbList" in
      *"'${item}'"*) ;;
      "" | "@as []" | "[]")
        run $stbDbus ${dconf} write "${key}" "['${item}']" ;;
      *)
        run $stbDbus ${dconf} write "${key}" "''${stbList%]}, '${item}']" ;;
    esac
  '';
in
{
  dconf.settings = {
    "org/gnome/settings-daemon/plugins/media-keys" = {
      # ── Super+D → search, as Mod+D is the launcher everywhere else. This is
      # Settings › Keyboard › Shortcuts › Launchers › Search:
      # gnome-settings-daemon opens the overview with the search entry
      # focused. Unbound by default (only the XF86Search key is), and nothing
      # else in GNOME 50 claims Super+D (show-desktop is unbound).
      search = [ "<Super>d" ];
      # Lock: Super+L (stock) plus Super+Shift+L, the key Niri, LeftWM and
      # Margo use (they need Super+L to focus right).
      screensaver = [
        "<Super>l"
        "<Super><Shift>l"
      ];
    };

    ${lib.removePrefix "/" (lib.removeSuffix "/" terminalPath)} = {
      name = "Terminal (Alacritty)";
      command = "alacritty";
      binding = "<Super>Return";
    };

    # The Forge tiling extension (installed by modules/desktops/gnome.nix)
    # ships defaults on four of the shared keys: Super+Return (swap with the
    # last active window), Super+V (vertical split), Super+Shift+C (always
    # float) and Super+Shift+L (move window right). An extension's grab wins
    # over gnome-settings-daemon's, so once Forge is enabled in Extension
    # Manager those four did nothing, or the wrong thing. They are left with
    # no key; Forge's other keys (Super+H/J/K/L focus, Super+Ctrl+H/J/K/L
    # swap, Super+W, ...) stay.
    "org/gnome/shell/extensions/forge/keybindings" = {
      window-swap-last-active = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
      con-split-vertical = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
      window-toggle-always-float = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
      window-move-right = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
    };

    # O-tiling (installed by hand from extensions.gnome.org, not by this
    # flake) ships "enter tiling mode" on Super+Return and Super+KP_Enter and
    # "toggle floating" on Super+F. Its grab wins over gnome-settings-daemon's,
    # so Super+Return never reached Alacritty and Super+F never went
    # fullscreen. Both are left with no key; its other keys stay. Writing the
    # dconf path is harmless while the extension is absent.
    "org/gnome/shell/extensions/o-tiling" = {
      tile-enter = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
      toggle-floating = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
    };

    # Caffeine: Super+Shift+C, as in every other session. The extension ships
    # the key unbound.
    "org/gnome/shell/extensions/caffeine" = {
      toggle-shortcut = [ "<Super><Shift>c" ];
    };

    # Super+1-9 switches workspace, as in every other session. GNOME gives
    # that key to "open the Nth dock app"; those are left with no key (the
    # dock itself still works by mouse). Super+Ctrl+1-9 ("new window of the
    # Nth dock app") stays. Workspaces are dynamic, so a number past the last
    # workspace does nothing.
    "org/gnome/shell/keybindings" =
      perDigit (n: {
        name = "switch-to-application-${toString n}";
        value = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
      })
      // {
        # Super+Print captures the focused window, as under Niri and Plasma;
        # Alt+Print (stock) still does.
        screenshot-window = [
          "<Alt>Print"
          "<Super>Print"
        ];
        # Super+Shift+D opens the app grid, as it opens the app menu in
        # every other session; Super+A (stock) and Super alone (the
        # extension above) still do. Nothing in GNOME 50 claims it.
        toggle-application-view = [
          "<Super>a"
          "<Super><Shift>d"
        ];
      };

    "org/gnome/desktop/wm/keybindings" =
      perDigit (
        n:
        let
          i = toString n;
        in
        {
          name = "switch-to-workspace-${i}";
          # Super+Home stays on workspace 1 (stock).
          value = lib.optional (n == 1) "<Super>Home" ++ [ "<Super>${i}" ];
        }
      )
      // perDigit (
        n:
        let
          i = toString n;
        in
        {
          name = "move-to-workspace-${i}";
          value = lib.optional (n == 1) "<Super><Shift>Home" ++ [ "<Super><Shift>${i}" ];
        }
      )
      // {
        # Super+Q closes, Alt+F4 still does. Super+F toggles fullscreen
        # (unbound in stock GNOME).
        close = [
          "<Super>q"
          "<Alt>F4"
        ];
        toggle-fullscreen = [ "<Super>f" ];

        # ── Accept the combo the side-button remap emits ───────────────────
        # modules/desktops/mouse-workspace-nav.nix turns BTN_SIDE/BTN_EXTRA
        # into Super+Ctrl+Left/Right. Plasma and COSMIC already bind exactly
        # that for this action out of the box; GNOME does not, so it is added
        # here ALONGSIDE the stock accelerators rather than replacing them —
        # these keys are lists, so every stock entry (gsettings-desktop-schemas
        # 50) is restated before the addition.
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

  # The app-grid extension has to be listed in `enabled-extensions` to load,
  # and the terminal shortcut in `custom-keybindings`. Both lists also hold
  # what was added by hand (Extension Manager, Settings › Keyboard), so
  # neither can be a dconf.settings value (which would replace the whole
  # list): this appends the one entry each when it is missing and leaves the
  # rest alone. Turning the extension off in Extension Manager lasts until the
  # next rebuild. A write goes through the session bus when there is one and
  # dbus-run-session otherwise, as HM's own dconfSettings step does; a read
  # needs no bus, as dconf reads the database file directly.
  home.activation.gnomeListEntries = lib.hm.dag.entryAfter [ "dconfSettings" ] ''
    if [[ -v DBUS_SESSION_BUS_ADDRESS ]]; then
      stbDbus=""
    else
      stbDbus="${pkgs.dbus}/bin/dbus-run-session --dbus-daemon=${pkgs.dbus}/bin/dbus-daemon"
    fi
    ${appendToList "/org/gnome/shell/enabled-extensions" appGridUuid}
    ${appendToList "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings" terminalPath}
    unset stbDbus stbList
  '';
}
