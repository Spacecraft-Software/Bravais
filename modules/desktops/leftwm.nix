# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — LeftWM Tiling Window Manager (X11)
{
  config,
  lib,
  pkgs,
  steelborePalette,
  ...
}:

{
  options.steelbore.desktops.leftwm = {
    enable = lib.mkEnableOption "LeftWM tiling window manager (X11)";
  };

  config = lib.mkIf config.steelbore.desktops.leftwm.enable (
    let
      # The LeftWM Themes wiki strongly recommends that
      # `~/.config/leftwm/themes/current` be a symlink rather than a real
      # directory — leftwm 0.5.x's path resolution intermittently fails to
      # find `current/up` when `current` is a directory containing files
      # (observed: "Global up script failed: IO error: No such file or
      # directory"). Ship the theme as one nix-store derivation and expose
      # it via a single xdg.configFile symlink.
      steelboreTheme = pkgs.linkFarm "leftwm-steelbore-theme" [
        # up/down are stubs: actual session bring-up happens in
        # `leftwm-xinitrc` (see modules/login/default.nix). leftwm-theme
        # tooling expects up/down to exist, so we ship empty no-ops.
        {
          name = "up";
          path = pkgs.writeShellScript "leftwm-steelbore-up" "exit 0";
        }
        {
          name = "down";
          path = pkgs.writeShellScript "leftwm-steelbore-down" "exit 0";
        }
        {
          name = "theme.ron";
          path = pkgs.writeText "leftwm-steelbore-theme.ron" ''
            // Steelbore LeftWM Theme
            (
                border_width: 2,
                margin: 8,
                workspace_margin: Some(8),
                default_border_color: "${steelborePalette.steelBlue}",
                floating_border_color: "${steelborePalette.liquidCool}",
                focused_border_color: "${steelborePalette.moltenAmber}",
                on_new_window_cmd: None,
            )
          '';
        }
        {
          name = "polybar.ini";
          path = pkgs.writeText "leftwm-steelbore-polybar.ini" ''
            ; Steelbore Polybar Configuration

            [colors]
            background = ${steelborePalette.voidNavy}
            foreground = ${steelborePalette.moltenAmber}
            accent = ${steelborePalette.steelBlue}
            success = ${steelborePalette.radiumGreen}
            warning = ${steelborePalette.redOxide}
            info = ${steelborePalette.liquidCool}

            [bar/steelbore]
            width = 100%
            height = 32
            fixed-center = true

            background = ''${colors.background}
            foreground = ''${colors.foreground}

            line-size = 2
            line-color = ''${colors.accent}

            border-bottom-size = 2
            border-bottom-color = ''${colors.accent}

            padding-left = 2
            padding-right = 2
            module-margin = 1

            font-0 = "Hack Nerd Font:size=12;2"
            font-1 = "JetBrainsMono Nerd Font:size=12;2"

            modules-left = leftwm-tags
            modules-center = date
            modules-right = cpu memory network

            cursor-click = pointer
            cursor-scroll = ns-resize

            [module/leftwm-tags]
            type = custom/script
            exec = leftwm-state -w "$LEFTWM_STATE_SOCKET" -t "$LEFTWM_THEME_DIR/template.liquid"
            tail = true

            [module/date]
            type = internal/date
            interval = 1
            date = "%Y-%m-%d"
            time = "%H:%M:%S"
            label = "%time% :: %date%"
            label-foreground = ''${colors.foreground}

            [module/cpu]
            type = internal/cpu
            interval = 1
            label = "CPU: %percentage%%"
            label-foreground = ''${colors.success}

            [module/memory]
            type = internal/memory
            interval = 1
            label = "RAM: %percentage_used%%"
            label-foreground = ''${colors.success}

            [module/network]
            type = internal/network
            interface-type = wireless
            interval = 1
            label-connected = "%essid%"
            label-connected-foreground = ''${colors.info}
            label-disconnected = "Offline"
            label-disconnected-foreground = ''${colors.warning}
          '';
        }
        {
          name = "template.liquid";
          path = pkgs.writeText "leftwm-steelbore-template.liquid" ''
            {% for tag in workspace.tags %}
            %{A1:leftwm-command "SendWorkspaceToTag {{ workspace.index }} {{ tag.index }}":}
            {% if tag.mine %}
            %{F${steelborePalette.moltenAmber}}%{+u}
            {% elsif tag.visible %}
            %{F${steelborePalette.liquidCool}}
            {% elsif tag.busy %}
            %{F${steelborePalette.steelBlue}}
            {% else %}
            %{F${steelborePalette.steelBlue}50}
            {% endif %}
              {{ tag.name }}
            %{-u}%{F-}%{A}
            {% endfor %}
          '';
        }
        {
          name = "picom.conf";
          path = pkgs.writeText "leftwm-steelbore-picom.conf" ''
            # Steelbore Picom Configuration
            backend = "glx";
            vsync = true;

            # Opacity
            active-opacity = 1.0;
            inactive-opacity = 0.95;
            frame-opacity = 1.0;

            # Fading
            fading = true;
            fade-delta = 5;
            fade-in-step = 0.03;
            fade-out-step = 0.03;

            # Rounded corners
            corner-radius = 0;

            # Shadows
            shadow = false;
          '';
        }
      ];
    in
    {
      # Enable X11. LeftWM is intentionally NOT registered via
      # services.xserver.windowManager.leftwm.enable — that path generates an
      # xsession .desktop whose Exec just runs `leftwm` directly. greetd does
      # not start Xorg (unlike SDDM/GDM/LightDM), so leftwm panics with a null
      # display pointer in a respawn loop. We register our own xsession in
      # modules/login/default.nix that wraps with startx instead.
      services.xserver.enable = true;

      # Wires up the per-user X plumbing startx needs:
      #   - /etc/X11/xinit/xserverrc telling xinit how to launch Xorg
      #   - services.xserver.exportConfiguration → /etc/X11/xorg.conf.d/*
      #   - xorg.xinit on systemPackages
      # Without this, `startx` in our session wrappers (start-leftwm,
      # start-plasma-x11) launches an Xorg that never finishes initializing
      # and the session hangs indefinitely.
      services.xserver.displayManager.startx.enable = true;

      # LeftWM and companion packages
      environment.systemPackages = with pkgs; [
        leftwm
        leftwm-theme
        leftwm-config

        # Launcher (rlaunch — Rust, X11)
        rlaunch
        rofi # Fallback launcher (also useful in scripts)
        dmenu # Minimal launcher

        # Status bar — Eww (Rust, cross-platform; shared with Niri)
        eww

        # Status bar — Polybar kept for transition; remove once Eww is stable
        polybar

        # Compositor
        picom # Compositor for transparency/effects

        # Notifications + utilities (cross-platform with Niri where applicable)
        dunst # Notification daemon (X11 + Wayland)
        gtklock # Lockscreen (X11 + Wayland via GTK)
        feh # Wallpaper / image viewer (X11)
        xclip # Clipboard
        xsel # Clipboard
        maim # Screenshot
        xdotool # X11 automation
        numlockx # NumLock control
      ];

      # LeftWM configuration
      home-manager.users.mj.xdg.configFile."leftwm/config.ron".text = ''
        // Steelbore LeftWM Configuration
        // The Spacecraft Software Standard — X11 Tiling

        #![enable(implicit_some)]
        (
            modkey: "Mod4",
            mousekey: "Mod4",
            workspaces: [],
            tags: ["1", "2", "3", "4", "5", "6", "7", "8", "9"],
            max_window_width: None,
            // `layouts` intentionally omitted. lefthk-core 0.2.2 (bundled
            // inside leftwm 0.5.4) ships its own config parser whose schema
            // expects layouts as Vec<String>, while leftwm-core expects bare
            // enum variants. Including the field in either form breaks one
            // of the two parsers — when lefthk's parse fails, it silently
            // falls back to a Mod+Shift+* default keymap, making every
            // user-defined Mod-only binding (Mod+Return, Mod+D, Mod+Q…) a
            // no-op. Omitting the field lets lefthk parse the rest of the
            // config; leftwm still gets a working layout set from its
            // built-in defaults. Re-add the explicit list once leftwm and
            // lefthk-core ship a unified config schema.
            layout_mode: Tag,
            insert_behavior: Bottom,
            scratchpad: [
                // alacritty, not rio — rio renders blank under leftwm's
                // startx-spawned Xorg (see the Mod+Return note below).
                (name: "Terminal", value: "alacritty", x: 50, y: 50, width: 1200, height: 800),
            ],
            window_rules: [],
            disable_current_tag_swap: false,
            disable_tile_drag: false,
            disable_window_snap: false,
            focus_behaviour: Sloppy,
            focus_new_windows: true,
            single_window_border: true,
            sloppy_mouse_follows_focus: true,
            auto_derive_workspaces: true,
            keybind: [
                // Session
                (command: Execute, value: "loginctl kill-session $XDG_SESSION_ID", modifier: ["modkey", "Shift"], key: "e"),
                (command: Execute, value: "gtklock", modifier: ["Control", "Alt"], key: "l"),

                // Applications
                // Mod+Return launches alacritty — the default terminal across
                // both Niri and LeftWM. rio's wgpu backend prefers Wayland and
                // renders nothing visible under leftwm's startx-spawned Xorg, so
                // alacritty's stable X11 backend is doubly the right choice here.
                (command: Execute, value: "alacritty", modifier: ["modkey"], key: "Return"),
                (command: Execute, value: "rlaunch", modifier: ["modkey"], key: "d"),
                (command: Execute, value: "rofi -show drun", modifier: ["modkey", "Shift"], key: "d"),

                // Window management
                (command: CloseWindow, value: "", modifier: ["modkey"], key: "q"),
                (command: ToggleFullScreen, value: "", modifier: ["modkey"], key: "f"),
                (command: ToggleFloating, value: "", modifier: ["modkey", "Shift"], key: "f"),

                // Focus / Move — only Up/Down survive. lefthk-core 0.2.2's
                // BaseCommand enum is missing FocusWindowLeft, FocusWindowRight,
                // MoveWindowLeft, and MoveWindowRight; including any of those
                // panics lefthk's parser and disables every keybinding. With
                // focus_behaviour: Sloppy, mouse hover already covers
                // left/right focus; tile-drag handles left/right window moves.
                (command: FocusWindowUp, value: "", modifier: ["modkey"], key: "k"),
                (command: FocusWindowDown, value: "", modifier: ["modkey"], key: "j"),
                (command: FocusWindowUp, value: "", modifier: ["modkey"], key: "Up"),
                (command: FocusWindowDown, value: "", modifier: ["modkey"], key: "Down"),
                (command: MoveWindowUp, value: "", modifier: ["modkey", "Shift"], key: "k"),
                (command: MoveWindowDown, value: "", modifier: ["modkey", "Shift"], key: "j"),

                // Layouts
                (command: NextLayout, value: "", modifier: ["modkey"], key: "space"),
                (command: PreviousLayout, value: "", modifier: ["modkey", "Shift"], key: "space"),

                // Workspaces
                (command: GotoTag, value: "1", modifier: ["modkey"], key: "1"),
                (command: GotoTag, value: "2", modifier: ["modkey"], key: "2"),
                (command: GotoTag, value: "3", modifier: ["modkey"], key: "3"),
                (command: GotoTag, value: "4", modifier: ["modkey"], key: "4"),
                (command: GotoTag, value: "5", modifier: ["modkey"], key: "5"),
                (command: GotoTag, value: "6", modifier: ["modkey"], key: "6"),
                (command: GotoTag, value: "7", modifier: ["modkey"], key: "7"),
                (command: GotoTag, value: "8", modifier: ["modkey"], key: "8"),
                (command: GotoTag, value: "9", modifier: ["modkey"], key: "9"),
                (command: MoveToTag, value: "1", modifier: ["modkey", "Shift"], key: "1"),
                (command: MoveToTag, value: "2", modifier: ["modkey", "Shift"], key: "2"),
                (command: MoveToTag, value: "3", modifier: ["modkey", "Shift"], key: "3"),
                (command: MoveToTag, value: "4", modifier: ["modkey", "Shift"], key: "4"),
                (command: MoveToTag, value: "5", modifier: ["modkey", "Shift"], key: "5"),
                (command: MoveToTag, value: "6", modifier: ["modkey", "Shift"], key: "6"),
                (command: MoveToTag, value: "7", modifier: ["modkey", "Shift"], key: "7"),
                (command: MoveToTag, value: "8", modifier: ["modkey", "Shift"], key: "8"),
                (command: MoveToTag, value: "9", modifier: ["modkey", "Shift"], key: "9"),

                // Resize
                (command: IncreaseMainWidth, value: "5", modifier: ["modkey"], key: "equal"),
                (command: DecreaseMainWidth, value: "5", modifier: ["modkey"], key: "minus"),

                // Scratchpad
                (command: ToggleScratchPad, value: "Terminal", modifier: ["modkey"], key: "grave"),
            ],
            state_path: None,
        )
      '';

      # LeftWM theme — single symlink to a nix-store directory containing
      # all theme files. See the steelboreTheme let-binding above.
      home-manager.users.mj.xdg.configFile."leftwm/themes/current".source = steelboreTheme;

    }
  );
}
