# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — mouse side-button workspace navigation
#
# The two thumb buttons (BTN_SIDE/BTN_EXTRA) switch workspaces left/right.
#
# Niri can express this natively — its bind syntax has first-class mouse button
# names — and therefore does NOT go through this module; see users/mj/niri.nix.
# Nothing else can. Mutter's keybinding schemas, KWin's shortcuts and cosmic's
# RON bindings all accept KEYBOARD ACCELERATORS ONLY, and no GNOME extension in
# nixpkgs binds side buttons (gnomeExtensions.panel-scroll is scroll-on-the-panel
# only). Under Wayland an extension cannot reliably grab pointer buttons over an
# application window either. So the remap happens BELOW the compositor, at the
# evdev layer, turning the buttons into a keystroke each desktop already knows.
#
# WHY Super+Ctrl+Left/Right AND NOT Ctrl+Alt: it is already the DEFAULT for this
# exact action in two of the three desktops served here —
#   Plasma  `Switch One Desktop to the Left`  = Meta+Ctrl+Left   (kglobalshortcutsrc)
#   COSMIC  `(modifiers: [Super, Ctrl], key: "Left"): PreviousWorkspace`
#           (cosmic-comp's shipped .../Shortcuts/v1/defaults)
# so only GNOME needs a binding added, in users/mj/desktop-theme.nix. Emitting
# GNOME's own Ctrl+Alt+Left/Right instead would have meant editing Plasma AND
# COSMIC. Do not "simplify" this back to Ctrl+Alt without re-checking those two
# defaults.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.steelbore.desktops.mouseWorkspaceNav;

  # BTN_ is the one prefix xremap requires; KEY_ is the optional one.
  # Modifier aliases: `SUPER` (aka WIN/W) and `C` (aka CTRL).
  xremapConfig = pkgs.writeText "steelbore-mouse-workspace-nav.yml" ''
    keymap:
      - name: Mouse side buttons -> workspace left/right
        remap:
          BTN_SIDE: SUPER-C-left
          BTN_EXTRA: SUPER-C-right
  '';

  # Shared by the systemd unit and by the LeftWM theme hook, which cannot use a
  # unit at all (see below). One definition so the two can never drift.
  xremapCommand = "${lib.getExe pkgs.xremap} --mouse --watch=device ${xremapConfig}";
in
{
  options.steelbore.desktops.mouseWorkspaceNav = {
    enable = lib.mkEnableOption "mouse side-button workspace navigation (via xremap)";

    command = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = xremapCommand;
      description = ''
        The xremap invocation, exposed so sessions that cannot use a systemd
        user unit (LeftWM, which is startx-based) can start the same process.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          config.steelbore.desktops.gnome.enable
          || config.steelbore.desktops.plasma.enable
          || config.steelbore.desktops.cosmic.enable
          || config.steelbore.desktops.leftwm.enable;
        message = ''
          steelbore.desktops.mouseWorkspaceNav requires at least one of gnome,
          plasma, cosmic or leftwm — it emits Super+Ctrl+Left/Right, which only
          means "switch workspace" to a desktop that binds it. Niri does this
          natively and does not need this module.
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
    # here despite the store path reading `xremap-wlroots`. The variant selects
    # only the window-detection client used to resolve `application:`/`window:`
    # conditions in a keymap. Upstream constructs that client lazily —
    # `Client::supported()` is documented as "called very late, i.e. the first
    # time xremap wants some information", and the only callers are
    # `current_window()`/`current_application()`. This keymap has no such
    # conditions, so the client is never consulted and no compositor-specific
    # protocol is ever bound. That is also why ONE build serves GNOME, Plasma,
    # COSMIC and LeftWM at once.
    environment.systemPackages = [ pkgs.xremap ];

    # Scoped per session, deliberately, rather than to graphical-session.target.
    # Niri is a graphical session too, and it handles these buttons NATIVELY —
    # xremap grabs the device and re-emits, so a graphical-session unit would
    # consume BTN_SIDE/BTN_EXTRA before niri ever saw them and silently kill the
    # binds in users/mj/niri.nix. Listing the three targets that want it keeps
    # niri out by construction. Do not replace this list with
    # graphical-session.target.
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
    systemd.user.services.steelbore-mouse-workspace-nav = {
      description = "Steelbore mouse side-button workspace navigation";
      partOf = [
        "gnome-session-initialized.target"
        "cosmic-session.target"
        "plasma-core.target"
      ];
      after = [
        "gnome-session-initialized.target"
        "cosmic-session.target"
        "plasma-core.target"
      ];
      wantedBy = [
        "gnome-session-initialized.target"
        "cosmic-session.target"
        "plasma-core.target"
      ];
      serviceConfig = {
        ExecStart = xremapCommand;
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
