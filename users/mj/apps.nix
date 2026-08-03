# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Home Manager: Per-app user configs (Zellij, IRC, Flatpak overrides, CRD session)
# Split from home.nix in Phase D (elegance plan 3.1); zero behavior change.
{
  lib,
  pkgs,
  steelborePalette,
  ...
}:

let
  x256 = steelborePalette.convert.x256; # xterm-256 indices (tiny IRC)
  # Shared terminal-theme record + per-format emitters (plan item 1.2)

  # ZELLIJ — Full Steelbore config, rendered to a store file so it can be
  # installed as a *writable* copy (see home.activation.zellijConfig below).
  # Zellij persists config.kdl at runtime (e.g. its in-app Configuration
  # screen), so a read-only Nix-store symlink yields
  # "Failed to write configuration file". Nix stays source of truth: the
  # writable copy is refreshed on every activation.
  zellijConfigFile = pkgs.writeText "zellij-config.kdl" ''
    theme "steelbore"
    default_shell "${pkgs.nushell}/bin/nu"
    simplified_ui false
    pane_frames true
    mouse_mode true
    copy_on_select true
    // Bound per-pane scrollback so a flood of build output can't balloon the server's
    // memory (defense in depth alongside zram + earlyoom). Lower to 5000 if pressure persists.
    scroll_buffer_size 10000

    themes {
        steelbore {
            text_unselected {
                base "${steelborePalette.foreground}"
                background "${steelborePalette.background}"
                emphasis_0 "${steelborePalette.foreground}"
                emphasis_1 "${steelborePalette.info}"
                emphasis_2 "${steelborePalette.success}"
                emphasis_3 "${steelborePalette.accent}"
            }
            text_selected {
                base "${steelborePalette.foreground}"
                background "${steelborePalette.background}"
                emphasis_0 "${steelborePalette.foreground}"
                emphasis_1 "${steelborePalette.info}"
                emphasis_2 "${steelborePalette.success}"
                emphasis_3 "${steelborePalette.accent}"
            }
            ribbon_selected {
                base "${steelborePalette.background}"
                background "${steelborePalette.foreground}"
                emphasis_0 "${steelborePalette.error}"
                emphasis_1 "${steelborePalette.foreground}"
                emphasis_2 "${steelborePalette.accent}"
                emphasis_3 "${steelborePalette.accent}"
            }
            ribbon_unselected {
                base "${steelborePalette.background}"
                background "${steelborePalette.accent}"
                emphasis_0 "${steelborePalette.error}"
                emphasis_1 "${steelborePalette.foreground}"
                emphasis_2 "${steelborePalette.accent}"
                emphasis_3 "${steelborePalette.accent}"
            }
            table_title {
                base "${steelborePalette.success}"
                background 0
                emphasis_0 "${steelborePalette.foreground}"
                emphasis_1 "${steelborePalette.info}"
                emphasis_2 "${steelborePalette.success}"
                emphasis_3 "${steelborePalette.accent}"
            }
            table_cell_selected {
                base "${steelborePalette.foreground}"
                background "${steelborePalette.background}"
                emphasis_0 "${steelborePalette.foreground}"
                emphasis_1 "${steelborePalette.info}"
                emphasis_2 "${steelborePalette.success}"
                emphasis_3 "${steelborePalette.accent}"
            }
            table_cell_unselected {
                base "${steelborePalette.foreground}"
                background "${steelborePalette.background}"
                emphasis_0 "${steelborePalette.foreground}"
                emphasis_1 "${steelborePalette.info}"
                emphasis_2 "${steelborePalette.success}"
                emphasis_3 "${steelborePalette.accent}"
            }
            list_selected {
                base "${steelborePalette.foreground}"
                background "${steelborePalette.background}"
                emphasis_0 "${steelborePalette.foreground}"
                emphasis_1 "${steelborePalette.info}"
                emphasis_2 "${steelborePalette.success}"
                emphasis_3 "${steelborePalette.accent}"
            }
            list_unselected {
                base "${steelborePalette.foreground}"
                background "${steelborePalette.background}"
                emphasis_0 "${steelborePalette.foreground}"
                emphasis_1 "${steelborePalette.info}"
                emphasis_2 "${steelborePalette.success}"
                emphasis_3 "${steelborePalette.accent}"
            }
            frame_selected {
                base "${steelborePalette.foreground}"
                background 0
                emphasis_0 "${steelborePalette.foreground}"
                emphasis_1 "${steelborePalette.info}"
                emphasis_2 "${steelborePalette.accent}"
                emphasis_3 0
            }
            frame_highlight {
                base "${steelborePalette.foreground}"
                background 0
                emphasis_0 "${steelborePalette.accent}"
                emphasis_1 0
                emphasis_2 "${steelborePalette.foreground}"
                emphasis_3 "${steelborePalette.foreground}"
            }
            exit_code_success {
                base "${steelborePalette.success}"
                background 0
                emphasis_0 "${steelborePalette.info}"
                emphasis_1 "${steelborePalette.background}"
                emphasis_2 "${steelborePalette.accent}"
                emphasis_3 "${steelborePalette.accent}"
            }
            exit_code_error {
                base "${steelborePalette.error}"
                background 0
                emphasis_0 "${steelborePalette.foreground}"
                emphasis_1 0
                emphasis_2 0
                emphasis_3 0
            }
            multiplayer_user_colors {
                player_1 "${steelborePalette.accent}"
                player_2 "${steelborePalette.accent}"
                player_3 0
                player_4 "${steelborePalette.foreground}"
                player_5 "${steelborePalette.info}"
                player_6 0
                player_7 "${steelborePalette.error}"
                player_8 0
                player_9 0
                player_10 0
            }
        }
    }
  '';
in
{

  # Refresh the tealdeer (tldr) cache on every home-manager activation.
  # `tldr --update` pulls the latest pages bundle. Failure is non-fatal so
  # an offline rebuild still succeeds.
  home.activation.tldrUpdate = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.tealdeer}/bin/tldr --update >/dev/null 2>&1 || true
  '';

  # Install zellij's config.kdl as a writable file (see zellijConfigFile in the
  # let-block). Must be writable so zellij can persist runtime config changes
  # without erroring; refreshed each activation so Nix remains source of truth.
  home.activation.zellijConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD install -Dm644 ${zellijConfigFile} "$HOME/.config/zellij/config.kdl"
  '';

  # Default GUI file manager (COSMIC Files) and text editor (COSMIC Text
  # Editor). A Home Manager option, not per-DE — it writes
  # ~/.config/mimeapps.list, read by desktop-agnostic xdg-open/xdg-mime
  # regardless of which of the five session DEs is active. Independent of
  # EDITOR/VISUAL=msedit (shell.nix), which is the terminal editor.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = "com.system76.CosmicFiles.desktop";
      "text/plain" = "com.system76.CosmicEdit.desktop";
    };
  };

  xdg.configFile = {
    "containers/containers.conf".text = ''
      [engine]
      runtime = "runc"
    '';

    # tealdeer (tldr) — auto-update once a week on first invocation.
    # The home-manager activation script also forces a refresh on every
    # nixos-rebuild (see home.activation.tldrUpdate).
    "tealdeer/config.toml".text = ''
      [updates]
      auto_update = true
      auto_update_interval_hours = 168

      [display]
      use_pager = false
      compact = false
    '';
  };

  xdg.dataFile = {
    # ═══════════════════════════════════════════════════════════════════════════
    # D-BUS — org.freedesktop.FileManager1 → COSMIC Files
    # "Show in folder" in Chromium apps (Opera, Chrome, …) — and the portal's
    # OpenURI.OpenDirectory fallback — resolve the file manager by D-Bus
    # activation of org.freedesktop.FileManager1, NOT via the inode/directory
    # mimeapps default above. The GNOME module ships Nautilus's activation file
    # in the system profile, so Nautilus opened instead of COSMIC Files.
    # dbus-broker scans $XDG_DATA_HOME/dbus-1/services before XDG_DATA_DIRS
    # (first file claiming a name wins), so this user-level file shadows
    # Nautilus's. cosmic-files-applet claims the bus name and spawns
    # `cosmic-files <uri>` on ShowItems/ShowFolders; it also renders COSMIC
    # desktop icons for ~/Desktop as a transparent layer — invisible while
    # ~/Desktop stays empty. Reload dbus-broker (or re-login) after switch:
    #   systemctl --user reload dbus-broker.service
    # ═══════════════════════════════════════════════════════════════════════════
    "dbus-1/services/org.freedesktop.FileManager1.service".text = ''
      [D-BUS Service]
      Name=org.freedesktop.FileManager1
      Exec=${pkgs.cosmic-files}/bin/cosmic-files-applet
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # FLATPAK — VSCode per-app override
    # User-level override (wins over system/NixOS overrides). PATH MUST keep
    # /app/bin:/usr/bin first, otherwise flatpak's `code` entrypoint isn't found
    # and launch dies with `bwrap: execvp code: No such file or directory`. The
    # host bin dirs follow so VSCode's integrated terminal still sees host tools
    # (/run/current-system/sw/bin is also filesystem-exposed below).
    #
    # `force = true`: flatpak rewrites this file as a plain (read-only) file
    # out-of-band, so HM finds a foreign file at the path on the next switch
    # and — with a stale `.backup` already present — refuses to back it up
    # ("would be clobbered"). force makes HM overwrite unconditionally with
    # no backup attempt, so activation can't deadlock on this file again.
    # ═══════════════════════════════════════════════════════════════════════════
    "flatpak/overrides/com.visualstudio.code" = {
      force = true;
      text = ''
        [Context]
        sockets=session-bus;system-bus;gpg-agent;inherit-wayland-socket;
        devices=dri;kvm;shm;
        features=multiarch;per-app-dev-shm;
        filesystems=home;/home/mj/steelbore;host-etc;/run/current-system/sw/bin;/steelbore;host-os;

        [Environment]
        PATH=/app/bin:/usr/bin:/run/wrappers/bin:/home/mj/.local/share/flatpak/exports/bin:/var/lib/flatpak/exports/bin:/home/mj/.nix-profile/bin:/nix/profile/bin:/home/mj/.local/state/nix/profile/bin:/etc/profiles/per-user/mj/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin
      '';
    };

    # ═══════════════════════════════════════════════════════════════════════════
    # HALLOY — Rust + iced multi-server IRCv3 client (GUI)
    # ═══════════════════════════════════════════════════════════════════════════
    # Theme schema mirrors halloy's bundled `ferra.toml`. Servers are left
    # as a commented-out Libera Chat example — drop in your nick / channels
    # to start using.
    "halloy/config.toml".text = ''
      # Steelbore Halloy configuration
      theme = "spacecraft-software"

      [font]
      family = "JetBrainsMono Nerd Font"
      size = 13

      [buffer.timestamp]
      format = "%Y-%m-%d %H:%M:%S"

      # Example server (uncomment + fill in):
      # [servers.libera]
      # nickname = "your-nick"
      # server = "irc.libera.chat"
      # port = 6697
      # use_tls = true
      # channels = ["#nixos", "#rust"]
    '';

    "halloy/themes/spacecraft-software.toml".text = ''
      # Steelbore Halloy Theme — Void Navy / Molten Amber palette
      # Schema mirrors halloy/assets/themes/ferra.toml.

      [general]
      background          = "${steelborePalette.background}"
      horizontal_rule     = "${steelborePalette.accent}"
      scrollbar           = "${steelborePalette.accent}"
      unread_indicator    = "${steelborePalette.foreground}"
      highlight_indicator = "${steelborePalette.success}"
      border              = "${steelborePalette.accent}"

      [text]
      primary   = "${steelborePalette.foreground}"
      secondary = "${steelborePalette.accent}"
      tertiary  = "${steelborePalette.info}"
      success   = "${steelborePalette.success}"
      error     = "${steelborePalette.error}"
      warning   = "${steelborePalette.foreground}"
      info      = "${steelborePalette.info}"
      debug     = "${steelborePalette.accent}"
      trace     = "${steelborePalette.info}"

      [buffer]
      background            = "${steelborePalette.background}"
      background_text_input = "${steelborePalette.background}"
      background_title_bar  = "${steelborePalette.background}"
      timestamp             = "${steelborePalette.accent}"
      action                = "${steelborePalette.success}"
      topic                 = "${steelborePalette.foreground}"
      highlight             = "${steelborePalette.accent}"
      code                  = "${steelborePalette.info}"
      nickname              = "${steelborePalette.foreground}"
      nickname_offline      = "${steelborePalette.accent}"
      url                   = "${steelborePalette.info}"
      selection             = "${steelborePalette.accent}"
      border_selected       = "${steelborePalette.foreground}"

      [buffer.server_messages]
      default = "${steelborePalette.accent}"

      [buttons.primary]
      background                = "${steelborePalette.background}"
      background_hover          = "${steelborePalette.accent}"
      background_selected       = "${steelborePalette.foreground}"
      background_selected_hover = "${steelborePalette.success}"

      [buttons.secondary]
      background                = "${steelborePalette.background}"
      background_hover          = "${steelborePalette.accent}"
      background_selected       = "${steelborePalette.foreground}"
      background_selected_hover = "${steelborePalette.success}"

      # IRC mIRC-style formatting palette. Mappings mirror foot/wezterm
      # — entries the Steelbore palette doesn't model directly
      # (brown, magenta, pink, lightgrey) reuse the closest neighbor.
      [formatting]
      white      = "${steelborePalette.foreground}"
      black      = "${steelborePalette.background}"
      blue       = "${steelborePalette.accent}"
      green      = "${steelborePalette.success}"
      red        = "${steelborePalette.error}"
      brown      = "${steelborePalette.foreground}"
      magenta    = "${steelborePalette.accent}"
      orange     = "${steelborePalette.foreground}"
      yellow     = "${steelborePalette.foreground}"
      lightgreen = "${steelborePalette.success}"
      cyan       = "${steelborePalette.info}"
      lightcyan  = "${steelborePalette.info}"
      lightblue  = "${steelborePalette.info}"
      pink       = "${steelborePalette.error}"
      grey       = "${steelborePalette.accent}"
      lightgrey  = "${steelborePalette.foreground}"
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # TINY — Rust + crossterm multi-server IRC client (TUI)
    # ═══════════════════════════════════════════════════════════════════════════
    # Tiny is 256-color only (no truecolor), so palette colors are mapped
    # to their nearest xterm-256 indices:
    #   Void Navy      #000027 → 17  (#00005f)   [also use `default` for bg]
    #   Molten Amber   #D98E32 → 172 (#d78700)
    #   Steel Blue     #4B7EB0 → 67  (#5f87af)
    #   Radium Green   #50FA7B → 84  (#5fff87)
    #   Red Oxide      #FF5C5C → 203 (#ff5f5f)
    #   Liquid Coolant #8BE9FD → 123 (#87ffff)
    # `bg: default` inherits the host terminal's background — which on
    # Bravais is already Void Navy.
    "tiny/config.yml".text = ''
      # Steelbore Tiny configuration

      # Servers — fill in or use /connect at runtime.
      servers: []

      defaults:
          nicks: [unbreakablemj]
          realname: Mohamed Hammad
          join: []
          tls: true

      log_dir: "~/.local/share/tiny/logs"

      scrollback: 4096

      layout: aligned
      max_nick_length: 16

      # 256-color theme. See note above for the palette → index mapping.
      colors:
          # Per-nick color cycle through the palette.
          nick: [${toString x256.foreground}, ${toString x256.accent}, ${toString x256.success}, ${toString x256.info}, ${toString x256.error}, ${toString x256.success}, ${toString x256.accent}, ${toString x256.foreground}, ${toString x256.info}, ${toString x256.accent}]

          clear:
              fg: default
              bg: default

          user_msg:
              fg: ${toString x256.foreground}            # Molten Amber
              bg: default

          err_msg:
              fg: ${toString x256.error}            # Red Oxide
              bg: default
              attrs: [bold]

          topic:
              fg: ${toString x256.accent}             # Steel Blue
              bg: default
              attrs: [bold]

          cursor:
              fg: ${toString x256.background}             # Void Navy on Molten Amber
              bg: ${toString x256.foreground}

          join:
              fg: ${toString x256.success}             # Radium Green
              bg: default
              attrs: [bold]

          part:
              fg: ${toString x256.error}            # Red Oxide
              bg: default
              attrs: [bold]

          nick_change:
              fg: ${toString x256.success}             # Radium Green
              bg: default
              attrs: [bold]

          faded:
              fg: ${toString x256.accent}             # Steel Blue
              bg: default

          exit_dialogue:
              fg: ${toString x256.foreground}
              bg: ${toString x256.background}

          highlight:
              fg: ${toString x256.success}             # Radium Green for mentions
              bg: default
              attrs: [bold]

          completion:
              fg: ${toString x256.info}            # Liquid Coolant
              bg: default

          timestamp:
              fg: ${toString x256.accent}             # Steel Blue
              bg: default

          tab_active:
              fg: ${toString x256.foreground}            # Molten Amber
              bg: default
              attrs: [bold]

          tab_normal:
              fg: ${toString x256.accent}             # Steel Blue
              bg: default

          tab_new_msg:
              fg: ${toString x256.success}             # Radium Green
              bg: default

          tab_highlight:
              fg: ${toString x256.error}            # Red Oxide
              bg: default
              attrs: [bold]

          tab_joinpart:
              fg: ${toString x256.accent}             # Steel Blue
              bg: default
    '';
  };

  # Chrome Remote Desktop virtual-session launcher (see
  # modules/services/chrome-remote-desktop.nix). CRD starts a headless *X11*
  # virtual server and execs this file, so use LeftWM (Niri/GNOME here are
  # Wayland — CRD can't drive them). Launch leftwm directly under a fresh D-Bus,
  # NOT via the startx-based start-leftwm, which would spawn a second physical
  # Xorg that collides with CRD's virtual X.
  home.file.".chrome-remote-desktop-session" = {
    executable = true;
    text = ''
      #!${pkgs.runtimeShell}
      export GDK_BACKEND=x11
      export XDG_CURRENT_DESKTOP=leftwm
      exec ${pkgs.dbus}/bin/dbus-run-session -- ${pkgs.leftwm}/bin/leftwm
    '';
  };
}
