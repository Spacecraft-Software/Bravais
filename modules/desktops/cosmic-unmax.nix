# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — steelbore-cosmic-unmax: revert clients that maximize
# themselves right after opening, under COSMIC.
#
# The COSMIC counterpart to modules/desktops/niri-unmax.nix. Same user-visible
# problem, entirely different mechanism, which is why they are two modules and
# two binaries rather than one with a backend switch.
#
# Why a daemon and not a setting: COSMIC has none. `CosmicCompConfig`
# (cosmic-comp 1.0.13) carries autotile, active_hint, focus_follows_cursor,
# edge_snap_threshold, input, xkb, workspaces, zoom and appearance — nothing
# about maximization. And it is not COSMIC choosing to maximize: the client
# asks via xdg-toplevel `set_maximized`, cosmic-comp records
# `pending.maximized = true` (src/wayland/handlers/xdg_shell/mod.rs) and
# honours it at map time (src/shell/mod.rs). No window rule can refuse it.
#
# Unlike the niri daemon, detection here needs no geometry: the
# `zcosmic_toplevel_handle_v1.state` event reports `maximized` explicitly. See
# pkgs/steelbore-cosmic-unmax/src/main.rs for the full design notes.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  unmax = (import ../../pkgs { inherit pkgs; }).steelbore-cosmic-unmax;
in
{
  options.steelbore.desktops.cosmicUnmax = {
    enable = lib.mkEnableOption "un-maximizing windows that open maximized under COSMIC";
  };

  config = lib.mkIf config.steelbore.desktops.cosmicUnmax.enable {
    assertions = [
      {
        assertion = config.steelbore.desktops.cosmic.enable;
        message = ''
          steelbore.desktops.cosmicUnmax requires steelbore.desktops.cosmic.enable = true —
          the daemon binds cosmic-comp's zcosmic_toplevel_manager_v1 protocol.
        '';
      }
    ];

    environment.systemPackages = [ unmax ];

    # `cosmic-session.target`, not `graphical-session.target`. Both are active
    # under COSMIC (verified live), but the narrower one keeps the daemon from
    # starting under Niri, GNOME or Plasma, where the cosmic globals do not
    # exist. It would exit 0 with a notice there rather than fail — see the
    # bind_globals fallback — but not starting at all is tidier than starting
    # to say nothing.
    #
    # cosmic-session puts WAYLAND_DISPLAY into the systemd user environment
    # (verified: `systemctl --user show-environment` reports wayland-1), which
    # is what lets the daemon connect at all.
    #
    # `Restart=on-failure` and NOT on-success: a clean exit is the daemon
    # correctly deciding it has nothing to do, and restarting that would flap.
    systemd.user.services.steelbore-cosmic-unmax = {
      description = "Steelbore COSMIC open-maximize reverter";
      partOf = [ "cosmic-session.target" ];
      after = [ "cosmic-session.target" ];
      wantedBy = [ "cosmic-session.target" ];
      serviceConfig = {
        ExecStart = lib.getExe unmax;
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
