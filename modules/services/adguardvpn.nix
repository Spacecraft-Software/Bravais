# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — AdGuard VPN CLI: package, SCRIPT-mode route script, teardown helper
#
# The single owner of everything AdGuard VPN. `modules/packages/networking.nix`
# used to install the package inside the networking bundle; it now points here,
# because the package alone is not the whole story — the routing mode, the
# root-owned route script and the teardown helper are one subject and drifted
# apart while they lived in three places.
#
# Note `adguardhome` (in the networking bundle) is a DIFFERENT product: a DNS
# blocker. This is the VPN client.
#
# The client is absent from nixpkgs on both channels, so the upstream static
# binary is vendored in pkgs/adguardvpn-cli/ against a pinned version + hash.
# It is unfree (allowUnfree is set in modules/core/nix.nix), and its own
# `update` / `check-update` subcommands cannot write to the read-only store --
# bump it with `nu pkgs/update-vendored.nu adguardvpn-cli` instead.
#
# ── Why SCRIPT routing mode ───────────────────────────────────────────────────
#
# TUN mode has three routing modes (`config set-tun-routing-mode`):
#
#   AUTO    the client installs routes AND rewrites /etc/resolv.conf itself.
#           systemd-resolved owns that file here, running DoT + DNSSEC
#           (modules/core/dns.nix), so AUTO displaces the encrypted resolver.
#           This is the trap recorded as AGENTS.md constraint #19.
#   NONE    no routes, no DNS changes. Leaves resolved alone -- and carries no
#           traffic either. Measured 2026-09-09 with the tunnel "connected":
#           default route still via wlp0s20f3, no `ip rule` entries, no extra
#           routing tables. A VPN that only looks connected.
#   SCRIPT  the client runs a script we supply, as root, on tunnel up. We get
#           the routes and resolved keeps the DNS. This is the mode that
#           satisfies both halves of constraint #19, which is why it is here.
#
# ── The route script contract (measured, not guessed) ─────────────────────────
#
# Taken from what `adguardvpn-cli config create-route-script` generates and from
# what the client says when the permissions are wrong:
#
#   path   $AGVPN_CLI_DATA_PATH/setup_routes.sh -- the client's data directory,
#          which is ${home}/.local/share/adguardvpn-cli unless the env var moves it
#   owner  root:root, mode 0700 -- the client refuses anything else, and is
#          right to: it executes this file AS ROOT, so a user-writable copy is
#          a local privilege-escalation primitive
#   argv   $1 is the tunnel interface name (tun0). There is no second argument
#          and no "down" invocation: routes attached to a device die with the
#          device, so teardown needs no script
#
# Do NOT run `config create-route-script` to install it. That subcommand hangs
# for the same reason `disconnect` did (see the helper below) -- it shells out
# to sudo to chown the file it just wrote, and never comes back. It also writes
# the script mj-owned, which the client then rejects. This module installs the
# file itself, root-owned and 0700, and never needs that subcommand.
{
  config,
  lib,
  pkgs,
  primaryUser,
  ...
}:

let
  cfg = config.steelbore.services.adguardvpn;
  steelborePkgs = import ../../pkgs { inherit pkgs; };

  home = config.users.users.${primaryUser}.home;
  dataDir = "${home}/.local/share/adguardvpn-cli";
  scriptPath = "${dataDir}/setup_routes.sh";

  # Upstream's generated template, with four deliberate differences. Every one
  # of them is a correctness fix, not a preference:
  #
  #   1. `route replace` instead of `route add`. `add` fails with EEXIST if a
  #      route survived a previous session, and with `set -e` that aborts the
  #      rest of the script -- so a reconnect after an unclean teardown would
  #      install the v4 half and skip the v6 half. `replace` is idempotent,
  #      which the CLI Standard asks of every apply-shaped operation anyway.
  #   2. `${pkgs.iproute2}/bin/ip` rather than bare `ip`. This runs as root out
  #      of the client's process, whose PATH is not ours to assume.
  #   3. `"$iface"` quoted, and validated against an interface-name charset
  #      before it reaches argv.
  #   4. `set -eu`.
  #
  # What is deliberately UNCHANGED from upstream:
  #
  #   * The 0.0.0.0/1 + 128.0.0.0/1 pair rather than replacing `default`. Two
  #     /1s cover the whole v4 space while staying *less* specific than any
  #     real route, so the LAN prefix (172.16.0.0/16 dev wlp0s20f3 here) still
  #     wins and local addresses keep working. It also leaves the original
  #     default route intact for the client's own socket to the VPN endpoint.
  #   * No route for the VPN endpoint itself. A tunnelled endpoint socket would
  #     be a routing loop; the client avoids it by binding that socket to the
  #     physical interface, which is what `config set-bound-if-override` exists
  #     to steer. Adding a host route here would duplicate that badly -- the
  #     endpoint address is not known at script time and changes per session.
  #   * `|| true` on the v6 line only. A network with no IPv6 must not fail the
  #     connect; a v4 failure genuinely is a failed connect.
  #   * No DNS handling whatsoever. That is the entire point: systemd-resolved
  #     keeps /etc/resolv.conf, and DoT queries simply travel through the
  #     tunnel like everything else. Keep `config set-change-system-dns off`.
  routeScript = pkgs.writeShellScript "adguardvpn-setup-routes" ''
    # Run AS ROOT by adguardvpn-cli when the tunnel comes up.
    # $1 = tunnel interface name. See modules/services/adguardvpn.nix.
    set -eu

    iface="''${1:?tunnel interface not supplied as $1}"
    case "$iface" in
      "" | *[!a-zA-Z0-9._-]*)
        echo "adguardvpn route script: refusing implausible interface name" >&2
        exit 2
        ;;
    esac

    ip=${pkgs.iproute2}/bin/ip

    "$ip" route replace 0.0.0.0/1 dev "$iface"
    "$ip" route replace 128.0.0.0/1 dev "$iface"
    "$ip" -6 route replace 2000::/3 dev "$iface" || true
  '';
in
{
  options.steelbore.services.adguardvpn = {
    enable = lib.mkEnableOption "AdGuard VPN CLI";

    routeScript = {
      enable = lib.mkEnableOption ''
        the root-owned SCRIPT-mode route script. Installing it is necessary but
        not sufficient: the routing mode itself lives in the client's own
        encrypted config, which no Nix option can reach. Run
        `adguardvpn-cli config set-tun-routing-mode script` once
      '';

      path = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = scriptPath;
        description = ''
          Where the route script is installed. Read-only, and exported so the
          documentation and steelbore-vpn cannot drift from the module.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      steelborePkgs.adguardvpn-cli
      steelborePkgs.steelbore-vpn
    ];

    # The client's data directory holds its config, logs and sockets, all
    # written as the user, so it must exist and be USER-owned before the route
    # script lands in it. That is also why the unit below deliberately does not
    # pass `install -D`: on a machine where the client has never run, -D would
    # create this directory root-owned and the client could then never write its
    # own log. Creating it here instead keeps the ownership correct and lets
    # `install` fail loudly if it is somehow still missing.
    systemd.tmpfiles.rules = lib.mkIf cfg.routeScript.enable [
      "d ${dataDir} 0755 ${primaryUser} users -"
    ];

    # A oneshot unit rather than a tmpfiles `C` rule, for a measured reason:
    # `C` copies only when the destination does not already exist, and `C+`
    # -- tested on systemd 260.1 -- fixes up mode and ownership of an existing
    # file but leaves its CONTENTS alone. A route script that silently keeps
    # stale contents while reporting the right permissions is precisely the
    # failure this module must not have. `install` always writes.
    systemd.services.steelbore-adguardvpn-route-script = lib.mkIf cfg.routeScript.enable {
      description = "Install the AdGuard VPN SCRIPT-mode route script (root-owned, 0700)";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-tmpfiles-setup.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        install -m 0700 -o root -g root ${routeScript} ${scriptPath}
      '';
    };
  };
}
