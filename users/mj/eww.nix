# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Home Manager: Eww status bar (Niri / Wayland variant)
# Extracted from niri.nix in the Eww refactor (elegance plan 6.1).
# LeftWM ships its own Eww config in modules/desktops/leftwm.nix under
# eww-leftwm/ and launches with `eww open bar --config ~/.config/eww-leftwm`.
{
  steelborePalette,
  ...
}:

{
  xdg.configFile = {
    # ═══════════════════════════════════════════════════════════════════════════
    # EWW — Niri (Wayland) status bar.
    # Niri spawns `eww open bar` at startup (niri/config.kdl spawn-at-startup).
    # ═══════════════════════════════════════════════════════════════════════════
    "eww/eww.yuck".text = ''
      ;; Steelbore Eww — Niri bar widget

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

      (defwidget bar []
        (centerbox :orientation "h"
          (label :class "title" :halign "start" :text "STEELBORE OS :: BRAVAIS")
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
            (label :class {battery == "--" ? "metric" : battery <= 15 ? "metric-crit" : battery <= 30 ? "metric-warn" : "metric"} :text "BAT ''${battery}%"))))

      (defwindow bar
        :monitor 0
        :geometry (geometry :x      "0"
                            :y      "0"
                            :width  "100%"
                            :height "32px"
                            :anchor "top center")
        :stacking  "fg"
        :exclusive true
        (bar))
    '';

    "eww/eww.scss".text = ''
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
    '';
  };
}
