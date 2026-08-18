# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Home Manager: Eww status bar (Niri / Wayland variant)
# Extracted from niri.nix in the Eww refactor (elegance plan 6.1).
# LeftWM ships its own Eww config in modules/desktops/leftwm.nix under
# eww-leftwm/ and launches with `eww open bar --config ~/.config/eww-leftwm`.
{
  pkgs,
  steelborePalette,
  ...
}:

let
  # Event-driven feed for the audio / mic / backlight / lock-key indicators.
  # Referenced by absolute store path in the `deflisten` below, as the LeftWM
  # bar does for `leftwm-state`: a bare name would resolve against whatever
  # PATH the compositor happened to export, which is not the same environment
  # a login shell gets.
  beacon = (import ../../pkgs { inherit pkgs; }).steelbore-beacon;
in
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

      ;; Hardware state — one event-driven feed. `steelbore-beacon`
      ;; (pkgs/steelbore-beacon) blocks on three kernel event sources — the
      ;; PulseAudio mainloop, EV_LED from the keyboard's evdev node, and
      ;; POLLPRI on the backlight's `actual_brightness` — and writes one JSON
      ;; line per change. `deflisten` rather than `defpoll` because all four
      ;; indicators react to function keys: a poll slow enough to be cheap
      ;; visibly lags the keypress, and one fast enough to feel instant wakes
      ;; the CPU all day for state that changes a handful of times an hour.
      ;; FnLock is deliberately absent — this ThinkPad's EC handles Fn+Esc
      ;; entirely, exposing no sysfs attribute and emitting no KEY_FN_ESC, so
      ;; an indicator could only guess and would silently drift after resume.
      ;; :initial keeps the bar renderable before the first line lands, and if
      ;; the daemon is missing altogether.
      (deflisten beacon
        :initial '{"volume":0,"muted":false,"mic":0,"mic_muted":false,"brightness":100,"caps":false,"num":false}'
        "${beacon}/bin/steelbore-beacon")

      ;; Static indicator glyphs — same shell-printf idiom and long interval as
      ;; the cpu/ram/battery icons above (yuck literals don't parse \uXXXX).
      ;; All are nf-md-*, whose ink sits inside its advance like md-battery's,
      ;; so the labels below omit the literal space before the value for the
      ;; same reason the battery label does.
      (defpoll ico-vol-high  :interval "3600s" "printf '\\xF3\\xB0\\x95\\xBE'")  ;; nf-md-volume_high U+F057E
      (defpoll ico-vol-med   :interval "3600s" "printf '\\xF3\\xB0\\x96\\x80'")  ;; nf-md-volume_medium U+F0580
      (defpoll ico-vol-low   :interval "3600s" "printf '\\xF3\\xB0\\x95\\xBF'")  ;; nf-md-volume_low U+F057F
      (defpoll ico-vol-mute  :interval "3600s" "printf '\\xF3\\xB0\\x96\\x81'")  ;; nf-md-volume_off U+F0581
      (defpoll ico-mic-on    :interval "3600s" "printf '\\xF3\\xB0\\x8D\\xAC'")  ;; nf-md-microphone U+F036C
      (defpoll ico-mic-off   :interval "3600s" "printf '\\xF3\\xB0\\x8D\\xAD'")  ;; nf-md-microphone_off U+F036D
      (defpoll ico-bright    :interval "3600s" "printf '\\xF3\\xB0\\x83\\xA0'")  ;; nf-md-brightness_5 U+F00E0
      (defpoll ico-caps      :interval "3600s" "printf '\\xF3\\xB0\\x98\\xB2'")  ;; nf-md-apple_keyboard_caps U+F0632
      (defpoll ico-num       :interval "3600s" "printf '\\xF3\\xB0\\x8E\\xA5'")  ;; nf-md-numeric U+F03A5

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
            ;; Hardware indicators. Icon and value are SEPARATE labels inside a small
            ;; box, not one interpolated string, because these glyphs disagree about
            ;; their own metrics: volume_high overflows its 600-unit advance by 150
            ;; and brightness_5 by 342, while volume_medium (+19) and volume_low
            ;; (+112) sit inside theirs. A literal space therefore renders a gap that
            ;; visibly changes width as the volume crosses 66% and 33%, and no space
            ;; lets the overflowing ink run into the first digit. `:spacing` is
            ;; measured in pixels and does not care what the glyph does, so the gap
            ;; is identical in every state. This is why the md-battery precedent
            ;; (RSB +50, no space) does NOT generalise to other nf-md-* icons —
            ;; measure with fontTools before assuming it does.
            (box :class "beacon-group" :orientation "h" :spacing 10 :space-evenly false
              ;; Caps Lock / Num Lock — rendered only while engaged, so presence
              ;; rather than color carries the meaning (Standard §18.2.1); the color
              ;; is reinforcement, not the signal.
              (label :class "ind-lock" :visible {beacon.caps} :text ico-caps)
              (label :class "ind-lock" :visible {beacon.num}  :text ico-num)
              ;; Volume and microphone — green while live, red while muted. The glyph
              ;; changes with the state too (volume_off / microphone_off), so muted
              ;; reads correctly without relying on color alone.
              (box :orientation "h" :spacing 3 :space-evenly false
                (label :class {beacon.muted ? "ind-muted" : "ind-live"}
                       :text {beacon.muted ? ico-vol-mute : beacon.volume >= 66 ? ico-vol-high : beacon.volume >= 33 ? ico-vol-med : ico-vol-low})
                (label :class {beacon.muted ? "ind-muted" : "ind-live"} :text "''${beacon.volume}%"))
              (box :orientation "h" :spacing 3 :space-evenly false
                (label :class {beacon.mic_muted ? "ind-muted" : "ind-live"}
                       :text {beacon.mic_muted ? ico-mic-off : ico-mic-on})
                (label :class {beacon.mic_muted ? "ind-muted" : "ind-live"} :text "''${beacon.mic}%"))
              ;; Display backlight.
              (box :orientation "h" :spacing 3 :space-evenly false
                (label :class "ind-bright" :text ico-bright)
                (label :class "ind-bright" :text "''${beacon.brightness}%")))
            ;; Threshold colors: amber = warning, red = dangerous. CPU/RAM climb
            ;; (high is bad); battery drains (low is bad). "--" (no battery) stays
            ;; neutral. The label word is replaced by its Nerd Font glyph
            ;; (cpu-icon/ram-icon/bat-icon); only the percentage stays as text.
            ;; Battery alone omits the literal space before its value:
            ;; md-battery's ink sits inside its 600-unit advance (RSB +50),
            ;; while oct-cpu/fa-memory overflow theirs (RSB -400/-438) into
            ;; the following space — so a spaced battery label shows a ~3x
            ;; wider visible gap than cpu/ram. No space = matching gaps.
            ;; "metric-group-start" adds a bit of breathing room ahead of the
            ;; cpu/ram/battery trio, setting it visually apart from the
            ;; radio/caffeine cluster (lang/bt/caf/net) to its left.
            (label :class {"metric-group-start " + (cpu >= 90 ? "metric-crit" : cpu >= 75 ? "metric-warn" : "metric")} :text "''${cpu-icon} ''${cpu}%")
            (label :class {memory >= 90 ? "metric-crit" : memory >= 75 ? "metric-warn" : "metric"} :text "''${ram-icon} ''${memory}%")
            (label :class {battery == "--" ? "metric" : battery <= 15 ? "metric-crit" : battery <= 30 ? "metric-warn" : "metric"} :text "''${bat-icon}''${battery}%"))))

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
      $background:    ${steelborePalette.background};
      $foreground: ${steelborePalette.foreground};
      $accent:   ${steelborePalette.accent};
      $success: ${steelborePalette.success};
      $info:  ${steelborePalette.info};
      $error:    ${steelborePalette.error};
      $warning: ${steelborePalette.warning};

      * {
          font-family: "JetBrainsMono Nerd Font", monospace;
          font-size: 13px;
          font-weight: bold;
      }

      window {
          background-color: $background;
          color: $foreground;
          border-bottom: 2px solid $accent;
          padding: 0 12px;
      }

      .title  { color: $foreground; }
      .clock  { color: $info; }
      .metrics { padding-right: 12px; }
      .metric-group-start { margin-left: 10px; }
      .metric      { color: $success; }  // normal
      .metric-warn { color: $foreground; }  // >=75% cpu/ram, <=30% battery
      .metric-crit { color: $error; }     // >=90% cpu/ram, <=15% battery

      // Radio / network / mode indicators — colors only (glyphs come from
      // the Nerd Font codepoints emitted in eww.yuck). Bluetooth is
      // three-state: off = red oxide (disabled), on = dim steel blue
      // (radio up, nothing linked), connected = radium green (active
      // link). Network stays two-state: up = green, down = red. Caffeine
      // mirrors the toggle: on = green (staying awake), off = red.
      .bt-off       { color: $error; }
      .bt-on        { color: $accent; }
      .bt-connected { color: $success; }
      .net-up   { color: $success; }
      .net-down { color: $error; }
      .caf-on  { color: $success; }
      .caf-off { color: $error; }

      // Keyboard language — en = steel blue (default), ar = molten amber
      // (secondary layout, draws the eye when active).
      // Hardware indicators fed by steelbore-beacon. Text sits on the canvas,
      // never on a surface fill (Standard §11.0.1) — same reason the metrics
      // above do. On Void Navy: success 16.75:1, error 5.77:1, accent 6.66:1,
      // warning 6.41:1, all clear of the 4.5:1 AA floor.
      //
      // Line comments, not /* */: a block comment survives SCSS into the CSS
      // GTK parses, and GTK rejects ANY non-ASCII byte inside one with a
      // misleading "unknown @ rule" -- the section sign and em dash above
      // would be enough. SCSS strips // entirely, so it never reaches GTK.
      .ind-live   { color: $success; }
      .ind-muted  { color: $error; }
      .ind-bright { color: $accent; }
      .ind-lock   { color: $warning; }
      // Separates the beacon cluster from the radio/network icons on its
      // left; the cpu label's own margin handles the right-hand side.
      .beacon-group { margin-left: 10px; }

      .lang-en { color: $accent; }
      .lang-ar { color: $foreground; }
    '';
  };
}
