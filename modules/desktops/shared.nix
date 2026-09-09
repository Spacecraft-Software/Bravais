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
    if [ "$(${btState}/bin/steelbore-bt-state)" = "off" ]; then
      ${pkgs.dunst}/bin/dunstify -a Bluetooth -r 9911 -u critical -i bluetooth-disabled "Bluetooth Off"
    else
      ${pkgs.dunst}/bin/dunstify -a Bluetooth -r 9911 -u normal -i bluetooth "Bluetooth On"
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

  # Keyboard-layout state — emits the active layout's display name (e.g.
  # "English (US)" / "Arabic" on Niri, or the xkb layout code on X11).
  # Backs the Eww language indicator (both eww.nix and leftwm.nix).
  # Niri: `niri msg --json keyboard-layouts` reports the configured layout
  # names plus which index is active — parsed with jaq (already a system
  # package, modules/packages/system.nix). LeftWM/X11: xkb toggle state
  # lives in the X server itself, not a config file, so a *live* read needs
  # xkb-switch (-p prints the active layout) rather than `setxkbmap -query`
  # (which only echoes the static config, not which of the two is active).
  layoutState = pkgs.writeShellScriptBin "steelbore-layout-state" ''
    set -eu
    if [ -n "''${NIRI_SOCKET:-}" ]; then
      ${pkgs.niri}/bin/niri msg --json keyboard-layouts 2>/dev/null \
        | ${pkgs.jaq}/bin/jaq -r '.names[.current_idx] // "??"' 2>/dev/null || echo "??"
    else
      ${pkgs.xkb-switch}/bin/xkb-switch -p 2>/dev/null || echo "??"
    fi
  '';

  # Keyring helpers, split in two on purpose.
  #
  # The old single `steelbore-keyring-unlock` conflated "open the keyring" with
  # "tell me whether the keyring is sane". Only the second is routinely useful:
  # greetd authenticates by password (modules/hardware/fingerprint.nix pins
  # `greetd.fprintAuth = false`), so pam_gnome_keyring auto-unlocks at login and
  # the keyring is normally already open. The unlock path is a rescue, not a
  # routine.
  #
  # It also piped the password into `gnome-keyring-daemon --unlock --replace`.
  # `--replace` KILLS the PAM-seeded daemon and takes over org.freedesktop.secrets:
  # every client holding an open Secret.Session has its object vaporised, which
  # is precisely the shape of the "No such secret item at path" failure the probe
  # below was written to detect. Read the gnome-keyring source before reaching
  # for that flag again: `--unlock` WITHOUT `--replace` is not an alternative
  # either -- discover_other_daemon() runs only for `--start`/`--replace`
  # (daemon/gkd-main.c), so a bare `--unlock` starts a RIVAL daemon rather than
  # handing the password to the running one, and `--start` + `--unlock` is
  # rejected outright in-code.
  #
  # The supported route is the Secret Service Unlock prompt, driven below.

  # Read-only diagnosis. No password, no prompt, no side effects -- safe to run
  # unattended at session start, which is the point: the 2026-07-25 failure was
  # invisible until browsers had already destroyed their own keys.
  #
  # Three distinct failure modes, in the order they bite:
  #
  #   1. No `default` alias at all. ReadAlias returns "/" and every
  #      Chromium-family lookup fails outright. The previous version reported
  #      SUCCESS here: `locked` came back empty and the `= "true"` test simply
  #      did not match, so it fell through to "Keyring unlocked".
  #   2. The alias points at the WRONG collection. Chromium-family Safe Storage
  #      keys resolve through the *default* alias, not through "login". On
  #      2026-08-18 `~/.local/share/keyrings/default` said "Default" -- a
  #      107-byte, zero-item keyring auto-created moments earlier -- while the
  #      real data lived elsewhere. The previous version checked only the
  #      alias's lock state, never its identity, so this passed.
  #   3. The alias is correct AND unlocked and it is STILL broken: a collection
  #      can index an item that no longer materialises on the bus. Every lookup
  #      that would match fails with "No such secret item at path: ..." instead
  #      of returning a result. Chromium reads that as "no key exists", mints a
  #      fresh Safe Storage key, and silently invalidates every stored cookie
  #      and password. Checks 1 and 2 stayed green through exactly that failure
  #      on 2026-07-25, which is why the probe exists.
  #
  # Exit codes: 0 ok, 2 locked, 3 no/wrong alias, 4 dangling items.
  keyringCheck = pkgs.writeShellScriptBin "steelbore-keyring-check" ''
    set -u
    notify=1
    [ "''${1:-}" = "--quiet" ] && notify=0

    # $1=urgency $2=icon $3=summary $4=body. Also prints, so the script is
    # usable from a terminal and legible in `journalctl`.
    say() {
      printf '%s: %s\n' "$3" "$4"
      if [ "$notify" = 1 ]; then
        ${pkgs.dunst}/bin/dunstify -a Keyring -u "$1" -r 9914 -i "$2" "$3" "$4" || true
      fi
    }

    default_coll=$(${pkgs.systemd}/bin/busctl --user call org.freedesktop.secrets \
      /org/freedesktop/secrets org.freedesktop.Secret.Service ReadAlias s default \
      2>/dev/null | ${pkgs.coreutils}/bin/cut -d'"' -f2)

    if [ -z "$default_coll" ] || [ "$default_coll" = "/" ]; then
      say critical dialog-error "Keyring: no default collection" \
        "The 'default' alias is unset — browsers cannot resolve a Safe Storage key at all. See USER_MANUAL 7.7 for the repair."
      exit 3
    fi

    case "$default_coll" in
      */collection/login) ;;
      *)
        say critical dialog-warning "Keyring: default is not 'login'" \
          "The default alias points at $default_coll. Chromium-family Safe Storage keys live behind this alias and will not reach the login keyring."
        exit 3
        ;;
    esac

    locked=$(${pkgs.systemd}/bin/busctl --user get-property org.freedesktop.secrets \
      "$default_coll" org.freedesktop.Secret.Collection Locked 2>/dev/null \
      | ${pkgs.coreutils}/bin/cut -d' ' -f2)
    if [ "$locked" = "true" ]; then
      say critical dialog-warning "Keyring: default collection locked" \
        "Browsers cannot reach their Safe Storage keys. Unlock with Mod+Shift+U (steelbore-keyring-unlock)."
      exit 2
    fi

    # A browser that has simply never run yields no match and no error -- only
    # the dangling case writes this message to stderr, so match on the message
    # rather than on the exit status. NOTE: this matches an unstructured
    # libsecret string and is therefore version-fragile; it earned its place by
    # catching the 2026-07-25 failure that both checks above missed.
    broken=""
    for probe in "application chrome" "application brave" "application chromium" \
                 "app_id com.google.Chrome" "app_id com.brave.Browser" \
                 "app_id com.opera.Opera" "app_id com.microsoft.Edge"; do
      # shellcheck disable=SC2086 -- probe is an attribute/value pair, split intentionally
      err=$(${pkgs.libsecret}/bin/secret-tool search --all $probe 2>&1 >/dev/null)
      case "$err" in
        *"No such secret item at path"*) broken="$broken ''${probe#* }" ;;
      esac
    done

    if [ -n "$broken" ]; then
      say critical dialog-warning "Keyring: dangling item(s) —''${broken}" \
        "These lookups fail with 'No such secret item'. Affected browsers will mint a NEW Safe Storage key on next launch and drop every saved login. Rebuild the login keyring before starting them."
      exit 4
    fi

    say low changes-allow "Keyring OK" "default -> $default_coll, unlocked, no dangling items."
  '';

  # The Secret Service Unlock flow REQUIRES one D-Bus connection held open
  # across Unlock() -> Prompt.Prompt() -> Prompt.Completed. gnome-keyring
  # destroys a Prompt object as soon as the connection that created it drops,
  # so `busctl call` -- which opens a fresh connection per invocation -- CANNOT
  # drive it: the second call finds the prompt already gone. That failure is
  # visible in the journal as
  #   Gcr: couldn't find the callback for prompting operation /org/gnome/keyring/Prompt/pN
  # Hence a real D-Bus client rather than shell.
  #
  # The password never enters this process. gcr-prompter (gcr 3, D-Bus-activated
  # as org.gnome.keyring.SystemPrompter -- see modules/core/keyring.nix, which
  # pins it) collects it and hands it to the daemon directly. That also retires
  # the old dmenu-bar password prompt, whose UI shape was indistinguishable from
  # a phishing prompt.
  #
  # Rust-first exception (AGENTS.md): Python is pragmatic today. The migration
  # target is `adit`, already reserved at flake.nix as the askpass replacement.
  keyringUnlockHelper =
    pkgs.writers.writePython3Bin "steelbore-keyring-unlock-helper"
      {
        libraries = [ pkgs.python3Packages.pygobject3 ];
        # E402: gi.require_version must run before the gi.repository import.
        flakeIgnore = [
          "E501"
          "E402"
        ];
      }
      ''
        import sys
        import gi
        gi.require_version("Gio", "2.0")
        from gi.repository import Gio, GLib

        BUS = "org.freedesktop.secrets"
        SVC = "/org/freedesktop/secrets"
        I_SVC = "org.freedesktop.Secret.Service"
        I_COLL = "org.freedesktop.Secret.Collection"
        I_PROMPT = "org.freedesktop.Secret.Prompt"
        I_PROPS = "org.freedesktop.DBus.Properties"

        conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)


        def call(path, iface, method, args, rtype):
            return conn.call_sync(
                BUS, path, iface, method, args,
                GLib.VariantType(rtype) if rtype else None,
                Gio.DBusCallFlags.NONE, 30000, None)


        alias = sys.argv[1] if len(sys.argv) > 1 else "default"
        coll = call(SVC, I_SVC, "ReadAlias", GLib.Variant("(s)", (alias,)), "(o)")[0]
        if coll == "/":
            print("no-alias")
            sys.exit(3)

        # PyGObject auto-unpacks the reply, so indexing a "(v)" already yields the
        # plain Python bool -- do NOT call .get_boolean() on it.
        locked = call(coll, I_PROPS, "Get",
                      GLib.Variant("(ss)", (I_COLL, "Locked")), "(v)")[0]
        if not locked:
            print("already-unlocked")
            sys.exit(0)

        _unlocked, prompt = call(SVC, I_SVC, "Unlock",
                                 GLib.Variant("(ao)", ([coll],)), "(aoo)")
        if prompt == "/":
            print("unlocked")
            sys.exit(0)

        loop = GLib.MainLoop()
        state = {"dismissed": True}


        def completed(_c, _sender, _path, _iface, _signal, params):
            state["dismissed"] = params[0]
            loop.quit()


        conn.signal_subscribe(BUS, I_PROMPT, "Completed", prompt, None,
                              Gio.DBusSignalFlags.NONE, completed)
        # window_id "" = no parent window; gcr-prompter self-parents.
        call(prompt, I_PROMPT, "Prompt", GLib.Variant("(s)", ("",)), None)
        # gcr-prompter self-quits on a 10 s inactivity timeout, so a walked-away-from
        # dialog never emits Completed. Bound the wait rather than hanging forever.
        GLib.timeout_add_seconds(120, lambda: (loop.quit(), False)[1])
        loop.run()

        print("dismissed" if state["dismissed"] else "unlocked")
        sys.exit(1 if state["dismissed"] else 0)
      '';

  # Thin wrapper: raise the prompt, translate the outcome, then hand off to the
  # read-only check so a successful unlock is also a verified one.
  keyringUnlock = pkgs.writeShellScriptBin "steelbore-keyring-unlock" ''
    set -u
    ${keyringUnlockHelper}/bin/steelbore-keyring-unlock-helper || rc=$?
    rc=''${rc:-0}
    case "$rc" in
      0) ;;
      1)
        ${pkgs.dunst}/bin/dunstify -a Keyring -u normal -r 9914 -i dialog-information \
          "Keyring: unlock cancelled" "The prompt was dismissed; the keyring is still locked."
        exit 1
        ;;
      3)
        ${pkgs.dunst}/bin/dunstify -a Keyring -u critical -r 9914 -i dialog-error \
          "Keyring: no default collection" "Nothing to unlock — the 'default' alias is unset."
        exit 3
        ;;
      *)
        ${pkgs.dunst}/bin/dunstify -a Keyring -u critical -r 9914 -i dialog-error \
          "Keyring: unlock failed" "The Secret Service returned an error. See: journalctl --user -t gcr-prompter"
        exit "$rc"
        ;;
    esac
    exec ${keyringCheck}/bin/steelbore-keyring-check
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
          frame_color = "${steelborePalette.accent}"
          separator_color = frame

          font = "Hack Nerd Font 12"
          line_height = 0
          markup = full
          format = "<b>%s</b>\n%b"
          alignment = left

          icon_position = left
          max_icon_size = 48

          [urgency_low]
          background = "${steelborePalette.background}"
          foreground = "${steelborePalette.info}"
          timeout = 5

          [urgency_normal]
          background = "${steelborePalette.background}"
          foreground = "${steelborePalette.foreground}"
          timeout = 10

          [urgency_critical]
          background = "${steelborePalette.background}"
          foreground = "${steelborePalette.error}"
          frame_color = "${steelborePalette.error}"
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
          layoutState
          keyringCheck
          keyringUnlock
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
