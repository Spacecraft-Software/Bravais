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

      ;; Bluetooth — three-state via the shared `steelbore-bt-state`
      ;; helper (modules/desktops/shared.nix): off = rfkill soft-blocked,
      ;; on = radio up but no device linked, connected = a paired device
      ;; reports Connected: yes. `bt` emits the matching Nerd Font glyph
      ;; from the shell (yuck literals don't parse \uXXXX): nf-md-
      ;; bluetooth_off (U+F00B2) for off, nf-fa-bluetooth (U+F293) for on,
      ;; nf-md-bluetooth_connect (U+F00B1) for connected. `bt_state`
      ;; carries the word for the CSS class (bt-off=red, bt-on=dim steel
      ;; blue, bt-connected=green). 5 s; radio + link changes are user-
      ;; initiated and cheap to re-check.
      (defpoll bt :interval "5s"
        "case $(steelbore-bt-state) in off) printf '\\xF3\\xB0\\x82\\xB2';; connected) printf '\\xF3\\xB0\\x82\\xB1';; *) printf '\\xF3\\xB0\\x82\\xAF';; esac")
      (defpoll bt_state :interval "5s" "steelbore-bt-state")

      ;; Network up/down. Scans /sys/class/net/* (skipping lo) for the
      ;; first interface whose operstate is "up" — works on any host
      ;; without hardcoding ifnames. `net` emits a Nerd Font glyph at the
      ;; shell level: nf-fa-wifi (U+F1EB) when the up iface is wireless
      ;; (wl*/wlan*), nf-fa-ethernet (U+EF44) for a wired one, nf-fa-plane
      ;; (U+F072) when none. `net_state` gives "up"/"down" for the CSS
      ;; class (net-up = green, net-down = red). 5 s; reads operstate which
      ;; the kernel updates on link events.
      (defpoll net :interval "5s"
        "for IF in /sys/class/net/*; do [ \"$IF\" = /sys/class/net/lo ] && continue; [ \"$(cat \"$IF/operstate\" 2>/dev/null)\" = up ] || continue; IFACE=\"$(basename \"$IF\")\"; case \"$IFACE\" in wl*|wlan*) printf '\\xEF\\x87\\xAB';; *) printf '\\xEE\\xBD\\x84';; esac; exit 0; done; printf '\\xEF\\x81\\xB2'")
      (defpoll net_state :interval "5s"
        "for IF in /sys/class/net/*; do [ \"$IF\" = /sys/class/net/lo ] && continue; if [ \"$(cat \"$IF/operstate\" 2>/dev/null)\" = up ]; then echo up; exit 0; fi; done; echo down")

      ;; Caffeine — mirrors the `steelbore-caffeine` toggle (SIGSTOP/
      ;; SIGCONT of swayidle). State is a flag file under XDG_RUNTIME_DIR
      ;; so the bar can read it rootless. `caf` emits nf-md-coffee_outline
      ;; (U+F06CA) when active (staying awake) or nf-md-coffee_off
      ;; (U+F0FAA) when idle; `caf_state` selects the CSS class (caf-on =
      ;; green, caf-off = red). 3 s so the indicator flips within a blink
      ;; of the Mod+Shift+C toggle.
      (defpoll caf :interval "3s"
        "if [ -e \"$XDG_RUNTIME_DIR/steelbore-caffeine.active\" ] || [ -e \"/tmp/steelbore-caffeine.active\" ]; then printf '\\xF3\\xB0\\x9B\\x8A'; else printf '\\xF3\\xB0\\xBE\\xAA'; fi")
      (defpoll caf_state :interval "3s"
        "if [ -e \"$XDG_RUNTIME_DIR/steelbore-caffeine.active\" ] || [ -e \"/tmp/steelbore-caffeine.active\" ]; then echo on; else echo off; fi")

      ;; Keyboard language indicator — active layout name from the shared
      ;; `steelbore-layout-state` helper (modules/desktops/shared.nix),
      ;; e.g. "English (US)" / "Arabic" on Niri. `lang_state` carries a
      ;; short code ("EN"/"AR") derived from the same string, used only
      ;; for the CSS class. 1 s so it updates promptly after Mod+Space.
      (defpoll lang :interval "1s" "steelbore-layout-state")
      (defpoll lang_state :interval "1s"
        "case $(steelbore-layout-state) in *Arabic*|*ara*) echo ar;; *) echo en;; esac")

      ;; Static metric glyphs — emitted once (the icon never changes),
      ;; polled on a long interval so eww re-evaluates the constant only
      ;; hourly. nf-oct-cpu (U+F4BC), nf-fa-memory (U+EFC5), nf-md-battery
      ;; (U+F0079). Shell printf carries the UTF-8 bytes for the same
      ;; reason as the dynamic glyphs above.
      (defpoll cpu-icon :interval "3600s" "printf '\\xEF\\x92\\xBC'")
      (defpoll ram-icon :interval "3600s" "printf '\\xEE\\xBF\\x85'")
      (defpoll bat-icon :interval "3600s" "printf '\\xF3\\xB0\\x81\\xB9'")

      (defwidget bar []
        (centerbox :orientation "h"
          (label :class "title" :halign "start" :text "STEELBORE OS :: BRAVAIS")
          (label :class "clock" :text time)
          (box :orientation "h" :spacing 8 :space-evenly false :halign "end" :class "metrics"
            ;; Keyboard language — leftmost in the metrics group. Text from
            ;; `lang`, color from `lang_state` (en=steel blue, ar=molten amber).
            (label :class {lang_state == "ar" ? "lang-ar" : "lang-en"} :text lang)
            ;; Bluetooth — glyph from `bt`, color from bt_state (3-state:
            ;; off=red, on=dim steel blue, connected=green). Click handling
            ;; not wired; XF86Bluetooth key still toggles the radio.
            (label :class {bt_state == "off" ? "bt-off" : bt_state == "connected" ? "bt-connected" : "bt-on"} :text bt)
            ;; Caffeine — glyph from `caf`,
            ;; color from caf_state (on=green, off=red). Toggled by
            ;; Mod+Shift+C → steelbore-caffeine.
            (label :class {caf_state == "on" ? "caf-on" : "caf-off"} :text caf)
            ;; Network — glyph from `net`, color from net_state.
            (label :class {net_state == "down" ? "net-down" : "net-up"} :text net)
            ;; Threshold colors: amber = warning, red = dangerous. CPU/RAM climb
            ;; (high is bad); battery drains (low is bad). "--" (no battery) stays
            ;; neutral. The label word is replaced by its Nerd Font glyph
            ;; (cpu-icon/ram-icon/bat-icon); only the percentage stays as text.
            ;; "metric-group-start" adds a bit of breathing room ahead of the
            ;; cpu/ram/battery trio, setting it visually apart from the
            ;; radio/caffeine cluster (lang/bt/caf/net) to its left.
            (label :class {"metric-group-start " + (cpu >= 90 ? "metric-crit" : cpu >= 75 ? "metric-warn" : "metric")} :text "''${cpu-icon} ''${cpu}%")
            (label :class {memory >= 90 ? "metric-crit" : memory >= 75 ? "metric-warn" : "metric"} :text "''${ram-icon} ''${memory}%")
            (label :class {battery == "--" ? "metric" : battery <= 15 ? "metric-crit" : battery <= 30 ? "metric-warn" : "metric"} :text "''${bat-icon} ''${battery}%"))))

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
      .metric-group-start { margin-left: 10px; }
      .metric      { color: $radiumGreen; }  // normal
      .metric-warn { color: $moltenAmber; }  // >=75% cpu/ram, <=30% battery
      .metric-crit { color: $redOxide; }     // >=90% cpu/ram, <=15% battery

      // Radio / network / mode indicators — colors only (glyphs come from
      // the Nerd Font codepoints emitted in eww.yuck). Bluetooth is
      // three-state: off = red oxide (disabled), on = dim steel blue
      // (radio up, nothing linked), connected = radium green (active
      // link). Network stays two-state: up = green, down = red. Caffeine
      // mirrors the toggle: on = green (staying awake), off = red.
      .bt-off       { color: $redOxide; }
      .bt-on        { color: $steelBlue; }
      .bt-connected { color: $radiumGreen; }
      .net-up   { color: $radiumGreen; }
      .net-down { color: $redOxide; }
      .caf-on  { color: $radiumGreen; }
      .caf-off { color: $redOxide; }

      // Keyboard language — en = steel blue (default), ar = molten amber
      // (secondary layout, draws the eye when active).
      .lang-en { color: $steelBlue; }
      .lang-ar { color: $moltenAmber; }
    '';
  };
}
