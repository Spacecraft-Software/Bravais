# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Declarative Flatpak Applications (via nix-flatpak)
{
  config,
  lib,
  ...
}:

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
      # System 's origin for the COSMIC applets below. Declared as the
      # `.flatpakrepo` rather than the bare repo URL so the GPG key travels
      # with it — a bare URL would need `--no-gpg-verify` to add.
      {
        name = "cosmic";
        location = "https://apt.pop-os.org/cosmic/cosmic.flatpakrepo";
      }
    ];

    # Keep the declared Flatpaks current. Neither update mechanism is on by
    # default, so without this nothing ever refreshes them — the version
    # installed is whatever the remote happened to serve the day the app was
    # first declared, forever. Chrome sat two months stale that way.
    #
    # A timer, deliberately, rather than `update.onActivation = true`: the
    # entries here pin no version (only an appId), so "current" is a property
    # of the remote and not of this flake — a rebuild is not what makes it
    # true. Tying updates to activation would add an unbounded download to
    # every `nixos-rebuild switch` (Chrome alone is ~150 MB, and a runtime bump
    # ~250 MB) and block the switch on it, for a class of package a rebuild
    # cannot make reproducible anyway.
    services.flatpak.update.auto = {
      enable = true;
      onCalendar = "weekly";
    };

    # Declarative Flatpak packages.
    #
    # DELIVERY POLICY (elegance plan 4.1): an app ships from nixpkgs UNLESS it
    # is a huge source build (Chromium-family browsers, VLC, LibreOffice) or
    # sandbox-hostile/self-updating GUI (VS Code, RustRover) — then Flatpak.
    # Never both: nixpkgs Emacs/Vim/Yakuake replaced the Flatpak copies here.
    services.flatpak.packages = [
      # ── COSMIC applets ─────────────────────────────────────────────────────
      # Declared here to collapse a SECOND Flatpak installation. These two were
      # hand-installed into the per-user scope (~/.local/share/flatpak), which
      # brought its own `cosmic` remote along and left flathub configured
      # twice — so every unqualified `flatpak` command became ambiguous
      # ("Remote 'flathub' found in multiple installations"). The user scope
      # held these two apps and 2.4 GB; everything else, all 32 apps, was
      # already system-wide and declarative.
      #
      # System Flatpaks export into /var/lib/flatpak/exports/share, which is on
      # XDG_DATA_DIRS, so the COSMIC panel still discovers them from here.
      {
        appId = "io.github.cosmic_utils.cosmic-ext-applet-clipboard-manager";
        origin = "cosmic";
      }
      {
        appId = "io.github.cosmic_utils.minimon-applet";
        origin = "cosmic";
      }

      # ── Browsers ───────────────────────────────────────────────────────────
      # { appId = "app.zen_browser.zen";               origin = "flathub"; }
      {
        appId = "com.google.Chrome";
        origin = "flathub";
      }
      {
        appId = "com.microsoft.Edge";
        origin = "flathub";
      }
      # { appId = "org.mozilla.firefox";               origin = "flathub"; }
      {
        appId = "com.opera.Opera";
        origin = "flathub";
      }
      {
        appId = "com.brave.Browser";
        origin = "flathub";
      }
      # { appId = "io.gitlab.librewolf-community";      origin = "flathub"; }

      # ── Communication ──────────────────────────────────────────────────────
      {
        appId = "com.discordapp.Discord";
        origin = "flathub";
      }
      {
        appId = "im.riot.Riot";
        origin = "flathub";
      } # Element
      {
        appId = "io.wavebox.Wavebox";
        origin = "flathub";
      }

      # ── Networking / Internet ──────────────────────────────────────────────
      {
        appId = "de.haeckerfelix.Fragments";
        origin = "flathub";
      } # Rust BitTorrent client (GTK4/libadwaita)

      # ── Security & Remote ──────────────────────────────────────────────────
      {
        appId = "com.bitwarden.desktop";
        origin = "flathub";
      }
      {
        appId = "com.rustdesk.RustDesk";
        origin = "flathub";
      }

      # ── Development ────────────────────────────────────────────────────────
      {
        appId = "com.jetbrains.RustRover";
        origin = "flathub";
      }
      {
        appId = "com.visualstudio.code";
        origin = "flathub";
      }
      # { appId = "dev.zed.Zed";                        origin = "flathub"; }  # DISABLED — using pkgs.zed-editor instead
      {
        appId = "io.github.shiftey.Desktop";
        origin = "flathub";
      } # GitHub Desktop
      # org.gnu.emacs / org.vim.Vim removed — nixpkgs emacs-pgtk and
      # vim/neovim are the single delivery (policy above).

      # ── System & Utilities ─────────────────────────────────────────────────
      {
        appId = "com.daidouji.oneko";
        origin = "flathub";
      } # Desktop cat
      {
        appId = "com.github.tchx84.Flatseal";
        origin = "flathub";
      }
      {
        appId = "io.github.dvlv.boxbuddyrs";
        origin = "flathub";
      } # BoxBuddy
      {
        appId = "io.github.prateekmedia.appimagepool";
        origin = "flathub";
      }
      {
        appId = "it.mijorus.gearlever";
        origin = "flathub";
      }
      {
        appId = "org.adishatz.Screenshot";
        origin = "flathub";
      }
      {
        appId = "org.flameshot.Flameshot";
        origin = "flathub";
      }
      {
        appId = "org.gnome.baobab";
        origin = "flathub";
      } # Disk Usage Analyzer

      # ── Multimedia ─────────────────────────────────────────────────────────
      {
        appId = "org.gimp.GIMP";
        origin = "flathub";
      }
      {
        appId = "org.videolan.VLC";
        origin = "flathub";
      }

      # ── Office ─────────────────────────────────────────────────────────────
      {
        appId = "org.libreoffice.LibreOffice";
        origin = "flathub";
      }
      {
        appId = "org.onlyoffice.desktopeditors";
        origin = "flathub";
      }

      # ── Knowledge & Communication ──────────────────────────────────────────
      # com.affine.AFFiNE — not on Flathub; use web app or check affine.pro for alternative install
      {
        appId = "io.appflowy.AppFlowy";
        origin = "flathub";
      }
      {
        appId = "com.tutanota.Tutanota";
        origin = "flathub";
      }

      # ── Terminals ──────────────────────────────────────────────────────────
      {
        appId = "app.devsuite.Ptyxis";
        origin = "flathub";
      } # Ptyxis terminal (GSettings schema org.gnome.Ptyxis — themed via shared host dconf, org/gnome/Ptyxis/Profiles/steelbore)

      # ── Productivity ───────────────────────────────────────────────────────
      {
        appId = "io.github.Qalculate";
        origin = "flathub";
      }
      # org.kde.yakuake removed — kdePackages.yakuake (nixpkgs) is the single
      # delivery; it inherits the generated Konsole Steelbore profile.

      # ── AI ─────────────────────────────────────────────────────────────────
      # Alpaca — GTK4/libadwaita GUI client for Ollama (GPL-3.0-or-later).
      # Re-enabled now that the Ollama service is back on (hosts/common.nix,
      # `steelbore.services.ollama.enable`); the old "DISABLED with Ollama"
      # note predated that. Flatpak rather than nixpkgs per the delivery
      # policy above — it is a sandbox-friendly GTK app that Flathub ships
      # ahead of the nixpkgs copy.
      #
      # Alpaca can manage its own bundled Ollama instance, but this host
      # already runs one as a system service on the default 127.0.0.1:11434.
      # Point Alpaca at that (Preferences → Instances → add a remote/local
      # instance at http://127.0.0.1:11434) rather than letting it start a
      # second copy — two servers would compete for the same models and RAM.
      {
        appId = "com.jeffser.Alpaca";
        origin = "flathub";
      }

      # ── Parked (disabled to reclaim disk; re-enable by uncommenting) ──────
      # ── Gaming ─────────────────────────────────────────────────────────────
      # DISABLED — commented out to reclaim disk space; re-enable to restore
      # { appId = "com.heroicgameslauncher.hgl";        origin = "flathub"; }  # Heroic
      # { appId = "com.usebottles.bottles";             origin = "flathub"; }
      # { appId = "com.valvesoftware.Steam";            origin = "flathub"; }
      # { appId = "info.beyondallreason.bar";           origin = "flathub"; }
      # { appId = "net.openra.OpenRA";                  origin = "flathub"; }
      # { appId = "net.wz2100.wz2100";                  origin = "flathub"; }  # Warzone 2100
      # { appId = "org.libretro.RetroArch";             origin = "flathub"; }
      # { appId = "org.openttd.OpenTTD";                origin = "flathub"; }

      # ── Retro / Classic Games ──────────────────────────────────────────────
      # DISABLED — commented out to reclaim disk space; re-enable to restore
      #
      # DOSBox and the ZDoom-family ports now ship from nixpkgs — see
      # modules/packages/games.nix. Do NOT un-park those: the delivery policy
      # above says nixpkgs unless huge-source-build or sandbox-hostile, and all
      # of them substitute from cache.nixos.org. Two copies would also mean two
      # separate data directories (~/.var/app/… vs ~/Games/), which is exactly
      # the confusion the policy exists to prevent. (org.libretro.RetroArch is a
      # different product — a multi-system frontend — and is not duplicated.)
      # { appId = "com.dosbox.DOSBox";                  origin = "flathub"; }
      # { appId = "com.dosbox_x.DOSBox-X";              origin = "flathub"; }
      # { appId = "com.play0ad.zeroad";                 origin = "flathub"; }  # 0 A.D.
      # { appId = "com.remnantsoftheprecursors.ROTP";   origin = "flathub"; }
      # { appId = "eu.jumplink.Learn6502";              origin = "flathub"; }
      # { appId = "io.github.dosbox-staging";           origin = "flathub"; }
      # { appId = "io.github.jotd666.gods-deluxe";      origin = "flathub"; }
      # { appId = "io.github.dman95.SASM";              origin = "flathub"; }  # Assembly IDE
      # { appId = "org.seul.crimson";                   origin = "flathub"; }  # Crimson Fields
      # { appId = "org.zdoom.UZDoom";                   origin = "flathub"; }
      # { appId = "rs.ruffle.Ruffle";                   origin = "flathub"; }
    ];

    # ── Keyring: Chromium credential backend ────────────────────────────────
    # Same root cause as the Nix-side wrappers in modules/packages/editors.nix:
    # Chromium reads XDG_CURRENT_DESKTOP to pick a credential backend, sees
    # "niri"/"leftwm", maps it to DE_OTHER, and falls back to plaintext storage
    # instead of the Secret Service. These apps' Flathub `cobalt` launchers do
    # read an imperative per-app ~/.var/app/<id>/config/<name>-flags.conf, but
    # that file is mutable user state outside Nix — override the variable the
    # detection actually reads instead, which stays declarative.
    #
    # Scoped to the sandbox, so unlike setting this session-wide it cannot
    # perturb host portal-backend selection or GTK app-menu behaviour. These are
    # all Chromium apps that draw their own chrome, so claiming GNOME inside the
    # sandbox costs nothing. Each already carries `org.freedesktop.secrets=talk`
    # in its Flathub manifest, so no extra bus permission is needed.
    services.flatpak.overrides.settings = lib.genAttrs [
      "com.google.Chrome"
      "com.microsoft.Edge"
      "com.opera.Opera"
      "com.brave.Browser"
      "com.discordapp.Discord"
      "io.wavebox.Wavebox"
      "com.visualstudio.code"
      "io.github.shiftey.Desktop"
    ] (_: { Environment.XDG_CURRENT_DESKTOP = "GNOME"; });
  };
}
