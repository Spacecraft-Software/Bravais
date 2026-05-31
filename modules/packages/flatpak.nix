# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Declarative Flatpak Applications (via nix-flatpak)
{ config, lib, pkgs, ... }:

{
  options.steelbore.packages.flatpak = {
    enable = lib.mkEnableOption "Flatpak application management";
  };

  config = lib.mkIf config.steelbore.packages.flatpak.enable {
    # Enable Flatpak service
    services.flatpak.enable = true;

    # Resilience for the nix-flatpak install service.  Pulling 5+ GB of
    # runtimes through Flathub's CDN routinely trips libostree's hardcoded
    # CURLOPT_LOW_SPEED_TIME=60s / CURLOPT_LOW_SPEED_LIMIT=1KB/s curl
    # timeouts on slow-mirror hops, and the install script exits with
    # `set -eu` on first error.  The unit ships with Restart=on-failure
    # RestartSec=60s — but systemd's default StartLimitBurst=5 in a
    # 10s window means a single 60s-spaced retry exhausts the budget,
    # so the unit gives up after one failure.  Bump the burst budget
    # and uncap the start timeout so a slow first run can finish, and
    # subsequent retries actually fire until the libostree partial-pull
    # cache fills in.
    systemd.services.flatpak-managed-install.serviceConfig = {
      TimeoutStartSec = lib.mkForce "infinity";
      RestartSec = lib.mkForce "30s";
    };
    systemd.services.flatpak-managed-install.unitConfig = {
      StartLimitIntervalSec = "30min";
      StartLimitBurst = 20;
    };

    # Flatpak remotes
    services.flatpak.remotes = [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
    ];

    # Declarative Flatpak packages
    services.flatpak.packages = [
      # ── Terminals ──────────────────────────────────────────────────────────
      { appId = "app.devsuite.Ptyxis";               origin = "flathub"; }

      # ── Browsers ───────────────────────────────────────────────────────────
      { appId = "app.zen_browser.zen";               origin = "flathub"; }
      { appId = "com.microsoft.Edge";                origin = "flathub"; }
      { appId = "com.opera.Opera";                   origin = "flathub"; }

      # ── Communication ──────────────────────────────────────────────────────
      { appId = "com.discordapp.Discord";             origin = "flathub"; }
      { appId = "im.riot.Riot";                       origin = "flathub"; }  # Element
      { appId = "io.wavebox.Wavebox";                 origin = "flathub"; }

      # ── Security & Remote ──────────────────────────────────────────────────
      { appId = "com.bitwarden.desktop";              origin = "flathub"; }
      { appId = "com.rustdesk.RustDesk";              origin = "flathub"; }

      # ── Development ────────────────────────────────────────────────────────
      { appId = "com.jetbrains.RustRover";            origin = "flathub"; }
      { appId = "com.visualstudio.code";              origin = "flathub"; }
      { appId = "dev.zed.Zed";                        origin = "flathub"; }
      { appId = "io.github.shiftey.Desktop";          origin = "flathub"; }  # GitHub Desktop
      { appId = "org.vim.Vim";                        origin = "flathub"; }

      # ── System & Utilities ─────────────────────────────────────────────────
      { appId = "com.daidouji.oneko";                 origin = "flathub"; }  # Desktop cat
      { appId = "com.github.tchx84.Flatseal";         origin = "flathub"; }
      { appId = "io.github.dvlv.boxbuddyrs";          origin = "flathub"; }  # BoxBuddy
      { appId = "io.github.prateekmedia.appimagepool"; origin = "flathub"; }
      { appId = "it.mijorus.gearlever";               origin = "flathub"; }
      { appId = "org.adishatz.Screenshot";            origin = "flathub"; }
      { appId = "org.flameshot.Flameshot";            origin = "flathub"; }
      { appId = "org.gnome.baobab";                   origin = "flathub"; }  # Disk Usage Analyzer

      # ── Gaming ─────────────────────────────────────────────────────────────
      { appId = "com.heroicgameslauncher.hgl";        origin = "flathub"; }  # Heroic
      { appId = "com.usebottles.bottles";             origin = "flathub"; }
      { appId = "com.valvesoftware.Steam";            origin = "flathub"; }
      { appId = "info.beyondallreason.bar";           origin = "flathub"; }
      { appId = "net.openra.OpenRA";                  origin = "flathub"; }
      { appId = "net.wz2100.wz2100";                  origin = "flathub"; }  # Warzone 2100
      { appId = "org.libretro.RetroArch";             origin = "flathub"; }
      { appId = "org.openttd.OpenTTD";                origin = "flathub"; }

      # ── Retro / Classic Games ──────────────────────────────────────────────
      { appId = "com.dosbox.DOSBox";                  origin = "flathub"; }
      { appId = "com.dosbox_x.DOSBox-X";              origin = "flathub"; }
      { appId = "com.play0ad.zeroad";                 origin = "flathub"; }  # 0 A.D.
      { appId = "com.remnantsoftheprecursors.ROTP";   origin = "flathub"; }
      { appId = "eu.jumplink.Learn6502";              origin = "flathub"; }
      { appId = "io.github.dosbox-staging";           origin = "flathub"; }
      { appId = "io.github.jotd666.gods-deluxe";      origin = "flathub"; }
      { appId = "io.github.dman95.SASM";              origin = "flathub"; }  # Assembly IDE
      { appId = "org.seul.crimson";                   origin = "flathub"; }  # Crimson Fields
      { appId = "org.zdoom.UZDoom";                   origin = "flathub"; }
      { appId = "rs.ruffle.Ruffle";                   origin = "flathub"; }

      # ── Browsers ───────────────────────────────────────────────────────────
      { appId = "com.brave.Browser";                  origin = "flathub"; }
      { appId = "io.gitlab.librewolf-community.librewolf"; origin = "flathub"; }

      # ── Multimedia ─────────────────────────────────────────────────────────
      { appId = "org.videolan.VLC";                   origin = "flathub"; }

      # ── Office ─────────────────────────────────────────────────────────────
      { appId = "org.libreoffice.LibreOffice";        origin = "flathub"; }
      { appId = "org.onlyoffice.desktopeditors";      origin = "flathub"; }

      # ── Knowledge & Communication ──────────────────────────────────────────
      { appId = "com.affine.AFFiNE";                  origin = "flathub"; }
      { appId = "io.appflowy.AppFlowy";               origin = "flathub"; }
      { appId = "de.tutao.tutanota";                  origin = "flathub"; }

      # ── Productivity ───────────────────────────────────────────────────────
      { appId = "io.github.Qalculate";                origin = "flathub"; }
      { appId = "org.kde.yakuake";                    origin = "flathub"; }

      # ── AI ─────────────────────────────────────────────────────────────────
      { appId = "com.jeffser.Alpaca";                 origin = "flathub"; }
    ];
  };
}
