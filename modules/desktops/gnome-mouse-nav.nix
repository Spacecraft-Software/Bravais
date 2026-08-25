# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — mouse side-button workspace navigation under GNOME
#
# The two thumb buttons switch workspaces under Niri because niri's bind syntax
# has first-class mouse button names (MouseBack/MouseForward). GNOME has no
# such thing: Mutter's keybinding schemas — org.gnome.desktop.wm.keybindings —
# accept KEYBOARD ACCELERATORS ONLY, and no GNOME extension in nixpkgs binds
# side buttons (gnomeExtensions.panel-scroll only handles scroll on the panel).
# Under Wayland an extension cannot reliably grab pointer buttons over an
# application window either. So the remap has to happen BELOW the compositor,
# at the evdev layer, turning the buttons into a keystroke GNOME already knows.
#
# GNOME is already horizontal: switch-to-workspace-left/-right are the real
# actions and ship bound to <Control><Alt>Left/Right, which Mutter grabs
# globally. Emitting those exact combos is why this module needs no dconf
# settings at all — and why no application can observe them, since the grab
# takes them first.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.steelbore.desktops.gnomeMouseNav;

  # BTN_ is the one prefix xremap requires; KEY_ is the optional one.
  # `C-` is Ctrl and `M-` is Alt (xremap's modifier aliases).
  xremapConfig = pkgs.writeText "steelbore-gnome-mouse-nav.yml" ''
    keymap:
      - name: Mouse side buttons -> horizontal workspace switch
        remap:
          BTN_SIDE: C-M-left
          BTN_EXTRA: C-M-right
  '';
in
{
  options.steelbore.desktops.gnomeMouseNav = {
    enable = lib.mkEnableOption "mouse side-button workspace navigation under GNOME (via xremap)";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.steelbore.desktops.gnome.enable;
        message = ''
          steelbore.desktops.gnomeMouseNav requires steelbore.desktops.gnome.enable = true —
          it emits <Control><Alt>Left/Right, which only means "switch workspace" to Mutter.
        '';
      }
    ];

    # Creates the `uinput` group, loads the kernel module, and installs the
    # udev rule that grants that group /dev/uinput. xremap cannot create its
    # virtual output device without it. The primary user must be IN the group —
    # see users/mj/default.nix; `input` (already there) only covers READING
    # /dev/input/event*.
    hardware.uinput.enable = true;

    # Plain `pkgs.xremap`, which is the `wlroots` variant, and that is CORRECT
    # here despite the store path reading `xremap-wlroots` under GNOME. The
    # variant selects only the window-detection client used to resolve
    # `application:`/`window:` conditions in a keymap. Upstream constructs that
    # client lazily -- `Client::supported()` is documented as "called very late,
    # i.e. the first time xremap wants some information", and the only callers
    # are `current_window()`/`current_application()`. This keymap has no such
    # conditions, so the client is never consulted and the wlroots protocol is
    # never bound. Overriding to `withVariant = "gnome"` would name it more
    # honestly but implies a dependency we do not have: that client talks to the
    # xremap GNOME Shell extension, which is not installed and is not needed.
    environment.systemPackages = [ pkgs.xremap ];

    # Scoped to GNOME by construction. gnome-session-initialized.target is
    # started only by a GNOME session, so Niri, LeftWM, Plasma and COSMIC never
    # pull this unit in and their side buttons keep doing browser back/forward.
    # That scoping is the whole design: a system-wide remapper would swallow
    # these buttons before niri ever saw them, breaking the native binds in
    # users/mj/niri.nix and killing back/forward everywhere at once. Do not
    # promote this to a system service or a graphical-session.target unit.
    #
    # BLAST RADIUS, because it is not obvious from the config: xremap EVIOCGRABs
    # every device it listens to and re-emits through its own virtual device, so
    # while this unit runs ALL keyboard and mouse input is proxied through it.
    # The kernel releases the grabs when the process dies and Restart=on-failure
    # brings it back, so a crash costs a keystroke rather than the session.
    # To narrow it to a single device later, add `--device` — run
    # `xremap --device-details` to see the names. Deliberately not hardcoded
    # here: a device name breaks the moment a different mouse is plugged in.
    #
    # --watch=device matters on a laptop. Without it a Bluetooth mouse that
    # reconnects after suspend is never picked up, and the buttons silently
    # stop working until the unit is restarted.
    systemd.user.services.steelbore-gnome-mouse-nav = {
      description = "Steelbore mouse side-button workspace navigation (GNOME)";
      partOf = [ "gnome-session-initialized.target" ];
      after = [ "gnome-session-initialized.target" ];
      wantedBy = [ "gnome-session-initialized.target" ];
      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.xremap} --mouse --watch=device ${xremapConfig}";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
