# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — mouse side-button workspace navigation
# Back (BTN_SIDE) goes RIGHT; forward (BTN_EXTRA) goes LEFT. Keep the native
# Niri and Margo bindings in the same direction (CONSTRAINTS.md #29).
{
  config,
  lib,
  pkgs,
  escapepod,
  ...
}:
let
  cfg = config.steelbore.desktops.mouseWorkspaceNav;
  package = escapepod.packages.${pkgs.stdenv.hostPlatform.system}.default;
  toml = pkgs.formats.toml { };
  buttonRules = [
    {
      button = "BTN_SIDE";
      keys = [
        "KEY_LEFTMETA"
        "KEY_LEFTCTRL"
        "KEY_RIGHT"
      ];
    }
    {
      button = "BTN_EXTRA";
      keys = [
        "KEY_LEFTMETA"
        "KEY_LEFTCTRL"
        "KEY_LEFT"
      ];
    }
  ];
  mouseConfig = toml.generate "escapepod-mouse-workspace-nav.toml" {
    # A receiver can expose keyboards with the same vendor/product pair.
    # Exact pointer names keep keyboards and pointing sticks ungrabbed.
    # With no grabbed keyboard the exit-6 chord is unavailable. Recovery in
    # GNOME/Plasma/COSMIC: systemctl --user stop escapepod-mouse-workspace-nav.
    # LeftWM: run its theme's `down` hook, which signals the recorded daemon PID.
    grab = "listed";
    device = map (name: {
      inherit name;
      button = buttonRules;
    }) cfg.deviceNames;
  };
  # Plasma X11: the X server can read the daemon's new virtual keyboard
  # before udev has tagged it, and libinput then refuses it for good ("not
  # using input device"). The buttons are still grabbed, so they go dead
  # with no error anywhere but Xorg.0.log. Wait for X to list this
  # instance's keyboard (its name ends in the daemon's PID) and fail the
  # start otherwise, so Restart= creates the device again; a restart after
  # login was enough every time it was tried. No-op outside X11, where the
  # compositor reads the device itself (CONSTRAINTS.md #56).
  xinput = pkgs.xinput or pkgs.xorg.xinput;
  xKeyboardReady = pkgs.writeShellScript "escapepod-x11-keyboard-ready" ''
    [ "''${XDG_SESSION_TYPE:-}" = x11 ] && [ -n "''${DISPLAY:-}" ] || exit 0
    want="Escape Pod virtual keyboard $MAINPID"
    i=0
    while [ "$i" -lt 40 ]; do
      if ${lib.getExe xinput} list --name-only 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qxF "$want"; then
        exit 0
      fi
      i=$((i + 1))
      ${pkgs.coreutils}/bin/sleep 0.25
    done
    echo "X did not add '$want'; restarting so the device is created again" >&2
    exit 1
  '';
  command = lib.escapeShellArgs [
    (lib.getExe package)
    "daemon"
    "run"
    "--backend"
    "evdev"
    "--config"
    (toString mouseConfig)
    "--yes"
    "--json"
  ];
in
{
  options.steelbore.desktops.mouseWorkspaceNav = {
    enable = lib.mkEnableOption "mouse side-button workspace navigation via Escape Pod";

    deviceNames = lib.mkOption {
      type = lib.types.listOf lib.types.nonEmptyStr;
      default = [ ];
      example = [
        "UGREEN Receiver  Mouse"
        "UGREEN BLE Mouse"
      ];
      description = ''
        Exact relative-mouse names from `escapepod device list`. Only these
        devices receive button rules. List pointer interfaces, not the
        keyboard interfaces a wireless receiver may expose. Absent devices
        are harmless and reconnecting devices are picked up automatically.
        The keyboard emergency chord is unavailable in this mouse-only mode;
        stop escapepod-mouse-workspace-nav.service to release the mice, or run
        the LeftWM theme's down hook in a startx session.
      '';
    };

    command = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = command;
      description = ''
        The Escape Pod invocation shared by the session unit and LeftWM's
        startx theme hook, which has no systemd graphical session.
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
          steelbore.desktops.mouseWorkspaceNav requires gnome, plasma,
          cosmic or leftwm. Niri and Margo bind side buttons natively.
        '';
      }
      {
        assertion = cfg.deviceNames != [ ] && lib.unique cfg.deviceNames == cfg.deviceNames;
        message = "mouseWorkspaceNav.deviceNames must name at least one mouse, without duplicates.";
      }
    ];

    # Session daemon: retain the existing uinput access arrangement. Do not
    # enable Escape Pod's global system service: Niri needs the physical buttons.
    hardware.uinput.enable = true;
    environment.systemPackages = [ package ];
    environment.etc."escapepod/mouse-workspace-nav.toml".source = mouseConfig;

    # Never graphical-session.target: that would consume Niri's native buttons.
    systemd.user.services.escapepod-mouse-workspace-nav = {
      description = "Escape Pod mouse side-button workspace navigation";
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
      # Five tries a minute: the readiness check above fails a start that X
      # skipped, and each retry makes a fresh device.
      startLimitBurst = 5;
      startLimitIntervalSec = 60;
      serviceConfig = {
        ExecStartPre = "${lib.getExe package} config check --config ${mouseConfig} --json";
        ExecStart = command;
        ExecStartPost = xKeyboardReady;
        Restart = "on-failure";
        RestartSec = 2;
        RestartPreventExitStatus = "6";
        TimeoutStopSec = 5;
      };
    };
  };
}
