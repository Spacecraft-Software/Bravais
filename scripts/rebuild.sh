#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — full system rebuild for steelbore-thinkpad.
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
HOST=steelbore-thinkpad
MCP_REPO=/spacecraft-software/mcp-servers
FLATPAK_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/flatpak-update.log"
STAMP="$HOME/.cache/bravais-vendored-check"

dry=0; no_sync=0; branch=""; no_update=0; update_all=0; no_gc=0; trace=0; skills_only=0; no_flatpak=0; detach_flatpak=0

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

# ── Live progress ───────────────────────────────────────────────────────────
# Mirrors pkgs/preflight/src/progress.rs and `flatpak-watch` in
# users/mj/rebuild.nu; change all three. Drawn only for a human at a terminal:
# never for an agent, CI or a pipe (CLI Standard §5), which keep exactly the
# old output.
is_live() {
    for v in "${AI_AGENT:-}" "${AGENT:-}" "${CI:-}"; do
        case "$v" in ''|0|false) ;; *) return 1 ;; esac
    done
    [ -t 1 ] && [ -t 2 ] && [ "${TERM:-dumb}" != dumb ]
}

# A running `flatpak update`, matched on the command line as preflight's
# `running_update` does: argv[0] `flatpak` (or NixOS's `.flatpak-wrapped`)
# with an `update` argument. flatpak-session-helper, -portal and
# -system-helper are always-on daemons and never carry one.
flatpak_running() {
    pgrep -f '^([^ ]*/)?\.?flatpak(-wrapped)? (.* )?update( |$)' >/dev/null 2>&1
}

# `op ops percent rate line` from the tail of the Flatpak log, separated by
# the ASCII unit separator: a tab is IFS whitespace, so `read` would merge an
# empty field into the next one.
# Off a terminal Flatpak writes `Updating 2/5…` as an operation starts, then
# `Updating 2/5… ████▌  23%  1.2 MB/s  00:30`; older releases separated the
# same text with \r. The newest line of either shape decides; a counter with no
# percentage is an operation just started, at 0%. `percent` counts each
# operation as an equal share -- Flatpak reports no transaction total.
flatpak_progress() {
    esc=$(printf '\033')
    tail -c 16384 "$FLATPAK_LOG" 2>/dev/null | tr '\r' '\n' | sed "s/${esc}\\[[0-9;]*[@-~]//g" | awk '
        NF { last = $0 }
        /[0-9]%/ || /[0-9]+\/[0-9]+/ { hit = $0 }
        END {
            op = ""; ops = ""; pct = ""; rate = ""
            if (match(hit, /[0-9]+\/[0-9]+/)) {
                split(substr(hit, RSTART, RLENGTH), a, "/")
                if (a[1] + 0 >= 1 && a[1] + 0 <= a[2] + 0) { op = a[1]; ops = a[2] }
            }
            if (match(hit, /[0-9]+%/)) {
                pct = substr(hit, RSTART, RLENGTH - 1)
                rate = substr(hit, RSTART + RLENGTH); gsub(/^ +| +$/, "", rate)
            } else if (op != "") pct = 0
            all = pct
            if (pct != "" && op != "") all = int(((op - 1) * 100 + pct) / ops)
            gsub(/^ +| +$/, "", last)
            printf "%s\037%s\037%s\037%s\037%s\n", op, ops, all, rate, last
        }'
}

elapsed() {
    if [ "$1" -ge 3600 ]; then printf '%dh%02dm' $(($1 / 3600)) $(($1 % 3600 / 60))
    elif [ "$1" -ge 60 ]; then printf '%dm%02ds' $(($1 / 60)) $(($1 % 60))
    else printf '%ds' "$1"; fi
}

# Follow the running update with a spinner, the operation counter, a bar and
# Flatpak's own rate. Ctrl-C stops following only: the update runs in its own
# session (setsid), so it gets neither the terminal's SIGINT nor its SIGHUP.
flatpak_watch() {
    # The Linux console font has no braille and no partial blocks.
    case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
        *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) frames='⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏'; full='█'; empty='░' ;;
        *) frames="| / - \\"; full='#'; empty='-' ;;
    esac
    [ "${TERM:-}" != linux ] || { frames="| / - \\"; full='#'; empty='-'; }
    say "$C_DIM" "following the Flatpak update — Ctrl-C stops following; the update keeps running" >&2
    trap 'printf "\r\033[2K" >&2; dim "stopped following; the update keeps running (log: $FLATPAK_LOG)"; exit 130' INT
    start=$(date +%s); tick=0; prog=""
    while :; do
        # Re-read the log and re-check the process every fifth frame.
        if [ $((tick % 5)) -eq 0 ]; then
            flatpak_running || break
            prog=$(flatpak_progress)
        fi
        # shellcheck disable=SC2086 # word-splitting the frame list is the point
        set -- $frames; shift $((tick % $#)); frame=$1
        took=$(elapsed $(($(date +%s) - start)))
        IFS=$(printf '\037') read -r op ops pct rate last <<EOF
$prog
EOF
        if [ -n "$pct" ]; then
            n=$((pct * 24 / 100)); bar=""; i=0
            while [ "$i" -lt 24 ]; do
                if [ "$i" -lt "$n" ]; then bar="$bar$full"; else bar="$bar$empty"; fi
                i=$((i + 1))
            done
            [ -z "$op" ] || op=" $op/$ops"
            [ -z "$rate" ] || rate="  $rate"
            printf '\r\033[2K%s flatpak%s  %s %3d%%%s  (%s)' "$frame" "$op" "$bar" "$pct" "$rate" "$took" >&2
        else
            # Flatpak's own line, ASCII only so `cut` cannot split a character.
            last=$(printf '%s' "${last:-starting}" | tr -cd ' -~' | cut -c1-50)
            printf '\r\033[2K%s flatpak: %s  (%s)' "$frame" "$last" "$took" >&2
        fi
        sleep 0.2 2>/dev/null || sleep 1
        tick=$((tick + 1))
    done
    trap - INT
    printf '\r\033[2K' >&2
    IFS=$(printf '\037') read -r _ _ _ _ last <<EOF
$(flatpak_progress)
EOF
    say "$C_OK" "flatpak: ${last:-finished}"
}
warn() { say "$C_WARN" "$1"; }
dim()  { say "$C_DIM"  "$1"; }

usage() {
    cat <<'USAGE'
rebuild.sh — full system rebuild for steelbore-thinkpad

Usage: scripts/rebuild.sh [OPTIONS]

Brings the checkout up to date with origin, bumps every flake input, frees disk while keeping a week of rollback
targets, builds and switches, then mirrors the repo into /etc/nixos. A failed
switch aborts before the mirror.

Options:
  --dry           nixos-rebuild dry-build only; skips GC and the /etc mirror
                  (the git sync fetches and reports, but does not move the checkout)
  --no-sync       build the checkout as it is; skip git fetch and fast-forward
  -b, --branch NAME
                  switch to origin's NAME before building (testing a PR)
  --no-update     skip `nix flake update`
  --update-all    accepted for compatibility; every run bumps every input
  --no-gc         skip garbage collection and the journal vacuum
  --trace         add --show-trace --verbose (to diagnose eval failures)
  --skills-only   bump only `construct`; skip GC, the mirror and the probes
  --no-flatpak    skip the detached Flatpak update
  --detach-flatpak
                  start the Flatpak update and return instead of following
                  its progress bar (always the case off a terminal)
  --yes           skip the question about using `preflight` instead
  -h, --help      show this help

Superseded by `preflight` (Rust), which takes all of the above and adds
--reclaim, --gc-all, --journal-days, --mcp-deploy, --update-vendored and --json.
See: preflight --help

Maintained by Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
https://Bravais.SpacecraftSoftware.org/
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry)         dry=1 ;;
        --no-sync)     no_sync=1 ;;
        -b|--branch)
            [ $# -ge 2 ] || { say "$C_ERR" "$1 needs a branch name"; exit 2; }
            branch=$2; shift ;;
        --branch=*)    branch=${1#--branch=} ;;
        --no-update)   no_update=1 ;;
        --update-all)  update_all=1 ;;
        --no-gc)       no_gc=1 ;;
        --trace)       trace=1 ;;
        --skills-only) skills_only=1 ;;
        --no-flatpak)  no_flatpak=1 ;;
        --detach-flatpak) detach_flatpak=1 ;;
        --yes)         assume_yes=1 ;;
        -h|--help|help) usage; exit 0 ;;
        *) say "$C_ERR" "unknown argument '$1' — try: rebuild.sh --help"; exit 2 ;;
    esac
    shift
done

# The one user-supplied string that reaches git: refuse anything that could
# be read as a flag or that no branch name can contain (Agentic CLI §7).
if [ -n "$branch" ]; then
    case "$branch" in
        -*|*..*|*[[:space:]]*|*[[:cntrl:]]*)
            say "$C_ERR" "invalid branch name '$branch'"; exit 2 ;;
    esac
    branch=${branch#origin/}
    [ "$no_sync" -eq 0 ] || { say "$C_ERR" "--branch conflicts with --no-sync"; exit 2; }
fi

if [ "$update_all" -eq 1 ] && { [ "$no_update" -eq 1 ] || [ "$skills_only" -eq 1 ]; }; then
    say "$C_ERR" "--update-all conflicts with --no-update and --skills-only"; exit 2
fi
if [ "$detach_flatpak" -eq 1 ] && [ "$no_flatpak" -eq 1 ]; then
    say "$C_ERR" "--detach-flatpak conflicts with --no-flatpak"; exit 2
fi

# ── Deprecation gate ────────────────────────────────────────────────────────
# Mirrors the same gate in users/mj/rebuild.nu — change one, change the other
# (see AGENTS.md). `preflight` (pkgs/preflight/, Rust) accepts every flag this
# script does and adds --reclaim, --gc-all, --journal-days, --mcp-deploy,
# --update-vendored and --json, so it is a strict superset and the question is a real one.
#
# `[ -t 0 ]` is POSIX and is the whole reason this is safe to put in a script
# that agents and rescue TTYs run: with stdin closed there is nobody to answer,
# so refuse loudly rather than block on `read` forever or fall through and
# rebuild unasked.
if [ "${assume_yes:-0}" != "1" ]; then
    if [ ! -t 0 ]; then
        say "$C_ERR" "rebuild.sh: refusing to run non-interactively without --yes"
        say "$C_DIM" "  prefer: preflight"
        exit 2
    fi
    say "$C_WARN" "\`rebuild.sh\` is superseded by \`preflight\`, the Rust rebuild orchestrator."
    say "$C_DIM" "  preflight takes the same flags and adds --reclaim, --gc-all,"
    say "$C_DIM" "  --journal-days, --mcp-deploy, --update-vendored and --json. See: preflight --help"
    printf 'continue with rebuild.sh anyway? [y/N] '
    read -r reply
    case "$reply" in
        y|Y|yes|YES|Yes) ;;
        *) say "$C_OK" "aborted — run \`preflight\` instead"; exit 0 ;;
    esac
fi

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

# ── Signing key ─────────────────────────────────────────────────────────────
# Before the git fetch and the flake update, both of which can need it.
if [ "$no_sync" -eq 0 ] || [ "$no_update" -eq 0 ]; then
    gitway-add "$HOME/.ssh/id_ed25519"
fi

# ── Git sync ────────────────────────────────────────────────────────────────
# Build origin's code, not whatever the checkout happens to hold. Mirrors
# pkgs/preflight/src/git_sync.rs, which carries the full reasoning; change all
# three. In short: carry uncommitted changes along with a warning (refuse only
# when the incoming commits touch them too); fetch --prune; keep the current
# branch while its upstream exists, else (detached, or merged and deleted
# upstream) go to origin's default branch; refuse a local-only branch;
# fast-forward only.
# Exit codes follow the CLI Standard: 5 conflict, 3 not found, 1 failure.
refuse() {  # <exit> <code> <message> <hint>
    if [ "$dry" -eq 1 ]; then
        warn "git-sync: dry run; would refuse ($2): $3"
        return 1
    fi
    say "$C_ERR" "[ERROR] $2: $3"
    dim "  try: $4"
    exit "$1"
}

git_sync() {
    if [ "$(git -C "$REPO" rev-parse --is-inside-work-tree 2>/dev/null)" != true ]; then
        refuse 1 NOT_A_CHECKOUT "$REPO is not a git checkout (or git is not on PATH)" \
            "rebuild.sh --no-sync   # build the tree as it is" || return 0
    fi
    # Porcelain columns 1-2 are the status, so the path starts at column 4.
    porcelain=$(git -C "$REPO" status --porcelain=v1 --untracked-files=no)
    carried=$(printf '%s\n' "$porcelain" | sed -n 's/^...//p' | sed 's/.* -> //' \
        | grep -vx 'flake\.lock' | tr '\n' ' ' | sed 's/ $//' || true)
    lock_dirty=0
    if printf '%s\n' "$porcelain" | grep -q '^.. flake\.lock$'; then lock_dirty=1; fi

    if ! git -C "$REPO" fetch --prune origin; then
        refuse 1 FETCH_FAILED "git fetch from origin failed, so the latest code is unknown" \
            "rebuild.sh --no-sync --no-update   # offline: build the tree as it is" || return 0
    fi

    current=$(git -C "$REPO" symbolic-ref --quiet --short HEAD || true)
    default=$(git -C "$REPO" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
    default=${default#origin/}
    [ -n "$default" ] || default=main
    why=""
    if [ -n "$branch" ]; then
        want=$branch
    elif [ -z "$current" ]; then
        want=$default; why=" (HEAD was detached)"
    elif ! git -C "$REPO" config --get "branch.$current.merge" >/dev/null; then
        refuse 5 NO_UPSTREAM "branch '$current' has no upstream on origin, so there is nothing to update it from" \
            "git -C $REPO switch $default   # or build it as it is: rebuild.sh --no-sync" || return 0
    elif git -C "$REPO" rev-parse --verify --quiet "$current@{upstream}" >/dev/null; then
        want=$current
    else
        want=$default; why=" ('$current' was deleted on origin)"
    fi

    if [ "$want" = "$current" ]; then
        switching=0
        target=$(git -C "$REPO" rev-parse --abbrev-ref "$current@{upstream}" 2>/dev/null || echo "origin/$want")
    else
        switching=1
        target="origin/$want"
    fi
    if ! git -C "$REPO" rev-parse --verify --quiet "$target^{commit}" >/dev/null; then
        refuse 3 NO_SUCH_BRANCH "origin has no branch '$want'" \
            "git -C $REPO branch --remotes   # the branches origin has" || return 0
    fi

    # The last run's `nix flake update` leaves flake.lock modified. If the
    # incoming commits change it too, git would refuse to move; when an update
    # follows anyway the stale bump is worthless and is dropped. Under
    # --no-update the lock IS what gets built, so it is never dropped silently.
    lock_conflicts=0
    if [ "$lock_dirty" -eq 1 ] && ! git -C "$REPO" diff --quiet HEAD "$target" -- flake.lock; then
        lock_conflicts=1
    fi

    if [ "$dry" -eq 1 ]; then
        behind=$(git -C "$REPO" rev-list --count "HEAD..$target" 2>/dev/null || echo '?')
        dim "git-sync: dry run; would move to $want$why at $target ($behind commit(s) behind); building the tree as it is"
        [ -z "$carried" ] || warn "uncommitted changes would be carried along: $carried"
        return 0
    fi

    if [ "$lock_conflicts" -eq 1 ]; then
        if [ "$no_update" -eq 1 ]; then
            refuse 5 LOCK_CONFLICT "flake.lock has an uncommitted bump and $target changes it too" \
                "git -C $REPO restore flake.lock   # drop the local bump, then re-run"
        fi
        git -C "$REPO" restore --staged --worktree -- flake.lock || \
            refuse 1 LOCK_CONFLICT "could not discard the uncommitted flake.lock bump" "git -C $REPO status"
    fi

    if [ "$switching" -eq 1 ]; then
        if git -C "$REPO" rev-parse --verify --quiet "refs/heads/$want" >/dev/null; then
            git -C "$REPO" switch "$want" || switch_failed
        else
            git -C "$REPO" switch --create "$want" --track "$target" || switch_failed
        fi
    fi

    before=$(git -C "$REPO" rev-parse HEAD)
    if ! git -C "$REPO" merge --ff-only "$target"; then
        # A fast-forward that is possible in history can only have been
        # stopped by the working tree.
        if [ -n "$carried" ] && git -C "$REPO" merge-base --is-ancestor HEAD "$target"; then
            dirty_refusal
        fi
        refuse 5 NOT_FAST_FORWARD "'$want' has commits that $target does not, so it cannot be fast-forwarded" \
            "git -C $REPO log --oneline $target..$want   # the local-only commits"
    fi
    new=$(git -C "$REPO" rev-list --count "$before..HEAD")
    note=""
    [ "$lock_conflicts" -eq 0 ] || note="; dropped the uncommitted flake.lock bump"
    say "$C_OK" "git-sync: $want at $(git -C "$REPO" rev-parse --short HEAD)$why; $new new commit(s)$note"
    # The build is origin's code plus these, so say so.
    [ -z "$carried" ] || warn "building with uncommitted changes: $carried"
}

dirty_refusal() {
    refuse 5 DIRTY_TREE "uncommitted changes conflict with the incoming commits: $carried" \
        "git -C $REPO stash   # then re-run; or build the tree as it is: rebuild.sh --no-sync"
}

switch_failed() {
    [ -z "$carried" ] || dirty_refusal
    refuse 1 SWITCH_FAILED "could not switch to '$want'" "git -C $REPO status"
}

if [ "$no_sync" -eq 1 ]; then
    dim "git-sync: skipped (--no-sync); building the tree as it is"
else
    git_sync
fi

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
# a rebuild is what re-points `pinned`/`current` at the new lock; `skills-sync`
# moves the pointer without one.
if [ "$no_update" -eq 0 ]; then
    # Anonymous, Nix resolves `github:` inputs through the GitHub API at 60
    # requests an hour, which a bare `nix flake update` exhausts (HTTP 403,
    # 2026-09-27). Borrow the gh CLI's keyring token for the update only:
    # it lives in this one child's environment, never in a file.
    # `extra-access-tokens` keeps any configured tokens; see docs/rebuild.md.
    gh_token=$(gh auth token --hostname github.com 2>/dev/null || true)
    if [ -z "$gh_token" ]; then
        dim "github-token: no \`gh auth token\`; anonymous GitHub API limit (60/h)"
    fi
    flake_update() {
        if [ -n "$gh_token" ]; then
            gh_line="extra-access-tokens = github.com=$gh_token"
            NIX_CONFIG="${NIX_CONFIG:+$NIX_CONFIG
}$gh_line" nix flake update "$@"
        else
            nix flake update "$@"
        fi
    }
    if [ "$skills_only" -eq 1 ]; then
        flake_update construct
    else
        # No input names = every input, stable nixpkgs and home-manager
        # included, so an input added to flake.nix is tracked without an
        # edit here.
        flake_update

        # Antigravity staleness probe. Updating the INPUT cannot move the
        # version pins inside it (artifacts/versions.json), so a rebuild can
        # report "unchanged" while the IDE is several releases behind. Reports
        # only, and never fails the rebuild: a brief Cloud Run outage must not
        # abort a switch. See CONSTRAINTS.md #27.
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
# /mnt/nix-tmp fills and builds fail. See CONSTRAINTS.md #28.
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
        # At a terminal, follow it with a progress bar until it ends
        # (--detach-flatpak returns at once, as every run off a terminal does).
        # The pause lets the forked update exist before the first check.
        if [ "$detach_flatpak" -eq 0 ] && is_live; then
            sleep 1
            flatpak_watch
        else
            dim "flatpak: detached → $FLATPAK_LOG"
        fi
    else
        say "$C_OK" "flatpak: up to date"
    fi
fi
