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
                base "${steelborePalette.moltenAmber}"
                background "${steelborePalette.voidNavy}"
                emphasis_0 "${steelborePalette.moltenAmber}"
                emphasis_1 "${steelborePalette.liquidCool}"
                emphasis_2 "${steelborePalette.radiumGreen}"
                emphasis_3 "${steelborePalette.steelBlue}"
            }
            text_selected {
                base "${steelborePalette.moltenAmber}"
                background "${steelborePalette.voidNavy}"
                emphasis_0 "${steelborePalette.moltenAmber}"
                emphasis_1 "${steelborePalette.liquidCool}"
                emphasis_2 "${steelborePalette.radiumGreen}"
                emphasis_3 "${steelborePalette.steelBlue}"
            }
            ribbon_selected {
                base "${steelborePalette.voidNavy}"
                background "${steelborePalette.moltenAmber}"
                emphasis_0 "${steelborePalette.redOxide}"
                emphasis_1 "${steelborePalette.moltenAmber}"
                emphasis_2 "${steelborePalette.steelBlue}"
                emphasis_3 "${steelborePalette.steelBlue}"
            }
            ribbon_unselected {
                base "${steelborePalette.voidNavy}"
                background "${steelborePalette.steelBlue}"
                emphasis_0 "${steelborePalette.redOxide}"
                emphasis_1 "${steelborePalette.moltenAmber}"
                emphasis_2 "${steelborePalette.steelBlue}"
                emphasis_3 "${steelborePalette.steelBlue}"
            }
            table_title {
                base "${steelborePalette.radiumGreen}"
                background 0
                emphasis_0 "${steelborePalette.moltenAmber}"
                emphasis_1 "${steelborePalette.liquidCool}"
                emphasis_2 "${steelborePalette.radiumGreen}"
                emphasis_3 "${steelborePalette.steelBlue}"
            }
            table_cell_selected {
                base "${steelborePalette.moltenAmber}"
                background "${steelborePalette.voidNavy}"
                emphasis_0 "${steelborePalette.moltenAmber}"
                emphasis_1 "${steelborePalette.liquidCool}"
                emphasis_2 "${steelborePalette.radiumGreen}"
                emphasis_3 "${steelborePalette.steelBlue}"
            }
            table_cell_unselected {
                base "${steelborePalette.moltenAmber}"
                background "${steelborePalette.voidNavy}"
                emphasis_0 "${steelborePalette.moltenAmber}"
                emphasis_1 "${steelborePalette.liquidCool}"
                emphasis_2 "${steelborePalette.radiumGreen}"
                emphasis_3 "${steelborePalette.steelBlue}"
            }
            list_selected {
                base "${steelborePalette.moltenAmber}"
                background "${steelborePalette.voidNavy}"
                emphasis_0 "${steelborePalette.moltenAmber}"
                emphasis_1 "${steelborePalette.liquidCool}"
                emphasis_2 "${steelborePalette.radiumGreen}"
                emphasis_3 "${steelborePalette.steelBlue}"
            }
            list_unselected {
                base "${steelborePalette.moltenAmber}"
                background "${steelborePalette.voidNavy}"
                emphasis_0 "${steelborePalette.moltenAmber}"
                emphasis_1 "${steelborePalette.liquidCool}"
                emphasis_2 "${steelborePalette.radiumGreen}"
                emphasis_3 "${steelborePalette.steelBlue}"
            }
            frame_selected {
                base "${steelborePalette.moltenAmber}"
                background 0
                emphasis_0 "${steelborePalette.moltenAmber}"
                emphasis_1 "${steelborePalette.liquidCool}"
                emphasis_2 "${steelborePalette.steelBlue}"
                emphasis_3 0
            }
            frame_highlight {
                base "${steelborePalette.moltenAmber}"
                background 0
                emphasis_0 "${steelborePalette.steelBlue}"
                emphasis_1 0
                emphasis_2 "${steelborePalette.moltenAmber}"
                emphasis_3 "${steelborePalette.moltenAmber}"
            }
            exit_code_success {
                base "${steelborePalette.radiumGreen}"
                background 0
                emphasis_0 "${steelborePalette.liquidCool}"
                emphasis_1 "${steelborePalette.voidNavy}"
                emphasis_2 "${steelborePalette.steelBlue}"
                emphasis_3 "${steelborePalette.steelBlue}"
            }
            exit_code_error {
                base "${steelborePalette.redOxide}"
                background 0
                emphasis_0 "${steelborePalette.moltenAmber}"
                emphasis_1 0
                emphasis_2 0
                emphasis_3 0
            }
            multiplayer_user_colors {
                player_1 "${steelborePalette.steelBlue}"
                player_2 "${steelborePalette.steelBlue}"
                player_3 0
                player_4 "${steelborePalette.moltenAmber}"
                player_5 "${steelborePalette.liquidCool}"
                player_6 0
                player_7 "${steelborePalette.redOxide}"
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
      background          = "${steelborePalette.voidNavy}"
      horizontal_rule     = "${steelborePalette.steelBlue}"
      scrollbar           = "${steelborePalette.steelBlue}"
      unread_indicator    = "${steelborePalette.moltenAmber}"
      highlight_indicator = "${steelborePalette.radiumGreen}"
      border              = "${steelborePalette.steelBlue}"

      [text]
      primary   = "${steelborePalette.moltenAmber}"
      secondary = "${steelborePalette.steelBlue}"
      tertiary  = "${steelborePalette.liquidCool}"
      success   = "${steelborePalette.radiumGreen}"
      error     = "${steelborePalette.redOxide}"
      warning   = "${steelborePalette.moltenAmber}"
      info      = "${steelborePalette.liquidCool}"
      debug     = "${steelborePalette.steelBlue}"
      trace     = "${steelborePalette.liquidCool}"

      [buffer]
      background            = "${steelborePalette.voidNavy}"
      background_text_input = "${steelborePalette.voidNavy}"
      background_title_bar  = "${steelborePalette.voidNavy}"
      timestamp             = "${steelborePalette.steelBlue}"
      action                = "${steelborePalette.radiumGreen}"
      topic                 = "${steelborePalette.moltenAmber}"
      highlight             = "${steelborePalette.steelBlue}"
      code                  = "${steelborePalette.liquidCool}"
      nickname              = "${steelborePalette.moltenAmber}"
      nickname_offline      = "${steelborePalette.steelBlue}"
      url                   = "${steelborePalette.liquidCool}"
      selection             = "${steelborePalette.steelBlue}"
      border_selected       = "${steelborePalette.moltenAmber}"

      [buffer.server_messages]
      default = "${steelborePalette.steelBlue}"

      [buttons.primary]
      background                = "${steelborePalette.voidNavy}"
      background_hover          = "${steelborePalette.steelBlue}"
      background_selected       = "${steelborePalette.moltenAmber}"
      background_selected_hover = "${steelborePalette.radiumGreen}"

      [buttons.secondary]
      background                = "${steelborePalette.voidNavy}"
      background_hover          = "${steelborePalette.steelBlue}"
      background_selected       = "${steelborePalette.moltenAmber}"
      background_selected_hover = "${steelborePalette.radiumGreen}"

      # IRC mIRC-style formatting palette. Mappings mirror foot/wezterm
      # — entries the Steelbore palette doesn't model directly
      # (brown, magenta, pink, lightgrey) reuse the closest neighbor.
      [formatting]
      white      = "${steelborePalette.moltenAmber}"
      black      = "${steelborePalette.voidNavy}"
      blue       = "${steelborePalette.steelBlue}"
      green      = "${steelborePalette.radiumGreen}"
      red        = "${steelborePalette.redOxide}"
      brown      = "${steelborePalette.moltenAmber}"
      magenta    = "${steelborePalette.steelBlue}"
      orange     = "${steelborePalette.moltenAmber}"
      yellow     = "${steelborePalette.moltenAmber}"
      lightgreen = "${steelborePalette.radiumGreen}"
      cyan       = "${steelborePalette.liquidCool}"
      lightcyan  = "${steelborePalette.liquidCool}"
      lightblue  = "${steelborePalette.liquidCool}"
      pink       = "${steelborePalette.redOxide}"
      grey       = "${steelborePalette.steelBlue}"
      lightgrey  = "${steelborePalette.moltenAmber}"
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
          nick: [${toString x256.moltenAmber}, ${toString x256.steelBlue}, ${toString x256.radiumGreen}, ${toString x256.liquidCool}, ${toString x256.redOxide}, ${toString x256.radiumGreen}, ${toString x256.steelBlue}, ${toString x256.moltenAmber}, ${toString x256.liquidCool}, ${toString x256.steelBlue}]

          clear:
              fg: default
              bg: default

          user_msg:
              fg: ${toString x256.moltenAmber}            # Molten Amber
              bg: default

          err_msg:
              fg: ${toString x256.redOxide}            # Red Oxide
              bg: default
              attrs: [bold]

          topic:
              fg: ${toString x256.steelBlue}             # Steel Blue
              bg: default
              attrs: [bold]

          cursor:
              fg: ${toString x256.voidNavy}             # Void Navy on Molten Amber
              bg: ${toString x256.moltenAmber}

          join:
              fg: ${toString x256.radiumGreen}             # Radium Green
              bg: default
              attrs: [bold]

          part:
              fg: ${toString x256.redOxide}            # Red Oxide
              bg: default
              attrs: [bold]

          nick_change:
              fg: ${toString x256.radiumGreen}             # Radium Green
              bg: default
              attrs: [bold]

          faded:
              fg: ${toString x256.steelBlue}             # Steel Blue
              bg: default

          exit_dialogue:
              fg: ${toString x256.moltenAmber}
              bg: ${toString x256.voidNavy}

          highlight:
              fg: ${toString x256.radiumGreen}             # Radium Green for mentions
              bg: default
              attrs: [bold]

          completion:
              fg: ${toString x256.liquidCool}            # Liquid Coolant
              bg: default

          timestamp:
              fg: ${toString x256.steelBlue}             # Steel Blue
              bg: default

          tab_active:
              fg: ${toString x256.moltenAmber}            # Molten Amber
              bg: default
              attrs: [bold]

          tab_normal:
              fg: ${toString x256.steelBlue}             # Steel Blue
              bg: default

          tab_new_msg:
              fg: ${toString x256.radiumGreen}             # Radium Green
              bg: default

          tab_highlight:
              fg: ${toString x256.redOxide}            # Red Oxide
              bg: default
              attrs: [bold]

          tab_joinpart:
              fg: ${toString x256.steelBlue}             # Steel Blue
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
