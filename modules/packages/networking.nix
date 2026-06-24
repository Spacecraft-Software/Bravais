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
    environment.systemPackages = with pkgs; [
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
    ];
  };
}
