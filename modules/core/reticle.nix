# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — mouse on the virtual consoles (steelbore-reticle)
#
# Replaces gpm with an in-tree Rust daemon (pkgs/steelbore-reticle):
# left-drag selects, double/triple click selects a word/line, right-click
# extends, middle-click pastes, and programs that ask for xterm mouse
# reporting (htop, mc, vim) get the clicks instead. It drives the kernel's
# own selection ioctls, so the console itself (tuigreet's VT, getty, the
# palette in console.colors) is untouched.
#
# Input comes from every pointing device through evdev, never grabbed. A
# mouse that xremap (modules/desktops/mouse-workspace-nav.nix) grabs is
# still followed, because the daemon also reads xremap's re-emitting uinput
# device, which it finds through inotify on /dev/input like any hotplug.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.steelbore.console.mouse;
  reticle = (import ../../pkgs { inherit pkgs; }).steelbore-reticle;
in
{
  options.steelbore.console.mouse = {
    enable = lib.mkEnableOption "mouse selection and paste on the virtual consoles (steelbore-reticle, Rust)";

    speed = lib.mkOption {
      type = lib.types.numbers.between 0.1 10;
      default = 1.0;
      description = ''
        Pointer speed multiplier, 0.1 to 10. At 1.0 a mouse moves one column per 10
        counts and a touchpad one column per 0.6 mm; rows take twice that,
        because a console cell is about twice as tall as it is wide.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Both would draw a pointer and fight over the selection.
    assertions = [
      {
        assertion = !config.services.gpm.enable;
        message = ''
          steelbore.console.mouse replaces gpm; disable services.gpm.
        '';
      }
    ];

    # On PATH for `steelbore-reticle device list` and `console get`.
    environment.systemPackages = [ reticle ];

    systemd.services.steelbore-reticle = {
      description = "Steelbore console mouse (Rust gpm replacement)";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        # Human-format diagnostics read better in the journal than JSON lines;
        # the journal adds its own timestamps and colour is never wanted there.
        # --verbose logs each device as it is picked up or goes away.
        ExecStart = "${lib.getExe reticle} run --speed ${toString cfg.speed} --format human --no-color --verbose";
        Restart = "on-failure";
        RestartSec = 2;

        # TIOCL_SETSEL and TIOCL_PASTESEL need CAP_SYS_ADMIN (Linux >= 6.7),
        # so this runs as root, but with that ONE capability. Without
        # CAP_DAC_OVERRIDE, root opens /dev/input/event* as their owner and a
        # logged-in VT (owned by the user, mode 0620) through the `tty` group.
        CapabilityBoundingSet = [ "CAP_SYS_ADMIN" ];
        SupplementaryGroups = [ "tty" ];
        DevicePolicy = "closed";
        DeviceAllow = [
          "char-input r"
          "char-tty w"
        ];
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateNetwork = true;
        RestrictAddressFamilies = [ "AF_UNIX" ];
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectHostname = true;
        ProtectProc = "invisible";
        ProcSubset = "pid";
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [ "@system-service" ];
        UMask = "0077";
      };
    };
  };
}
