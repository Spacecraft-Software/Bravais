# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Shared bare-WM desktop services
#
# Config and helper wrappers consumed by BOTH bare window managers (Niri and
# LeftWM) live here, so disabling one WM cannot silently strip the other's
# config. First occupants: the dunst notification theme (dunst is spawned by
# Niri's spawn-at-startup AND LeftWM's session script) and the steelbore-*
# shell wrappers that both sessions' key binds call (rfkill toggles, caffeine,
# keyboard-backlight cycle, X11 OSD for LeftWM).
{
  config,
  lib,
  pkgs,
  steelborePalette,
  ...
}:

let
  # Bluetooth state detector — emits one of `off | on | connected` so the
  # Eww bar (bt/bt_state defpolls) and the toggle OSD share one truth
  # source. `off` = rfkill soft-blocked; `on` = radio up but no device
  # reports Connected: yes; `connected` = at least one paired device is
  # linked right now. Iterating `bluetoothctl info` per device is the
  # portable BlueZ way — there is no single built-in "is anything
  # connected?" query. Heavier than a pure rfkill check, but only the
  # known-device list (typically 1–3 entries) is walked every 5 s.
  btState = pkgs.writeShellScriptBin "steelbore-bt-state" ''
    set -eu
    # Check both Soft and Hard blocked (XanMod kernel may report Hard).
    # If rfkill has no bluetooth entry, fall through to bluetoothctl.
    rfkill_out=$(${pkgs.util-linux}/bin/rfkill list bluetooth 2>/dev/null || true)
    if echo "$rfkill_out" | grep -qE "(Soft|Hard) blocked: yes"; then
      echo off
      exit 0
    fi
    # rfkill may have no bluetooth entry at all (uncommon but observed).
    # Fall back to bluetoothctl D-Bus adapter power state.
    if [ -z "$rfkill_out" ]; then
      if ! ${pkgs.bluez}/bin/bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
        echo off
        exit 0
      fi
    fi
    devices=$(${pkgs.bluez}/bin/bluetoothctl devices 2>/dev/null | ${pkgs.gawk}/bin/awk '{print $2}' || true)
    for addr in $devices; do
      if [ -z "$addr" ]; then continue; fi
      if ${pkgs.bluez}/bin/bluetoothctl info "$addr" 2>/dev/null | grep -q "Connected: yes"; then
        echo connected
        exit 0
      fi
    done
    echo on
  '';

  # Radio toggles for the dedicated Bluetooth / airplane-mode keys.
  # rfkill works rootless: /dev/rfkill carries a systemd `uaccess` ACL for
  # the active-session user. Feedback goes through dunstify (dunst is
  # spawned by both sessions), since swayosd has no OSD for radio state.
  # `-r` reuses a fixed notification id so repeated presses replace
  # rather than stack. The off branch uses critical urgency so dunst
  # renders it in red oxide (the dunstrc urgency_critical palette) — the
  # toggle-off event is now as unmistakable as the toggle-on one.
  btToggle = pkgs.writeShellScriptBin "steelbore-bt-toggle" ''
    ${pkgs.util-linux}/bin/rfkill toggle bluetooth
    # Settle delay ensures the check below reads the *post*-toggle state.
    sleep 0.3
    rfkill_out=$(${pkgs.util-linux}/bin/rfkill list bluetooth 2>/dev/null || true)
    if echo "$rfkill_out" | grep -qE "(Soft|Hard) blocked: yes"; then
      ${pkgs.dunst}/bin/dunstify -a Bluetooth -r 9911 -u critical "Bluetooth Off"
    else
      ${pkgs.dunst}/bin/dunstify -a Bluetooth -r 9911 -u normal "Bluetooth On"
    fi
  '';
  airplaneToggle = pkgs.writeShellScriptBin "steelbore-airplane-toggle" ''
    ${pkgs.util-linux}/bin/rfkill toggle all
    if ${pkgs.util-linux}/bin/rfkill list wlan | grep -q "Soft blocked: yes"; then
      ${pkgs.dunst}/bin/dunstify -a Airplane -r 9912 -i airplane-mode "Airplane Mode On"
    else
      ${pkgs.dunst}/bin/dunstify -a Airplane -r 9912 -i network-wireless "Airplane Mode Off"
    fi
  '';

  # Caffeine — toggle the swayidle idle daemon (auto lock + screen-off,
  # configured in users/mj/niri.nix). SIGSTOP pauses swayidle so its idle
  # timers stop advancing (the machine stays awake); SIGCONT resumes
  # normal idle behaviour. State tracked by a runtime-dir flag; dunstify
  # reports the new state. Bound to Mod+Shift+C in the Niri config.
  caffeineToggle = pkgs.writeShellScriptBin "steelbore-caffeine" ''
    state="''${XDG_RUNTIME_DIR:-/tmp}/steelbore-caffeine.active"
    if [ -e "$state" ]; then
      ${pkgs.procps}/bin/pkill -CONT -x swayidle || true
      rm -f "$state"
      ${pkgs.dunst}/bin/dunstify -a Caffeine -r 9913 -i caffeine-cup-empty "Caffeine off — idle lock/blank resumed"
    else
      ${pkgs.procps}/bin/pkill -STOP -x swayidle || true
      : > "$state"
      ${pkgs.dunst}/bin/dunstify -a Caffeine -r 9913 -i caffeine-cup-full "Caffeine on — staying awake"
    fi
  '';

  # Keyboard-backlight cycle — the ThinkPad T490s has a single
  # XF86KbdLightOnOff hotkey (F11 in hotkey mode) rather than separate
  # +/- keys. Cycles tpacpi::kbd_backlight 0→1→2→0. The brightnessctl udev
  # rule (below) makes /sys/class/leds/tpacpi::kbd_backlight/brightness
  # group-writable (input), so this runs rootless.
  kbdLightCycle = pkgs.writeShellScriptBin "steelbore-kbd-light-cycle" ''
    dev=tpacpi::kbd_backlight
    cur=$(cat "/sys/class/leds/$dev/brightness")
    max=$(cat "/sys/class/leds/$dev/max_brightness")
    echo $(( (cur + 1) % (max + 1) )) > "/sys/class/leds/$dev/brightness"
  '';

  # X11 OSD for LeftWM — swayosd is Wayland-only (wlr-layer-shell), so
  # LeftWM hotkeys route through this wrapper instead. Performs the
  # wpctl/brightnessctl action AND emits a dunstify progress-bar popup
  # (replace-id → HUD feel). Niri keeps swayosd directly; this wrapper
  # is only called from LeftWM binds.
  #
  # Usage: steelbore-osd <action>
  #   volume-up | volume-down | volume-mute | mic-mute
  #   brightness-up | brightness-down
  osd = pkgs.writeShellScriptBin "steelbore-osd" ''
    set -eu
    bar() { # $1=percent $2=filled $3=empty
      filled=$2; empty=$3
      printf '%s' "$filled"; printf '%s' "$empty"
    }
    render_bar() { # $1=percent (0-100)
      pct=$1
      filled=$(( pct / 10 ))
      empty=$(( 10 - filled ))
      bar_str=""
      i=0; while [ $i -lt $filled ]; do bar_str="''${bar_str}▮"; i=$((i+1)); done
      i=0; while [ $i -lt $empty  ]; do bar_str="''${bar_str}░"; i=$((i+1)); done
      echo "$bar_str"
    }
    case "$1" in
      volume-up)
        ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
        vol=$( ${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2*100}' | awk '{printf "%d", $1}' )
        ${pkgs.dunst}/bin/dunstify -a Volume -r 9901 -i audio-volume-high "Volume $(render_bar $vol) $vol%"
        ;;
      volume-down)
        ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        vol=$( ${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2*100}' | awk '{printf "%d", $1}' )
        ${pkgs.dunst}/bin/dunstify -a Volume -r 9901 -i audio-volume-medium "Volume $(render_bar $vol) $vol%"
        ;;
      volume-mute)
        ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        if ${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED; then
          ${pkgs.dunst}/bin/dunstify -a Volume -r 9901 -i audio-volume-muted "Muted"
        else
          ${pkgs.dunst}/bin/dunstify -a Volume -r 9901 -i audio-volume-high "Unmuted"
        fi
        ;;
      mic-mute)
        ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        if ${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED; then
          ${pkgs.dunst}/bin/dunstify -a Mic -r 9902 -i microphone-sensitivity-muted "Mic Muted"
        else
          ${pkgs.dunst}/bin/dunstify -a Mic -r 9902 -i microphone-sensitivity-high "Mic Unmuted"
        fi
        ;;
      brightness-up)
        ${pkgs.brightnessctl}/bin/brightnessctl set +10%
        pct=$( ${pkgs.brightnessctl}/bin/brightnessctl info | awk -F'[()%]' '/Current/ {print $4}' )
        ${pkgs.dunst}/bin/dunstify -a Brightness -r 9903 -i display-brightness "Brightness $(render_bar $pct) $pct%"
        ;;
      brightness-down)
        ${pkgs.brightnessctl}/bin/brightnessctl set 10%-
        pct=$( ${pkgs.brightnessctl}/bin/brightnessctl info | awk -F'[()%]' '/Current/ {print $4}' )
        ${pkgs.dunst}/bin/dunstify -a Brightness -r 9903 -i display-brightness-low "Brightness $(render_bar $pct) $pct%"
        ;;
      *)
        echo "Usage: steelbore-osd {volume-up|volume-down|volume-mute|mic-mute|brightness-up|brightness-down}" >&2
        exit 1
        ;;
    esac
  '';
in
{
  config =
    lib.mkIf (config.steelbore.desktops.leftwm.enable || config.steelbore.desktops.niri.enable)
      {
        # Dunst notification configuration
        environment.etc."dunst/dunstrc".text = ''
          # Steelbore Dunst Configuration
          [global]
          monitor = 0
          follow = mouse
          width = 350
          height = 150
          origin = top-right
          offset = 10x40

          transparency = 5
          padding = 16
          horizontal_padding = 16
          frame_width = 2
          frame_color = "${steelborePalette.steelBlue}"
          separator_color = frame

          font = "Hack Nerd Font 12"
          line_height = 0
          markup = full
          format = "<b>%s</b>\n%b"
          alignment = left

          icon_position = left
          max_icon_size = 48

          [urgency_low]
          background = "${steelborePalette.voidNavy}"
          foreground = "${steelborePalette.liquidCool}"
          timeout = 5

          [urgency_normal]
          background = "${steelborePalette.voidNavy}"
          foreground = "${steelborePalette.moltenAmber}"
          timeout = 10

          [urgency_critical]
          background = "${steelborePalette.voidNavy}"
          foreground = "${steelborePalette.redOxide}"
          frame_color = "${steelborePalette.redOxide}"
          timeout = 0
        '';

        # Shared helper wrappers — installed for whichever bare WM(s)
        # are enabled. Both Niri and LeftWM binds reference these by
        # bare name (they land on PATH via environment.systemPackages).
        environment.systemPackages = [
          btState
          btToggle
          airplaneToggle
          caffeineToggle
          kbdLightCycle
          osd
          # Explicit on both sessions (already system-wide via core
          # audio, but listed here for clarity — LeftWM binds need them).
          pkgs.brightnessctl # C — display + keyboard backlight
          pkgs.playerctl # MPRIS media control
        ];

        # brightnessctl udev rules make /sys/class/backlight (group
        # `video`) and /sys/class/leds (group `input`) group-writable,
        # so the display + keyboard backlight are controllable rootless.
        # User `mj` is in both groups. swayosd-server's brightness
        # backend (Niri) also relies on the backlight being
        # `video`-writable. Moved here from niri.nix so LeftWM gets the
        # same ACL.
        services.udev.packages = [ pkgs.brightnessctl ];
      };
}
