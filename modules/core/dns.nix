# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — DNS via systemd-resolved with DoT + DNSSEC
#
# Primary  : Cloudflare malware-block (1.1.1.2 / 1.0.0.2, SNI
#            security.cloudflare-dns.com). Drops queries for known
#            malicious domains at the DNS level.
# Fallback : regular Cloudflare (1.1.1.1 / 1.0.0.1, SNI
#            cloudflare-dns.com). Used only when primary is
#            unreachable; keeps DoT and DNSSEC, loses malware
#            filtering during fallback.
#
# All queries are encrypted in transit (DoT, port 853) and
# DNSSEC-validated end-to-end. The `~.` routing domain makes the
# global DNS the route for every query, ignoring any link-specific
# DNS pushed by DHCP from the LAN gateway.
#
# Schema note: on nixos-unstable, `services.resolved.{dnssec,
# dnsovertls,domains,fallbackDns}` were renamed to
# `services.resolved.settings.Resolve.{DNSSEC,DNSOverTLS,Domains,
# FallbackDNS}`. The old names still work via mkRenamedOptionModule
# but emit deprecation warnings. On stable 25.11 only the old names
# exist. The `options.services.resolved ? settings` check picks the
# right form per channel — same stable/unstable workaround pattern
# as CLAUDE.md known constraint #5.
{
  config,
  lib,
  pkgs,
  options,
  ...
}:

let
  resolveSettings = {
    DNSSEC = "true";
    DNSOverTLS = "true";
    # `~.` is systemd-resolved's "everything" routing domain. Sending
    # it as a global Domains entry forces ALL queries through the
    # global DNS list (Cloudflare malware-block) regardless of which
    # link they would otherwise route via. Link-specific DNS pushed
    # by NetworkManager/DHCP becomes effectively unused.
    Domains = [ "~." ];
    FallbackDNS = [
      "1.1.1.1#cloudflare-dns.com"
      "1.0.0.1#cloudflare-dns.com"
      "2606:4700:4700::1111#cloudflare-dns.com"
      "2606:4700:4700::1001#cloudflare-dns.com"
    ];
  };

  hasSettings = options.services.resolved ? settings;
in
{
  services.resolved = {
    enable = true;
  }
  // (
    if hasSettings then
      {
        settings.Resolve = resolveSettings;
      }
    else
      {
        dnssec = resolveSettings.DNSSEC;
        dnsovertls = resolveSettings.DNSOverTLS;
        domains = resolveSettings.Domains;
        fallbackDns = resolveSettings.FallbackDNS;
      }
  );

  # Primary DNS list. Lowered to `DNS=` in /etc/systemd/resolved.conf
  # by the NixOS resolved module. The `IP#hostname` form carries the
  # TLS SNI alongside the IP so DoT can verify Cloudflare's cert.
  networking.nameservers = [
    "1.1.1.2#security.cloudflare-dns.com"
    "1.0.0.2#security.cloudflare-dns.com"
    "2606:4700:4700::1112#security.cloudflare-dns.com"
    "2606:4700:4700::1002#security.cloudflare-dns.com"
  ];

  # NetworkManager pushes DHCP-acquired DNS to systemd-resolved as
  # link-specific DNS instead of writing /etc/resolv.conf directly.
  # With `~.` above, link DNS is unused but stays available for
  # diagnostic/oddity purposes.
  networking.networkmanager.dns = "systemd-resolved";
}
