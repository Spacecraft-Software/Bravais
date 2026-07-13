# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Home Manager: Niri compositor + bars + OSD/idle user configs
# Split from home.nix in Phase D (elegance plan 3.1); zero behavior change.
{
  pkgs,
  steelborePalette,
  ...
}:

let
  # Wallpaper daemon: upstream renamed swww → awww. On unstable both
  # exist (swww is a deprecation alias that warns); on stable 25.11
  # only swww. The `or`-fallback picks the right package per channel;
  # binary names follow the package name (awww/awww-daemon vs
  # swww/swww-daemon), so wallpaperBin tracks. Mirrors the system-wide
  # logic in modules/desktops/niri.nix.
  wallpaperPkg = pkgs.awww or pkgs.swww;
  wallpaperBin = if pkgs ? awww then "awww" else "swww";
in
{
  xdg.configFile = {
    "swayosd/config.toml".text = ''
      [server]
      max_volume = 100
      style = "/home/mj/.config/swayosd/style.css"
    '';

    # swayidle — idle management under Niri (spawned via the Niri config's
    # spawn-at-startup "swayidle" "-w"). Auto-locks then blanks on idle, and
    # locks before suspend. The Caffeine toggle (Mod+Shift+C → steelbore-
    # caffeine, defined in modules/desktops/niri.nix) SIGSTOPs swayidle to
    # keep the machine awake on demand. niri restores monitors on input, but
    # the explicit resume power-on is a harmless safety net.
    "swayidle/config".text = ''
      timeout 300 'gtklock -d'
      timeout 360 'niri msg action power-off-monitors' resume 'niri msg action power-on-monitors'
      before-sleep 'gtklock -d'
    '';

    "swayosd/style.css".text = ''
      /* Steelbore SwayOSD theme — Void Navy / Molten Amber */
      window#osd {
        padding: 12px 18px;
        border-radius: 12px;
        border: 1px solid ${steelborePalette.steelBlue};
        background-color: ${steelborePalette.voidNavy};
      }

      window#osd #container {
        margin: 14px;
      }

      window#osd image,
      window#osd label {
        color: ${steelborePalette.moltenAmber};
      }

      window#osd progressbar {
        min-height: 6px;
        border-radius: 999px;
        background: transparent;
      }

      window#osd trough {
        min-height: 6px;
        border-radius: 999px;
        background-color: ${steelborePalette.steelBlue};
      }

      window#osd progress {
        min-height: 6px;
        border-radius: 999px;
        background-color: ${steelborePalette.moltenAmber};
      }

      /* Muted state — desaturate the bar to the warning color. */
      window#osd progressbar:disabled progress {
        background-color: ${steelborePalette.redOxide};
      }
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # NIRI — User configuration
    # ═══════════════════════════════════════════════════════════════════════════
    "niri/config.kdl".text = ''
      // Steelbore Niri User Configuration

      // XDG_CURRENT_DESKTOP routes xdg-desktop-portal lookups (see
      // xdg.portal.config.niri in modules/theme/dark-mode.nix). Niri
      // imports these into the systemd user env at session start.
      environment {
          XDG_CURRENT_DESKTOP "niri"
      }

      layout {
          gaps 8
          focus-ring {
              // off  — uncomment to disable; presence of the block enables it
              width 2
              active-color "${steelborePalette.moltenAmber}"
              inactive-color "${steelborePalette.steelBlue}"
          }
          border { off; }
          // Default column width
          default-column-width { proportion 0.5; }
          // Center focused column when it changes
          center-focused-column "on-overflow"
      }

      // Startup. The wallpaper daemon needs to bind its IPC socket before
      // any client command; the inline sleep gives it a moment before the
      // image is set. The wallpaper is a loose file in ~ (not Nix-managed), so
      // fall back to the solid Void Navy fill if it's ever missing.
      spawn-at-startup "${wallpaperPkg}/bin/${wallpaperBin}-daemon"
      spawn-at-startup "sh" "-c" "sleep 1 && ${wallpaperPkg}/bin/${wallpaperBin} img /home/mj/Pictures/Wallpapers/Steelbore/Steelbore_wallpaper_blue.png || ${wallpaperPkg}/bin/${wallpaperBin} clear ${steelborePalette.convert.bareHex steelborePalette.voidNavy}"
      spawn-at-startup "eww" "open" "bar"
      spawn-at-startup "dunst"
      // OSD daemon for the dedicated brightness/volume keys (binds below).
      // Auto-reads ~/.config/swayosd/{config.toml,style.css}.
      spawn-at-startup "swayosd-server"
      // Idle daemon — auto lock + screen-off (config: ~/.config/swayidle/config).
      // Toggle off on demand with Mod+Shift+C (Caffeine).
      spawn-at-startup "swayidle" "-w"
      // Load SSH key into gitway-agent once per session. With no TTY but
      // DISPLAY/WAYLAND_DISPLAY set, gitway-add uses $SSH_ASKPASS
      // (ksshaskpass) automatically. Cached for 24 h per the agent TTL.
      spawn-at-startup "gitway-add" "/home/mj/.ssh/id_ed25519"
      // Polkit authentication agent — shows password dialogs for privileged
      // ops (fingerprint enrollment, Flatpak installs, etc.).
      spawn-at-startup "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"

      input {
          keyboard {
              xkb {
                  layout "us,ar"
                  // grp:ctrl_space_toggle drives switching under X11/LeftWM, but
                  // is a no-op in Niri (Niri grabs keys for its own binds before
                  // xkbcommon's group-toggle action fires). The Mod+Space bind in
                  // `binds` below does the switching here. Kept for X11 parity.
                  options "grp:ctrl_space_toggle"
              }
          }
          touchpad {
              tap
              accel-speed 0.3
              natural-scroll
          }
      }

      // Key bindings.
      //
      // `hotkey-overlay-title="..."` populates Niri's show-hotkey-overlay
      // cheatsheet. Binds WITHOUT a title are still active but hidden
      // from the overlay — used here for secondary aliases (vim-style
      // movement that mirrors arrow-key binds, mouse-wheel workspace
      // nav, individual workspace 2-9 numbers that share the title of
      // the Mod+1 anchor entry).
      binds {
          // Session
          Mod+Shift+E hotkey-overlay-title="Exit niri" { quit; }
          Mod+Shift+L hotkey-overlay-title="Lock the Screen: gtklock" { spawn "gtklock"; }
          Mod+Shift+C hotkey-overlay-title="Toggle Caffeine (keep awake)" { spawn "steelbore-caffeine"; }
          // `Slash` is Niri's KDL name for the `/` key (US layout produces
          // `?` when shifted) — consistent with our use of symbolic names
          // (Minus, Equal, Return) elsewhere in the bind table.
          Mod+Shift+Slash hotkey-overlay-title="Show Important Hotkeys" { show-hotkey-overlay; }

          // Keyboard layout — toggle us ⇄ ar. Niri's native action (see the xkb
          // note above for why the grp: toggle alone doesn't switch here).
          Mod+Space hotkey-overlay-title="Switch Keyboard Layout (us/ar)" { switch-layout "next"; }

          // Applications
          Mod+Return hotkey-overlay-title="Open a Terminal: alacritty" { spawn "alacritty"; }
          Mod+D hotkey-overlay-title="Run an Application: anyrun" { spawn "anyrun"; }

          // Bluetooth managers (BlueZ clients; stack enabled in
          // modules/hardware/bluetooth.nix). The XF86Bluetooth key below
          // only toggles the radio (rfkill) — these connect/pair devices.
          Mod+B hotkey-overlay-title="Bluetooth Manager (TUI): bluetui" { spawn "alacritty" "-e" "bluetui"; }
          Mod+Shift+B hotkey-overlay-title="Bluetooth Manager (GUI): overskride" { spawn "overskride"; }

          // Audio mixers / output switchers (PipeWire; Niri has no audio
          // applet). The XF86Audio* keys above only adjust volume/mute via
          // swayosd — these switch the output device and per-app routing.
          Mod+A hotkey-overlay-title="Audio Mixer (TUI): wiremix" { spawn "alacritty" "-e" "wiremix"; }
          Mod+Shift+A hotkey-overlay-title="Audio Mixer (GUI): pavucontrol" { spawn "pavucontrol"; }

          // Window management
          Mod+Q hotkey-overlay-title="Close Focused Window" { close-window; }
          Mod+F hotkey-overlay-title="Maximize Column" { maximize-column; }
          Mod+Shift+F hotkey-overlay-title="Fullscreen Window" { fullscreen-window; }

          // Floating
          Mod+V hotkey-overlay-title="Toggle Window Floating" { toggle-window-floating; }
          Mod+Shift+V hotkey-overlay-title="Switch Focus Floating/Tiling" { switch-focus-between-floating-and-tiling; }

          // Overview
          Mod+O hotkey-overlay-title="Open the Overview" { toggle-overview; }

          // Focus — arrow-key primaries appear in the overlay; vim
          // duplicates are silent secondary aliases.
          Mod+Left  hotkey-overlay-title="Focus Column to the Left"  { focus-column-left; }
          Mod+Right hotkey-overlay-title="Focus Column to the Right" { focus-column-right; }
          Mod+Up    hotkey-overlay-title="Focus Window Up"           { focus-window-up; }
          Mod+Down  hotkey-overlay-title="Focus Window Down"         { focus-window-down; }
          Mod+H { focus-column-left; }
          Mod+L { focus-column-right; }
          Mod+K { focus-window-up; }
          Mod+J { focus-window-down; }

          // Move windows — Mod+Ctrl+arrows primaries (matches Niri's
          // default-config idioms); Mod+Shift+arrows and vim variants
          // are silent secondary aliases for muscle memory.
          Mod+Ctrl+Left  hotkey-overlay-title="Move Column Left"   { move-column-left; }
          Mod+Ctrl+Right hotkey-overlay-title="Move Column Right"  { move-column-right; }
          Mod+Ctrl+Up    hotkey-overlay-title="Move Window Up"     { move-window-up; }
          Mod+Ctrl+Down  hotkey-overlay-title="Move Window Down"   { move-window-down; }
          Mod+Shift+Left  { move-column-left; }
          Mod+Shift+Right { move-column-right; }
          Mod+Shift+Up    { move-window-up; }
          Mod+Shift+Down  { move-window-down; }
          // Mod+Shift+L is reserved for gtklock; vim moves use H/K/J only.
          Mod+Shift+H { move-column-left; }
          Mod+Shift+K { move-window-up; }
          Mod+Shift+J { move-window-down; }

          // Consume / Expel (column-folding) — square brackets per the
          // Niri default-config idiom. `BracketLeft`/`BracketRight` are
          // Niri's KDL names for `[`/`]`.
          Mod+BracketLeft  hotkey-overlay-title="Consume Window into Column" { consume-or-expel-window-left; }
          Mod+BracketRight hotkey-overlay-title="Expel Window into New Column" { consume-or-expel-window-right; }

          // Workspaces (Mod+1 is the anchor; 2-9 share the same
          // semantic title so the overlay isn't flooded).
          Mod+1 hotkey-overlay-title="Switch to Workspace 1-9" { focus-workspace 1; }
          Mod+2 { focus-workspace 2; }
          Mod+3 { focus-workspace 3; }
          Mod+4 { focus-workspace 4; }
          Mod+5 { focus-workspace 5; }
          Mod+6 { focus-workspace 6; }
          Mod+7 { focus-workspace 7; }
          Mod+8 { focus-workspace 8; }
          Mod+9 { focus-workspace 9; }
          Mod+Shift+1 hotkey-overlay-title="Move Column to Workspace 1-9" { move-column-to-workspace 1; }
          Mod+Shift+2 { move-column-to-workspace 2; }
          Mod+Shift+3 { move-column-to-workspace 3; }
          Mod+Shift+4 { move-column-to-workspace 4; }
          Mod+Shift+5 { move-column-to-workspace 5; }
          Mod+Shift+6 { move-column-to-workspace 6; }
          Mod+Shift+7 { move-column-to-workspace 7; }
          Mod+Shift+8 { move-column-to-workspace 8; }
          Mod+Shift+9 { move-column-to-workspace 9; }

          // Workspace navigation (relative)
          Mod+Page_Down hotkey-overlay-title="Switch Workspace Down" { focus-workspace-down; }
          Mod+Page_Up   hotkey-overlay-title="Switch Workspace Up"   { focus-workspace-up; }
          Mod+Ctrl+Page_Down hotkey-overlay-title="Move Column to Workspace Down" { move-column-to-workspace-down; }
          Mod+Ctrl+Page_Up   hotkey-overlay-title="Move Column to Workspace Up"   { move-column-to-workspace-up; }
          Mod+Tab hotkey-overlay-title="Switch to Previous Workspace" { focus-workspace-previous; }
          // Mouse-wheel workspace nav (silent — secondary, mouse-only).
          Mod+WheelScrollDown { focus-workspace-down; }
          Mod+WheelScrollUp   { focus-workspace-up; }

          // Resize
          Mod+R     hotkey-overlay-title="Switch Preset Column Widths" { switch-preset-column-width; }
          Mod+Minus hotkey-overlay-title="Decrease Column Width" { set-column-width "-10%"; }
          Mod+Equal hotkey-overlay-title="Increase Column Width" { set-column-width "+10%"; }

          // Screenshots
          Print     hotkey-overlay-title="Take a Screenshot" { screenshot; }
          Mod+Print hotkey-overlay-title="Screenshot Window" { screenshot-window; }

          // Dedicated / multimedia keys. Kept out of the hotkey overlay
          // (labelled hardware keys, not Mod-chords) and allow-when-locked
          // so they work over gtklock. Mirrors modules/desktops/niri.nix;
          // packages + udev rule + rfkill wrappers are system-level there.
          //
          // Brightness (display) — swayosd OSD bar
          XF86MonBrightnessUp   allow-when-locked=true { spawn "swayosd-client" "--brightness" "raise"; }
          XF86MonBrightnessDown allow-when-locked=true { spawn "swayosd-client" "--brightness" "lower"; }
          // Volume / mic — swayosd OSD bar (capped at 100% via config.toml)
          XF86AudioRaiseVolume  allow-when-locked=true { spawn "swayosd-client" "--output-volume" "raise"; }
          XF86AudioLowerVolume  allow-when-locked=true { spawn "swayosd-client" "--output-volume" "lower"; }
          XF86AudioMute         allow-when-locked=true { spawn "swayosd-client" "--output-volume" "mute-toggle"; }
          // Mic mute — wpctl performs the actual toggle. swayosd's
          // --input-volume mute-toggle is a no-op on this PipeWire build
          // (exits 0 without flipping source mute; verified 2026-07-07),
          // so we still call it just to pop the OSD bar. The
          // steelbore-audio-led daemon watches PipeWire mute state and
          // lights platform::micmute automatically once wpctl flips it.
          XF86AudioMicMute      allow-when-locked=true { spawn "sh" "-c" "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle && swayosd-client --input-volume mute-toggle"; }
          // Media (MPRIS) — playerctl, no OSD
          XF86AudioPlay { spawn "playerctl" "play-pause"; }
          XF86AudioNext { spawn "playerctl" "next"; }
          XF86AudioPrev { spawn "playerctl" "previous"; }
          XF86AudioStop { spawn "playerctl" "stop"; }
          // Keyboard backlight — the ThinkPad T490s F11 hotkey emits
          // XF86KbdLightOnOff (a single toggle key, not separate +/- keys).
          // steelbore-kbd-light-cycle wraps the 0→1→2→0 cycle.
          // XF86KbdBrightnessUp/Down remain for keyboards with separate keys.
          XF86KbdLightOnOff     allow-when-locked=true { spawn "steelbore-kbd-light-cycle"; }
          XF86KbdBrightnessUp   allow-when-locked=true { spawn "brightnessctl" "--device=tpacpi::kbd_backlight" "set" "+1"; }
          XF86KbdBrightnessDown allow-when-locked=true { spawn "brightnessctl" "--device=tpacpi::kbd_backlight" "set" "1-"; }
          // Radios — rfkill toggles with dunst feedback (wrappers in shared.nix)
          XF86Bluetooth allow-when-locked=true { spawn "steelbore-bt-toggle"; }
          XF86RFKill    allow-when-locked=true { spawn "steelbore-airplane-toggle"; }
       }
     '';
  };
}
