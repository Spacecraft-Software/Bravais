# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — steelbore-niri-unmax: revert clients that re-maximize
# themselves right after opening (Chrome et al.)
#
# Why a daemon and not a window rule: niri's `open-maximized` /
# `open-maximized-to-edges` rules are map-time only. Chrome maps at its tile
# size and requests maximization a moment later (measured 2026-07-25:
# 756x816 → 1536x832), which niri honours, and `max-width` was tested live and
# does not constrain a maximized-to-edges window. The daemon watches the niri
# IPC event stream and toggles the state back off — only for windows inside a
# short post-open grace window, so a maximize the user performs later is never
# touched. See pkgs/steelbore-niri-unmax/src/main.rs for the full design notes.
#
# PRECONDITION: detection is geometric (tile width == output logical width)
# and requires `layout.gaps > 0` in the niri config (users/mj/niri.nix sets
# `gaps 8`). With zero gaps a normal full column is indistinguishable from the
# maximized-to-edges state and this module must be disabled.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  unmax = (import ../../pkgs { inherit pkgs; }).steelbore-niri-unmax;
in
{
  options.steelbore.desktops.niriUnmax = {
    enable = lib.mkEnableOption "un-maximizing windows that open maximized-to-edges under Niri";
  };

  config = lib.mkIf config.steelbore.desktops.niriUnmax.enable {
    assertions = [
      {
        assertion = config.steelbore.desktops.niri.enable;
        message = ''
          steelbore.desktops.niriUnmax requires steelbore.desktops.niri.enable = true —
          the daemon watches the niri IPC event stream.
        '';
      }
    ];

    environment.systemPackages = [ unmax ];

    # Bound to the graphical session: NIRI_SOCKET reaches the systemd user
    # environment via niri-session's import-environment. Under non-niri
    # graphical sessions (GNOME/COSMIC/Plasma) the daemon probes the socket,
    # finds none answering, and exits 0 — no Restart=on-failure flapping.
    # Under LeftWM (startx, no graphical-session.target) it never starts.
    # The daemon also holds a per-session single-instance lock, so a manually
    # started copy and the unit cannot double-toggle the same window.
    systemd.user.services.steelbore-niri-unmax = {
      description = "Steelbore niri open-maximize reverter";
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = lib.getExe unmax;
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
