#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
# Exercise the actual mapping only on a private Xvfb display, never host input.
set -eu
daemon=$1
config=$2
fixture_dir=$(mktemp -d)
xvfb_pid=
observer_pid=
daemon_pid=
cleanup() {
    for child in "$daemon_pid" "$observer_pid" "$xvfb_pid"; do
        if [ -n "$child" ]; then kill "$child" 2>/dev/null || :; wait "$child" 2>/dev/null || :; fi
    done
}
trap cleanup 0
trap 'exit 1' HUP INT TERM

Xvfb -displayfd 3 -screen 0 800x600x24 -nolisten tcp 3>"$fixture_dir/display" >"$fixture_dir/xvfb.log" 2>&1 &
xvfb_pid=$!
attempts=0
while [ ! -s "$fixture_dir/display" ]; do
    attempts=$((attempts + 1))
    [ "$attempts" -lt 100 ]
    sleep 0.05
done
IFS= read -r display_number < "$fixture_dir/display"
DISPLAY=:$display_number
export DISPLAY
# Explicit X11 selection plus a nonexistent uinput path prohibits host grabs.
ESCAPEPOD_UINPUT="$fixture_dir/no-uinput"
export ESCAPEPOD_UINPUT
stdbuf -oL xev -name EscapePodSuperTapTest -event keyboard >"$fixture_dir/events" 2>&1 &
observer_pid=$!
window=$(timeout 5 xdotool search --sync --name '^EscapePodSuperTapTest$')
xdotool windowfocus --sync "$window"
"$daemon" daemon run --backend x11 --config "$config" --yes --json --verbose >"$fixture_dir/daemon.out" 2>"$fixture_dir/daemon.log" &
daemon_pid=$!
attempts=0
until rg -q BACKEND_SELECTED "$fixture_dir/daemon.log"; do
    attempts=$((attempts + 1))
    [ "$attempts" -lt 100 ]
    kill -0 "$daemon_pid"
    sleep 0.05
done
sleep 0.1
f19_count() { rg -c 'keysym .* F19\)' "$fixture_dir/events" || :; }
wait_for_count() {
    attempts=0
    while [ "$(f19_count)" != "$1" ]; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge 100 ]; then
            cat "$fixture_dir/events" "$fixture_dir/daemon.log" >&2
            return 1
        fi
        sleep 0.05
    done
}

xdotool key Super_L
wait_for_count 2
xdotool key Super_R
wait_for_count 4
# Using Super as a modifier must not inject a menu trigger.
xdotool key Super_L+Return
xdotool key Super_R+d
sleep 0.2
test "$(f19_count)" = 4
# Neither a mouse chord nor an abandoned hold is a tap.
for super in Super_L Super_R; do
    xdotool keydown "$super"
    xdotool click 1
    xdotool keyup "$super"
    xdotool keydown "$super"
    sleep 0.6
    xdotool keyup "$super"
    sleep 0.2
    test "$(f19_count)" = 4
done
printf '%s\n' 'Lone Super taps, modifier chords, mouse chords and hold timeout passed'
