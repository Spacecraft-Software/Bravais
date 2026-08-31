# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Networking and Internet Tools
{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.steelbore.packages.networking = {
    enable = lib.mkEnableOption "Networking and internet tools";
  };

  config = lib.mkIf config.steelbore.packages.networking.enable {
    environment.systemPackages =
      with pkgs;
      [
        # Network Management
        impala # Rust — TUI for iwd
        iwd

        # HTTP Clients (Rust preferred)
        xh # Rust — curl replacement
        monolith # Rust — webpage archiver
        curlFull
        wget2

        # Diagnostics (Rust preferred)
        gping # Rust — Graphical ping
        trippy # Rust — Network diagnostic
        lychee # Rust — Link checker
        rustscan # Rust — Port scanner
        sniffglue # Rust — Packet sniffer
        bandwhich # Rust — Bandwidth monitor

        # GUI Applications
        sniffnet # Rust — Network monitor
        mullvad-vpn # Rust — VPN client
        rqbit # Rust — BitTorrent client (CLI + web UI)

        # Download Managers
        aria2
        uget

        # Chat / IRC
        halloy # Rust + iced — modern multi-server IRCv3 client (GUI)
        tiny # Rust + crossterm — minimal multi-server IRC client (TUI)

        # Clipboard
        wl-clipboard
        wl-clipboard-rs # Rust

        # DNS & Services
        dnsmasq
        atftp
        adguardhome
      ]
      # AdGuard VPN CLI — a *different product* from adguardhome above (that one
      # is a DNS blocker; this is the VPN client). Absent from nixpkgs on both
      # channels, so the upstream static binary is vendored; derivation and
      # version/hash-bump notes live in pkgs/adguardvpn-cli/. Unfree; allowUnfree
      # is set in modules/core/nix.nix.
      #
      # Two runtime notes. (1) TUN mode opens /dev/net/tun and rewrites
      # /etc/resolv.conf — which systemd-resolved owns here, running DoT + DNSSEC
      # (modules/core/dns.nix) — so a TUN connection displaces that encrypted
      # resolver. SOCKS mode (`adguardvpn-cli config set-mode SOCKS`) needs no
      # privileges and leaves resolved alone; TUN mode needs sudo, or a
      # security.wrappers entry granting cap_net_admin, since a store path
      # cannot carry file capabilities. (2) The built-in `update` /
      # `check-update` subcommands cannot write to the read-only store — bump
      # with `nu pkgs/update-vendored.nu adguardvpn-cli` instead.
      ++ [ (import ../../pkgs { inherit pkgs; }).adguardvpn-cli ];
  };
}
