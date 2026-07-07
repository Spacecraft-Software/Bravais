# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — LeftWM Tiling Window Manager (X11)
{
  primaryUser,
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
      # Liquid template rendered by `leftwm-state -w 0 -n -t <path>` into
      # Eww yuck widget DSL. Each tag becomes a clickable button that calls
      # `leftwm-command 'SendWorkspaceToTag 0 <index>'` to switch tags.
      # The four CSS classes match tag states from LeftWM's DisplayState JSON:
      #   mine    — tag is owned by the active display AND focused
      #   visible — tag is shown on some display but not focused
      #   busy    — tag has windows but is not shown on any display
      #   (else)  — tag is empty and not shown
      workspaceTemplate = pkgs.writeText "leftwm-workspace-template.liquid" ''
        (box :orientation "h" :class "workspaces" :space-evenly true
        {% for tag in workspace.tags %}
        {% if tag.mine %}
          (button :class "ws-button-mine" :onclick "leftwm-command 'SendWorkspaceToTag 0 {{tag.index}}'" " {{ tag.name }} ")
        {% elsif tag.visible %}
          (button :class "ws-button-visible" :onclick "leftwm-command 'SendWorkspaceToTag 0 {{tag.index}}'" " {{ tag.name }} ")
        {% elsif tag.busy %}
          (button :class "ws-button-busy" :onclick "leftwm-command 'SendWorkspaceToTag 0 {{tag.index}}'" " {{ tag.name }} ")
        {% else %}
          (button :class "ws-button" :onclick "leftwm-command 'SendWorkspaceToTag 0 {{tag.index}}'" " {{ tag.name }} ")
        {% endif %}
        {% endfor %}
        )
      '';

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
      home-manager.users.${primaryUser}.xdg.configFile = {
        "leftwm/config.ron".text = ''
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
        "leftwm/themes/current".source = steelboreTheme;

        # ═══════════════════════════════════════════════════════════════════════════
        # EWW — LeftWM (X11) status bar.
        # Lives under eww-leftwm/ (a separate Eww config directory) so it
        # doesn't collide with the Niri Eww config in users/mj/eww.nix.
        # Launched via `eww open bar --config ~/.config/eww-leftwm` from
        # the LeftWM session startup script (modules/login/default.nix).
        # ═══════════════════════════════════════════════════════════════════════════
        "eww-leftwm/eww.yuck".text = ''
          ;; Steelbore Eww — LeftWM bar widget

          (defpoll time    :interval "1s"  "date '+%Y-%m-%d %H:%M:%S'")
          (defpoll cpu     :interval "3s"  "top -bn1 -d 0.1 | awk '/^%Cpu/ {printf \"%d\", $2 + $4}'")
          (defpoll memory  :interval "5s"  "free | awk '/^Mem/ {printf \"%d\", $3 / $2 * 100}'")
          (defpoll battery :interval "30s" "cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo --")

          ;; Bluetooth radio state. `rfkill list bluetooth` "Soft blocked: yes"
          ;; means the radio is OFF; empty/missing output (no BT hardware or rfkill
          ;; unavailable) is also treated as off. The `bt` defpoll emits the Nerd
          ;; Font mdi-bluetooth glyph (U+F293) via printf with explicit UTF-8 bytes
          ;; — eww yuck string literals don't interpret \uXXXX escapes, so the
          ;; glyph has to arrive from the shell. `bt_state` keeps the on/off word
          ;; for the CSS class selector. 5 s; rfkill changes are user-initiated.
          (defpoll bt       :interval "5s" "printf '\\xEF\\x8A\\x93'")
          (defpoll bt_state :interval "5s"
            "rfkill list bluetooth 2>/dev/null | grep -q 'Soft blocked: yes' && echo off || echo on")

          ;; Network up/down. Scans /sys/class/net/* (skipping lo) for the first
          ;; interface whose operstate is "up" — works on any host without
          ;; hardcoding ifnames. `net` emits a Nerd Font glyph at the shell level:
          ;; mdi-wifi (U+F2A7) when the up iface is wireless (wl*/wlan*), mdi-
          ;; ethernet (U+F299) for a wired one, mdi-lan-disconnect (U+F2D3) when
          ;; none. `net_state` gives "up"/"down" for the CSS class. 5 s; reads
          ;; operstate which the kernel updates on link events.
          (defpoll net :interval "5s"
            "for IF in /sys/class/net/*; do [ \"\''${IF}\" = /sys/class/net/lo ] && continue; [ \"$(cat \"\''${IF}/operstate\" 2>/dev/null)\" = up ] || continue; IFACE=\"$(basename \"\''${IF}\")\"; case \"\''${IFACE}\" in wl*|wlan*) printf '\\xEF\\x8A\\xA7';; *) printf '\\xEF\\x8A\\x99';; esac; exit 0; done; printf '\\xEF\\x8B\\x93'")
          (defpoll net_state :interval "5s"
            "for IF in /sys/class/net/*; do [ \"\''${IF}\" = /sys/class/net/lo ] && continue; [ \"$(cat \"\''${IF}/operstate\" 2>/dev/null)\" = up ] && { echo up; exit 0; }; done; echo down")

          ;; LeftWM IPC — event-driven workspace and window-title updates via
          ;; `leftwm-state`, which streams JSON from LeftWM's Unix domain socket
          ;; ($XDG_RUNTIME_DIR/leftwm/current_state.sock). `deflisten` reads
          ;; each new line, updating the variable instantly on every state change
          ;; (no polling). The `-n` flag preserves newlines in the Liquid template
          ;; output so the `literal` widget can parse the rendered yuck.
          (deflisten leftwm-ws "${pkgs.leftwm}/bin/leftwm-state -w 0 -n -t ${workspaceTemplate}")
          (deflisten window-title "${pkgs.leftwm}/bin/leftwm-state -w 0 -s '{{ window_title }}'")

          (defwidget bar []
            (centerbox :orientation "h"
              (box :orientation "h" :spacing 8 :halign "start"
                (literal :content leftwm-ws)
                (label :class {window-title == "" ? "title" : "window-title"} :halign "start" :text {window-title == "" ? "STEELBORE OS :: BRAVAIS" : window-title}))
              (label :class "clock" :text time)
              (box :orientation "h" :spacing 16 :halign "end" :class "metrics"
                ;; Bluetooth — glyph from `bt`, color from bt_state. Click handling
                ;; not wired (per user choice); XF86Bluetooth key still toggles radio.
                (label :class {bt_state == "on" ? "bt-on" : "bt-off"} :text bt)
                ;; Network — glyph from `net`, color from net_state.
                (label :class {net_state == "down" ? "net-down" : "net-up"} :text net)
                ;; Threshold colors: amber = warning, red = dangerous. CPU/RAM climb
                ;; (high is bad); battery drains (low is bad). "--" (no battery) stays
                ;; neutral. See .metric-warn / .metric-crit in eww.scss.
                (label :class {cpu    >= 90 ? "metric-crit" : cpu    >= 75 ? "metric-warn" : "metric"} :text "CPU ''${cpu}%")
                (label :class {memory >= 90 ? "metric-crit" : memory >= 75 ? "metric-warn" : "metric"} :text "RAM ''${memory}%")
                (label :class {battery == "--" ? "metric" : battery <= 15 ? "metric-crit" : battery <= 30 ? "metric-warn" : "metric"} :text "BAT ''${battery}%")
                ;; System tray — SNI/D-Bus protocol. Works natively on X11
                ;; (LeftWM); known issues on Wayland (not used here).
                (systray :class "tray" :icon-size 16 :spacing 4 :space-evenly false :prepend-new true))))

          (defwindow bar
            :monitor 0
            :geometry (geometry :x      "0"
                                :y      "0"
                                :width  "100%"
                                :height "32px"
                                :anchor "top center")
            :stacking    "fg"
            :reserve     (struts :distance "34px" :side "top")
            :windowtype  "dock"
            :wm-ignore   false
            (bar))
        '';

        "eww-leftwm/eww.scss".text = ''
          $voidNavy:    ${steelborePalette.voidNavy};
          $moltenAmber: ${steelborePalette.moltenAmber};
          $steelBlue:   ${steelborePalette.steelBlue};
          $radiumGreen: ${steelborePalette.radiumGreen};
          $liquidCool:  ${steelborePalette.liquidCool};
          $redOxide:    ${steelborePalette.redOxide};

          * {
              font-family: "JetBrainsMono Nerd Font", monospace;
              font-size: 13px;
              font-weight: bold;
          }

          window {
              background-color: $voidNavy;
              color: $moltenAmber;
              border-bottom: 2px solid $steelBlue;
              padding: 0 12px;
          }

          .title  { color: $moltenAmber; }
          .clock  { color: $liquidCool; }
          .metrics { padding-right: 12px; }
          .metric      { color: $radiumGreen; }  // normal
          .metric-warn { color: $moltenAmber; }  // >=75% cpu/ram, <=30% battery
          .metric-crit { color: $redOxide; }     // >=90% cpu/ram, <=15% battery

          // Radio / network indicators — on = radium green, off = dim steel blue,
          // network-down = red oxide (warning). Glyphs come from the Nerd Font
          // codepoints in eww.yuck; classes here only color them.
          .bt-on  { color: $radiumGreen; }
          .bt-off { color: $steelBlue; }
          .net-up   { color: $radiumGreen; }
          .net-down { color: $redOxide; }

          // ── LeftWM workspace buttons ──────────────────────────────────────
          // mine    = active/focused tag on the current display
          // visible = shown on some display but not focused
          // busy    = has windows but not shown on any display
          // (else)  = empty tag
          .workspaces {
              padding: 0 4px;
          }

          .ws-button-mine {
              color: $moltenAmber;
              border-bottom: 2px solid $moltenAmber;
              padding: 0 4px;
          }

          .ws-button-visible {
              color: $liquidCool;
              border-bottom: 2px solid $liquidCool;
              padding: 0 4px;
          }

          .ws-button-busy {
              color: $steelBlue;
              padding: 0 4px;
          }

          .ws-button {
              color: $steelBlue;
              opacity: 0.5;
              padding: 0 4px;
          }

          // ── Focused window title ──────────────────────────────────────────
          .window-title {
              color: $moltenAmber;
              max-width: 400px;
              text-overflow: ellipsis;
              overflow: hidden;
              white-space: nowrap;
          }

          // ── System tray ───────────────────────────────────────────────────
          .tray {
              padding: 0 4px;
          }
        '';
      };

    }
  );
}
