# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Home Manager: Margo compositor config
#
# ~/.config/margo/config.conf, written only when steelbore.desktops.margo is
# on. Writing it means margo never generates its own first-run config (which
# points at mshell, a shell Bravais does not build). Animations are tuned to
# mango's own defaults (slide in/out, long overshooting curves); the rest of
# the session reuses the Niri stack. `mctl check-config` validates the file
# and `Mod+Ctrl+R` reloads it in place.
{
  config,
  lib,
  pkgs,
  osConfig,
  steelborePalette,
  ...
}:

let
  # margo colors are 0xRRGGBBAA.
  rgba = hex: alpha: "0x${steelborePalette.convert.bareHex hex}${alpha}";
  wallpaperPkg = pkgs.awww or pkgs.swww;
  wallpaperBin = if pkgs ? awww then "awww" else "swww";
in
{
  config = lib.mkIf osConfig.steelbore.desktops.margo.enable {
    xdg.configFile."margo/config.conf".text = ''
      # Managed by Home Manager (users/mj/margo.nix) — edits here are replaced
      # on the next rebuild. Full reference:
      # /run/current-system/sw/share/doc/margo/config.example.conf

      # ── Look ──────────────────────────────────────────────────────────────
      borderpx          = 2
      border_radius     = 10
      gappih            = 10
      gappiv            = 10
      gappoh            = 10
      gappov            = 10
      focused_opacity   = 1.00
      unfocused_opacity = 0.92
      cursor_size       = 24

      rootcolor       = ${rgba steelborePalette.background "ff"}
      bordercolor     = ${rgba steelborePalette.border "ff"}
      focuscolor      = ${rgba steelborePalette.focus "ff"}
      urgentcolor     = ${rgba steelborePalette.error "ff"}
      scratchpadcolor = ${rgba steelborePalette.info "ff"}
      globalcolor     = ${rgba steelborePalette.structure "ff"}
      overlaycolor    = ${rgba steelborePalette.accent "ff"}
      shadowscolor    = ${rgba steelborePalette.background "99"}
      group_active_color   = ${rgba steelborePalette.focus "ff"}
      group_inactive_color = ${rgba steelborePalette.border "ff"}

      shadows              = 1
      shadow_only_floating = 1
      blur                 = 0

      # ── Animations: mango's defaults ──────────────────────────────────────
      # Windows slide in and out; the 0.46,1.0,0.29,1 curve is mango's long
      # ease-out. Movement stays on the bezier clock for mango parity; set
      # animation_clock_move = spring for margo's niri-style physics, which
      # keeps velocity when a move is interrupted mid-flight.
      animations              = 1
      layer_animations        = 1
      animation_type_open     = slide
      animation_type_close    = slide
      animation_fade_in       = 1
      animation_fade_out      = 1
      fadein_begin_opacity    = 0.50
      fadeout_begin_opacity   = 0.80
      tag_animation_direction = 0

      animation_duration_move  = 500
      animation_duration_open  = 400
      animation_duration_tag   = 350
      animation_duration_close = 800
      animation_duration_focus = 120

      animation_curve_move  = 0.46, 1.00, 0.29, 1.00
      animation_curve_open  = 0.46, 1.00, 0.29, 1.00
      animation_curve_tag   = 0.46, 1.00, 0.29, 1.00
      animation_curve_close = 0.08, 0.92, 0.00, 1.00
      animation_curve_focus = 0.46, 1.00, 0.29, 1.00

      animation_clock_move  = bezier
      animation_clock_open  = bezier
      animation_clock_close = bezier
      animation_clock_tag   = bezier
      animation_clock_focus = bezier
      animation_clock_layer = bezier

      # ── Layout ────────────────────────────────────────────────────────────
      default_layout              = scroller
      scroller_default_proportion = 0.800
      scroller_focus_center       = 1
      scroller_proportion_preset  = 1.000, 0.800, 0.618, 0.500

      # ── Input ─────────────────────────────────────────────────────────────
      xkb_rules_layout = us
      repeat_rate      = 35
      repeat_delay     = 250
      tap_to_click     = 1
      tap_and_drag     = 1

      # ── Session environment ───────────────────────────────────────────────
      # `:mango` keeps portal rules written for mango matching.
      env = XDG_CURRENT_DESKTOP, margo:mango
      env = XDG_SESSION_DESKTOP, margo
      env = XDG_SESSION_TYPE,    wayland
      env = NIXOS_OZONE_WL,      1
      env = QT_QPA_PLATFORM,     wayland;xcb

      # ── Startup: the Niri companion stack ─────────────────────────────────
      exec-once = ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
      exec-once = ${wallpaperPkg}/bin/${wallpaperBin}-daemon
      exec-once = sh -c "sleep 1 && ${wallpaperPkg}/bin/${wallpaperBin} img ${config.home.homeDirectory}/Pictures/Wallpapers/Steelbore/ChatGPT_Image_2026-09-30_16-46-13.png || ${wallpaperPkg}/bin/${wallpaperBin} clear ${steelborePalette.convert.bareHex steelborePalette.background}"
      exec-once = eww open bar
      exec-once = dunst
      exec-once = swayosd-server
      exec-once = swayidle -w timeout 300 'gtklock -d' timeout 360 'mctl dispatch dpms off' resume 'mctl dispatch dpms on' before-sleep 'gtklock -d'
      exec-once = ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1
      exec-once = sh -c "sleep 5 && steelbore-keyring-check"

      # ── Launch ────────────────────────────────────────────────────────────
      bind = super,Return,spawn,alacritty
      bind = super,d,spawn,anyrun
      bind = super,b,spawn,alacritty -e bluetui
      bind = super+shift,b,spawn,overskride
      bind = super+shift,a,spawn,pavucontrol

      # ── Windows ───────────────────────────────────────────────────────────
      bind = super,q,killclient
      bind = super,f,togglefullscreen
      bind = super+shift,space,togglefloating
      bind = super,h,focusdir,left
      bind = super,j,focusdir,down
      bind = super,k,focusdir,up
      bind = super,l,focusdir,right
      bind = super,Left,focusdir,left
      bind = super,Down,focusdir,down
      bind = super,Up,focusdir,up
      bind = super,Right,focusdir,right
      bind = super+shift,h,exchange_client,left
      bind = super+shift,j,exchange_client,down
      bind = super+shift,k,exchange_client,up
      bind = super+shift,l,exchange_client,right
      bind = super+ctrl,h,movewin,-40,0
      bind = super+ctrl,j,movewin,0,40
      bind = super+ctrl,k,movewin,0,-40
      bind = super+ctrl,l,movewin,40,0
      bind = super+ctrl+shift,h,resizewin,-40,0
      bind = super+ctrl+shift,j,resizewin,0,40
      bind = super+ctrl+shift,k,resizewin,0,-40
      bind = super+ctrl+shift,l,resizewin,40,0
      bind = super,Tab,focusstack,1
      bind = super+shift,Tab,focusstack,-1
      bind = super,z,zoom
      bind = super+ctrl,s,sticky_window
      bind = alt,Tab,mru_next
      bind = alt+shift,Tab,mru_prev
      mousebind = super,lmb,moveresize,curmove
      mousebind = super,rmb,moveresize,curresize

      # ── Tags 1-9 (bitmask arguments) ──────────────────────────────────────
      bind = super,1,view,1
      bind = super,2,view,2
      bind = super,3,view,4
      bind = super,4,view,8
      bind = super,5,view,16
      bind = super,6,view,32
      bind = super,7,view,64
      bind = super,8,view,128
      bind = super,9,view,256
      bind = super,0,view,4294967295
      bind = super+shift,1,tag,1
      bind = super+shift,2,tag,2
      bind = super+shift,3,tag,4
      bind = super+shift,4,tag,8
      bind = super+shift,5,tag,16
      bind = super+shift,6,tag,32
      bind = super+shift,7,tag,64
      bind = super+shift,8,tag,128
      bind = super+shift,9,tag,256
      bind = super,Page_Up,viewtoleft
      bind = super,Page_Down,viewtoright
      bind = super+ctrl,Page_Up,tagtoleft
      bind = super+ctrl,Page_Down,tagtoright
      gesturebind = NONE,left,3,viewtoright
      gesturebind = NONE,right,3,viewtoleft

      # ── Layout ────────────────────────────────────────────────────────────
      bind = super,space,switch_layout
      bind = super,t,setlayout,tile
      bind = super,s,setlayout,scroller
      bind = super,m,setlayout,monocle
      bind = super+ctrl,g,setlayout,grid
      bind = super,r,switch_proportion_preset
      bind = super+shift,r,set_proportion,0.500
      bind = super+shift,g,togglegaps
      bind = super,w,togglegroup
      bind = super,e,changegroupactive,next
      bind = super+shift,e,changegroupactive,prev

      # ── Scratchpad ────────────────────────────────────────────────────────
      bind = super+ctrl,Return,toggle_named_scratchpad,^dropdown-terminal$,none,alacritty --class dropdown-terminal
      bind = super+ctrl,Escape,unscratchpad

      # ── Screenshots ───────────────────────────────────────────────────────
      bind = NONE,Print,spawn,sh -c 'grim -g "$(slurp)" - | wl-copy'
      bind = ctrl,Print,spawn,sh -c 'grim - | wl-copy'

      # ── Hardware keys (same helpers as Niri) ──────────────────────────────
      bind = NONE,XF86MonBrightnessUp,spawn,swayosd-client --brightness raise
      bind = NONE,XF86MonBrightnessDown,spawn,swayosd-client --brightness lower
      bind = NONE,XF86AudioRaiseVolume,spawn,swayosd-client --output-volume raise
      bind = NONE,XF86AudioLowerVolume,spawn,swayosd-client --output-volume lower
      bind = NONE,XF86AudioMute,spawn,swayosd-client --output-volume mute-toggle
      bind = NONE,XF86AudioMicMute,spawn,sh -c 'wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle && swayosd-client --input-volume mute-toggle'
      bind = NONE,XF86AudioPlay,spawn,playerctl play-pause
      bind = NONE,XF86AudioNext,spawn,playerctl next
      bind = NONE,XF86AudioPrev,spawn,playerctl previous
      bind = NONE,XF86AudioStop,spawn,playerctl stop
      bind = NONE,XF86KbdLightOnOff,spawn,steelbore-kbd-light-cycle
      bind = NONE,XF86Bluetooth,spawn,steelbore-bt-toggle
      bind = NONE,XF86RFKill,spawn,steelbore-airplane-toggle

      # ── System ────────────────────────────────────────────────────────────
      # Lock is Alt+L: Super+Shift+L (Niri's lock) moves a window right here.
      bind = alt,l,spawn,gtklock
      bind = super+shift,c,spawn,steelbore-caffeine
      bind = super+shift,u,spawn,steelbore-keyring-unlock
      bind = super,F10,dpms,toggle
      bind = super+ctrl,r,reload_config
      bind = super+shift,q,quit
    '';
  };
}
