#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — full system rebuild for bravais-thinkpad.
#
# A port of the Nushell `rebuild` command defined in users/mj/shell.nix, for use
# from Bash (or any POSIX shell) — an agent's tool shell, a rescue TTY, a
# recovery session where Home Manager has not been activated, or simply a Bash
# prompt. The two are expected to stay in step; if you change one, change both.
#
# Written to the POSIX subset despite the Bash shebang (Standard §7.1), so it
# also runs unmodified under dash, ash and brush. No [[ ]], no (( )), no arrays,
# no ${var^^}, no process substitution. Verify with:
#
#   nix run nixpkgs#shellcheck -- -s sh scripts/rebuild.sh
#   nix run nixpkgs#dash -- scripts/rebuild.sh --help
#
# The one thing this script does NOT reproduce is the Nushell version's
# structured return values: `antigravity-status` and `flatpak-status` are
# Nushell records that other commands consume as data. Here they are printed.

set -eu

REPO=/spacecraft-software/bravais
HOST=bravais-thinkpad
MCP_REPO=/spacecraft-software/mcp-servers
FLATPAK_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/flatpak-update.log"
STAMP="$HOME/.cache/bravais-vendored-check"

dry=0; no_update=0; no_gc=0; trace=0; skills_only=0; no_flatpak=0

# Colors only when stdout is a terminal — a piped or logged run stays clean,
# and NO_COLOR is honored (Standard §18.2.1).
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_WARN=$(printf '\033[33m'); C_INFO=$(printf '\033[34m')
    C_OK=$(printf '\033[32m');   C_DIM=$(printf '\033[90m')
    C_ERR=$(printf '\033[31m');  C_OFF=$(printf '\033[0m')
else
    C_WARN=; C_INFO=; C_OK=; C_DIM=; C_ERR=; C_OFF=
fi

say()  { printf '%s%s%s\n' "$1" "$2" "$C_OFF"; }
warn() { say "$C_WARN" "$1"; }
dim()  { say "$C_DIM"  "$1"; }

usage() {
    cat <<'USAGE'
rebuild.sh — full system rebuild for bravais-thinkpad

Usage: scripts/rebuild.sh [OPTIONS]

Bumps the tracked flake inputs, frees disk while keeping a week of rollback
targets, builds and switches, then mirrors the repo into /etc/nixos. A failed
switch aborts before the mirror.

Options:
  --dry           nixos-rebuild dry-build only; skips GC and the /etc mirror
  --no-update     skip `nix flake update`
  --no-gc         skip garbage collection and the journal vacuum
  --trace         add --show-trace --verbose (to diagnose eval failures)
  --skills-only   bump only `construct`; skip GC, the mirror and the probes
  --no-flatpak    skip the detached Flatpak update
  -h, --help      show this help

Maintained by Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
https://Bravais.SpacecraftSoftware.org/
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry)         dry=1 ;;
        --no-update)   no_update=1 ;;
        --no-gc)       no_gc=1 ;;
        --trace)       trace=1 ;;
        --skills-only) skills_only=1 ;;
        --no-flatpak)  no_flatpak=1 ;;
        -h|--help|help) usage; exit 0 ;;
        *) say "$C_ERR" "unknown argument '$1' — try: rebuild.sh --help"; exit 2 ;;
    esac
    shift
done

cd "$REPO"

# ── JSON, without assuming which parser is installed ────────────────────────
# jaq is the repo's preferred jq (spacecraft-cli-preference) and is what this
# host has; jq and python3 are accepted so the script still works on a machine
# that has not been rebuilt yet. Reads a dotted path from stdin.
json_get() {
    if command -v jaq >/dev/null 2>&1;   then jaq -r "$1"
    elif command -v jq >/dev/null 2>&1;  then jq  -r "$1"
    else python3 -c 'import json,sys
p=sys.argv[1].lstrip(".").replace("\"","").split(".")
o=json.load(sys.stdin)
for k in p:
    o = o[int(k)] if k.isdigit() else o[k]
print(o)' "$1"
    fi
}

# True for jaq/jq, false for the python3 fallback. The fallback deliberately
# understands DOTTED PATHS ONLY, which is all the antigravity probe needs; the
# mcpctl probe below needs real filter expressions (`select(.dirty)`), so it is
# gated on this rather than allowed to fail into a silent, wrong zero.
have_jq() { command -v jaq >/dev/null 2>&1 || command -v jq >/dev/null 2>&1; }

# xh over curl where present (spacecraft-cli-preference), curl otherwise.
http_get() {
    if command -v xh >/dev/null 2>&1; then xh --ignore-stdin --timeout 10 GET "$1" 2>/dev/null
    else curl -sL --max-time 10 "$1"
    fi
}

# ── Monthly vendored-binary reminder ────────────────────────────────────────
# claude-desktop, chrome-remote-desktop, ollama, obscura and BrowserOS pin
# upstream binaries that `nix flake update` cannot bump.
if [ ! -e "$STAMP" ] || [ -n "$(find "$STAMP" -mtime +30 2>/dev/null)" ]; then
    warn "vendored binaries unchecked for 30+ days — run: nu pkgs/update-vendored.nu --check"
    mkdir -p "$(dirname "$STAMP")"; : > "$STAMP"
fi

# ── Flake inputs ────────────────────────────────────────────────────────────
# --skills-only is the fast path for a prose-only skill change: skills come from
# `construct` alone, so bumping the other four inputs drags unrelated rebuild
# work into an edit that touched a Markdown file. It does NOT drop the switch —
# ~/.agents/skills is a Home-Manager store link, so a system generation is still
# the only way to move it.
if [ "$no_update" -eq 0 ]; then
    gitway-add "$HOME/.ssh/id_ed25519"
    if [ "$skills_only" -eq 1 ]; then
        nix flake update construct
    else
        nix flake update antigravity-nix construct gitway nixpkgs-unstable home-manager-unstable

        # Antigravity staleness probe. Updating the INPUT cannot move the
        # version pins inside it (artifacts/versions.json), so a rebuild can
        # report "unchanged" while the IDE is several releases behind. Reports
        # only, and never fails the rebuild: a brief Cloud Run outage must not
        # abort a switch. See AGENTS.md constraint #27.
        ag_rev=$(json_get '.nodes."antigravity-nix".locked.rev' < flake.lock 2>/dev/null || true)
        ag_pinned=""; ag_latest=""
        if [ -n "$ag_rev" ]; then
            ag_pinned=$(nix eval --raw \
                "github:UnbreakableMJ/antigravity-nix/$ag_rev#packages.x86_64-linux.google-antigravity-ide.version" \
                2>/dev/null || true)
        fi
        ag_json=$(http_get "https://antigravity-ide-auto-updater-974169037036.us-central1.run.app/releases" || true)
        if [ -n "$ag_json" ]; then
            ag_v=$(printf '%s' "$ag_json" | json_get '.[0].version' 2>/dev/null || true)
            ag_e=$(printf '%s' "$ag_json" | json_get '.[0].execution_id' 2>/dev/null || true)
            [ -n "$ag_v" ] && [ -n "$ag_e" ] && ag_latest="$ag_v-$ag_e"
        fi
        if [ -z "$ag_pinned" ] || [ -z "$ag_latest" ]; then
            dim "antigravity: version probe unavailable — skipped"
        elif [ "$ag_pinned" != "$ag_latest" ]; then
            warn "antigravity-nix pins IDE $ag_pinned but $ag_latest is out — its daily auto-update has probably stalled"
            dim "  fix upstream: cd /spacecraft-software/antigravity-nix; ./scripts/update-version.sh; then PR to master"
            dim "  then re-run: nix flake update antigravity-nix"
        fi
    fi
fi

# ── Reclaim ─────────────────────────────────────────────────────────────────
# Keeps a week of generations so a bad switch stays rollback-able. Both are
# best-effort: a GC failure must not stop the switch that follows.
if [ "$no_gc" -eq 0 ] && [ "$dry" -eq 0 ] && [ "$skills_only" -eq 0 ]; then
    sudo nix-collect-garbage --delete-older-than 7d || true
    sudo journalctl --vacuum-time=7d || true
fi

# /nix, not / — on this host / is a 16 GiB tmpfs that is always near-empty, so
# `df -h /` reports 0% used while the nvme partition holding /nix and
# /mnt/nix-tmp fills and builds fail. See AGENTS.md constraint #28.
[ "$skills_only" -eq 0 ] && { say "$C_INFO" "── disk before ──"; df -h /nix; }

# ── Build and switch ────────────────────────────────────────────────────────
# --option warn-dirty false silences the "Git tree is dirty" warning on the
# local flake eval. nixos-rebuild-ng rejects nix's --no-warn-dirty passthrough,
# so use the forwarded --option form it does accept.
set -- --option warn-dirty false
[ "$trace" -eq 1 ] && set -- "$@" --show-trace --verbose

if [ "$dry" -eq 1 ]; then
    sudo nixos-rebuild dry-build --flake ".#$HOST" "$@"
else
    sudo nixos-rebuild switch --flake ".#$HOST" "$@"
fi

[ "$dry" -eq 1 ] && exit 0
[ "$skills_only" -eq 1 ] && exit 0

# ── Mirror the repo into /etc/nixos ─────────────────────────────────────────
# Lean true mirror: prunes stale files, but skips VCS internals, the build
# symlink, and agent-local context (.claude is gitignored). Runs only after a
# successful switch — `set -e` above guarantees that.
sudo rsync -av --delete --delete-excluded \
    --exclude='.git/' --exclude='result' --exclude='.claude/' \
    "$REPO/" /etc/nixos/
say "$C_OK" "── disk after ──"; df -h /nix

# ── MCP host config drift ───────────────────────────────────────────────────
# MCP host configs are NOT part of this flake; they reach the machine only via
# `mcpctl deploy`. A rebuild cannot carry them, so this only reports.
# Deliberately not an automatic deploy: `deploy` refuses a host whose process is
# running, and a rebuild is usually run from an agent session, so an auto-deploy
# would silently skip ~/.claude.json — the file most likely to be stale — while
# reporting success. mcpctl is resolved BY NAME; ~/.cargo/bin is appended to
# PATH, so a Nix-provided copy already wins (constraint #23).
if [ -d "$MCP_REPO" ] && command -v mcpctl >/dev/null 2>&1 && ! have_jq; then
    dim "mcp: drift probe needs jaq or jq — skipped"
elif [ -d "$MCP_REPO" ] && command -v mcpctl >/dev/null 2>&1; then
    if probe=$(mcpctl deploy --dry-run --json --repo "$MCP_REPO" 2>/dev/null); then
        drifted=$(printf '%s' "$probe" | json_get '[.data.files[] | select(.dirty)] | length' 2>/dev/null || echo 0)
        blocked=$(printf '%s' "$probe" | json_get '.data.blocked | length' 2>/dev/null || echo 0)
        # --repo is part of the hint, not decoration: this script runs from the
        # bravais checkout, so a bare `mcpctl deploy --yes` exits with
        # "no `mcp.toml` in … or any parent". A hint must be runnable as printed.
        [ "${drifted:-0}" -gt 0 ] 2>/dev/null && \
            warn "$drifted MCP host config(s) drifted from the manifest — run: mcpctl deploy --yes --repo $MCP_REPO"
        [ "${blocked:-0}" -gt 0 ] 2>/dev/null && \
            warn "MCP deploy would skip a running host — close it, then: mcpctl deploy --yes --repo $MCP_REPO"
    else
        warn "mcpctl drift probe failed"
    fi
fi

# ── Flatpak, last and detached ──────────────────────────────────────────────
# `services.flatpak.update.onActivation` is the more obviously declarative
# spelling and is deliberately not used: it blocks activation on an unbounded
# download (the full set measured 4.4 GB at ~0.4 MB/s ≈ three hours), and a
# switch held open for hours — or interrupted part-way — is a worse failure than
# a Flatpak being a few days old. Running it inline after the switch carries the
# same cost minus the half-applied-system risk; detaching is what removes the
# wait. The weekly timer in modules/packages/flatpak.nix is the safety net.
if [ "$no_flatpak" -eq 0 ] && command -v flatpak >/dev/null 2>&1; then
    pending=$(flatpak remote-ls --updates 2>/dev/null | grep -c . || true)
    if [ "${pending:-0}" -gt 0 ] 2>/dev/null; then
        say "$C_INFO" "── flatpak: $pending update(s), detached ──"
        mkdir -p "$(dirname "$FLATPAK_LOG")"
        # setsid --fork so the update survives this script exiting. Same log
        # path the Nushell `flatpak-log` reads; note Flatpak redraws its
        # progress bar with carriage returns, so the file is one enormous line
        # unless you split on \r before reading it.
        setsid --fork sh -c "flatpak update -y >'$FLATPAK_LOG' 2>&1" || \
            warn "could not detach the flatpak update"
    else
        say "$C_OK" "flatpak: up to date"
    fi
fi
