#!/bin/sh
# SPDX-FileCopyrightText: 2026 Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
# SPDX-License-Identifier: GPL-3.0-or-later
# Exercise the rendered LeftWM hooks with a harmless process, never evdev.
set -eu
theme=$1
shell_path=$2
fixture_dir="$PWD/mouse-fixture"
mkdir "$fixture_dir"
{
  printf '#!%s\n' "$shell_path"
  printf '%s\n' 'while :; do sleep 1; done'
} > "$fixture_dir/escapepod"
chmod +x "$fixture_dir/escapepod"
export XDG_RUNTIME_DIR="$fixture_dir"
pidfile="$fixture_dir/steelbore-leftwm-escapepod.pid"
fixture_pid=
trap 'if [ -n "$fixture_pid" ]; then kill "$fixture_pid" 2>/dev/null || :; fi' 0

# Use the actual generated lifecycle code, replacing only the daemon command.
awk -v stub="$fixture_dir/escapepod" '
  /^[[:space:]]*mouse_pidfile=/ { take=1 }
  take && /\/bin\/escapepod.*daemon/ { print "  \"" stub "\" 60 &"; next }
  take { print }
' "$theme/up" > "$fixture_dir/up"
awk '
  /^[[:space:]]*pidfile=.*steelbore-leftwm-escapepod/ { take=1 }
  take { print }
' "$theme/down" > "$fixture_dir/down"
test -s "$fixture_dir/up"
test -s "$fixture_dir/down"
sh -n "$fixture_dir/up"
sh -n "$fixture_dir/down"

sh "$fixture_dir/up"
IFS= read -r fixture_pid < "$pidfile"
# Wait for exec to give the fixture the daemon's process name.
checks=0
while :; do
  IFS= read -r process_name < "/proc/$fixture_pid/comm"
  [ "$process_name" != escapepod ] || break
  checks=$((checks + 1))
  [ "$checks" -lt 50 ]
  sleep 0.1
done
sh "$fixture_dir/up"
IFS= read -r second_pid < "$pidfile"
test "$fixture_pid" = "$second_pid"
sh "$fixture_dir/down"
test ! -e "$pidfile"
checks=0
while :; do
  process_state=$(awk '{print $3}' "/proc/$fixture_pid/stat" 2>/dev/null || :)
  case "$process_state" in ""|Z) break ;; esac
  checks=$((checks + 1))
  [ "$checks" -lt 50 ]
  sleep 0.1
done
fixture_pid=

# A reused PID must not stop an unrelated process (this test's own shell).
printf '%s\n' "$$" > "$pidfile"
sh "$fixture_dir/down"
test ! -e "$pidfile"
printf '%s\n' 'LeftWM reload and shutdown lifecycle passed'
