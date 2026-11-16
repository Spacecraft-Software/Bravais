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
  # Touchpad swipes (Escape Pod reads the touchpad read-only and never
  # grabs it, so the desktop sees every swipe too). Fingers follow the
  # content: a swipe left goes to the workspace on the right, as the side
  # buttons do (docs/keybindings.md). Up opens the overview: Super+W is
  # KWin's Overview and LeftWM's skippy-xd paging; 4-finger down is KWin's
  # Grid View (Super+G), unbound under LeftWM.
  swipe = fingers: direction: keys: { inherit fingers direction keys; };
  workspaceSwipes = fingers: [
    (swipe fingers "left" [
      "KEY_LEFTMETA"
      "KEY_LEFTCTRL"
      "KEY_RIGHT"
    ])
    (swipe fingers "right" [
      "KEY_LEFTMETA"
      "KEY_LEFTCTRL"
      "KEY_LEFT"
    ])
  ];
  x11Swipes =
    workspaceSwipes 3
    ++ workspaceSwipes 4
    ++ [
      (swipe 3 "up" [
        "KEY_LEFTMETA"
        "KEY_W"
      ])
      (swipe 4 "up" [
        "KEY_LEFTMETA"
        "KEY_W"
      ])
      (swipe 4 "down" [
        "KEY_LEFTMETA"
        "KEY_G"
      ])
    ];

  # One configuration per kind of session, because a desktop that handles a
  # swipe itself would see it twice -- once natively, once as the shortcut:
  #   - Plasma X11, LeftWM: KWin's gestures are Wayland-only and LeftWM has
  #     none, so every swipe comes from here.
  #   - COSMIC: cosmic-comp switches workspaces on four fingers only, so
  #     only three-finger left/right comes from here (this replaced a
  #     cosmic-comp source patch, CONSTRAINTS.md #35).
  #   - GNOME, Plasma Wayland: gestures of their own; side buttons only.
  # The mouse-workspace-nav flake check guards this split (CONSTRAINTS.md #57).
  mkConfig =
    name: swipes:
    toml.generate name {
      # A receiver can expose keyboards with the same vendor/product pair.
      # Exact pointer names keep keyboards and pointing sticks ungrabbed.
      # With no grabbed keyboard the exit-6 chord is unavailable. Recovery in
      # GNOME/Plasma/COSMIC: systemctl --user stop escapepod-mouse-workspace-nav.
      # LeftWM: run its theme's `down` hook, which signals the recorded daemon PID.
      grab = "listed";
      device =
        map (name: {
          inherit name;
          button = buttonRules;
        }) cfg.deviceNames
        ++ lib.optionals (swipes != [ ]) (
          map (name: {
            inherit name;
            gesture = swipes;
          }) cfg.touchpadNames
        );
    };
  mouseConfig = mkConfig "escapepod-mouse-workspace-nav.toml" [ ];
  x11Config = mkConfig "escapepod-mouse-workspace-nav-x11.toml" x11Swipes;
  cosmicConfig = mkConfig "escapepod-mouse-workspace-nav-cosmic.toml" (workspaceSwipes 3);
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
  commandFor =
    config:
    lib.escapeShellArgs [
      (lib.getExe package)
      "daemon"
      "run"
      "--backend"
      "evdev"
      "--config"
      (toString config)
      "--yes"
      "--json"
    ];
  # LeftWM is an X11 session with no gestures of its own.
  command = commandFor x11Config;

  # The session unit picks its configuration from the session it runs in;
  # anything it cannot place gets the side buttons alone, so no desktop ever
  # acts on a swipe twice.
  sessionCommand = pkgs.writeShellScript "escapepod-mouse-workspace-nav" ''
    case "''${XDG_CURRENT_DESKTOP:-}" in
      *COSMIC*) config=${cosmicConfig} ;;
      *KDE*)
        if [ "''${XDG_SESSION_TYPE:-}" = x11 ]; then
          config=${x11Config}
        else
          config=${mouseConfig}
        fi
        ;;
      *) config=${mouseConfig} ;;
    esac
    exec ${lib.getExe package} daemon run --backend evdev --config "$config" --yes --json
  '';
in
{
  options.steelbore.desktops.mouseWorkspaceNav = {
    enable = lib.mkEnableOption "mouse side-button workspace navigation via Escape Pod";

    touchpadNames = lib.mkOption {
      type = lib.types.listOf lib.types.nonEmptyStr;
      default = [ ];
      example = [ "Elan Touchpad" ];
      description = ''
        Exact touchpad names from `escapepod device list` (status `swipes`
        once matched). Escape Pod reads them read-only, never grabbing
        them, and sends workspace and overview shortcuts for three- and
        four-finger swipes in the sessions whose desktop has no such
        gestures: Plasma X11 and LeftWM (all), COSMIC (three-finger
        left/right only). Empty: no swipes anywhere.
      '';
    };

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
        The Escape Pod invocation for LeftWM's startx theme hook, which has
        no systemd graphical session: the X11 configuration (side buttons and
        every swipe). The session unit picks its configuration per session.
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
      {
        assertion = lib.unique cfg.touchpadNames == cfg.touchpadNames;
        message = "mouseWorkspaceNav.touchpadNames must not repeat a name.";
      }
    ];

    # Session daemon: retain the existing uinput access arrangement. Do not
    # enable Escape Pod's global system service: Niri needs the physical buttons.
    hardware.uinput.enable = true;
    environment.systemPackages = [ package ];
    environment.etc."escapepod/mouse-workspace-nav.toml".source = mouseConfig;
    environment.etc."escapepod/mouse-workspace-nav-x11.toml".source = x11Config;
    environment.etc."escapepod/mouse-workspace-nav-cosmic.toml".source = cosmicConfig;

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
        ExecStartPre = map (c: "${lib.getExe package} config check --config ${c} --json") [
          mouseConfig
          x11Config
          cosmicConfig
        ];
        ExecStart = sessionCommand;
        ExecStartPost = xKeyboardReady;
        Restart = "on-failure";
        RestartSec = 2;
        RestartPreventExitStatus = "6";
        TimeoutStopSec = 5;
      };
    };
  };
}
