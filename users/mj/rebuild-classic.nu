# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — `rebuild` and its helpers, as a standalone Nushell source.
#
# This file is the SINGLE definition of these commands. It is consumed twice,
# from Nix, so the two consumers cannot drift:
#
#   1. users/mj/shell.nix embeds it in Nushell's config.nu, so `rebuild`,
#      `flatpak-status`, `flatpak-update`, `flatpak-watch`, `flatpak-log` and
#      `antigravity-status` stay available as interactive Nu commands.
#   2. the same text is wrapped with a `nu` shebang and a `def main` and
#      installed as the `rebuild` binary, so it is callable from Bash, Ion,
#      Brush or anything else on PATH. Previously `rebuild` existed ONLY as a
#      Nushell def, so `bash: rebuild: command not found` was the correct and
#      confusing answer from every other shell.
#
# Keep this file pure Nushell: it is read with `builtins.readFile`, so a Nix
# `${...}` interpolation here would be a literal, not a substitution.

# ── flatpak ───────────────────────────────────────────────────────
# Path a detached `flatpak-update` writes its progress to. Fixed
# rather than passed around, so `flatpak-status` knows where to look
# without being told, and `rebuild` and a hand-run update share one
# log instead of each inventing their own.
def flatpak-log []: nothing -> string {
  $nu.home-dir | path join ".local" "state" "flatpak-update.log"
}

# Whether a `flatpak update` is running. Matched on the command line, as
# `running_update` in pkgs/preflight/src/progress.rs does: argv[0] must be
# `flatpak` (or NixOS's `.flatpak-wrapped`) and an argument `update`.
# flatpak-session-helper, -portal and -system-helper are always-on daemons
# that share the name, so a bare name filter would report running = true
# forever; none of them carries `update`.
def flatpak-running []: nothing -> bool {
  ps -l | where command =~ '^(\S*/)?\.?flatpak(-wrapped)?\s(.*\s)?update(\s|$)' | is-not-empty
}

# Draw live progress? Only for a human at a terminal: never for an agent,
# CI or a pipe (CLI Standard §5), the same test as `progress::detect` in
# pkgs/preflight/src/progress.rs.
def bravais-live []: nothing -> bool {
  let agent = (["AI_AGENT" "AGENT" "CI"] | any {|v|
    let val = ($env | get -o $v | default "")
    $val not-in ["" "0" "false"]
  })
  (not $agent) and (is-terminal --stdout) and (is-terminal --stderr) and (($env | get -o TERM) != "dumb")
}

# Progress out of the tail of a Flatpak log. Mirrors `parse` in
# pkgs/preflight/src/progress.rs, which documents the two line shapes
# Flatpak writes when its output is not a terminal: `Updating 2/5…` as an
# operation starts, then `Updating 2/5… ████▌  23%  1.2 MB/s  00:30`.
# The newest line with either shape decides; a counter with no percentage
# is an operation that has just started, so it stands at 0%. `percent`
# counts every operation as an equal share — Flatpak reports no total.
def flatpak-progress [text: string]: nothing -> record {
  # Split before `ansi strip`, which also drops the carriage returns.
  let lines = ($text | split row -r '[\r\n]' | ansi strip | str trim | where $it != "")
  let hit = ($lines | reverse | where {|l| ($l =~ '\d%') or ($l =~ '\d+/\d+(…|\.\.\.)?(\s|$)') } | get 0?)
  let ctr = if $hit == null { null } else {
    $hit | parse -r '(?<op>\d+)/(?<ops>\d+)(?:…|\.\.\.)?(?:\s|$)' | get 0? | if $in == null { null } else {
      {op: ($in.op | into int), ops: ($in.ops | into int)}
    } | if $in != null and $in.op >= 1 and $in.op <= $in.ops { $in } else { null }
  }
  let pct = if $hit == null { null } else {
    $hit | parse -r '(?<p>\d{1,3})%\s*(?<rate>.*)$' | get 0?
  }
  let op_percent = if $pct != null { $pct.p | into int } else if $ctr != null { 0 } else { null }
  let rate = if $pct != null and ($pct.rate | str trim) != "" { $pct.rate | str trim } else { null }
  let percent = if $op_percent == null { null } else if $ctr == null { $op_percent } else {
    (($ctr.op - 1) * 100 + $op_percent) // $ctr.ops
  }
  {
    op: ($ctr | get -o op), ops: ($ctr | get -o ops)
    op_percent: $op_percent, percent: $percent, rate: $rate
    line: ($lines | last 1 | get 0?)
  }
}

# `1m05s` / `12s`, compact because it shares a line with a bar; the same
# shape as `progress::elapsed` in preflight.
def bravais-elapsed [d: duration]: nothing -> string {
  let s = ($d // 1sec)
  if $s >= 3600 {
    $"($s // 3600)h($s mod 3600 // 60 | fill -a right -c '0' -w 2)m"
  } else if $s >= 60 {
    $"($s // 60)m($s mod 60 | fill -a right -c '0' -w 2)s"
  } else { $"($s)s" }
}

# Follow a running Flatpak update to its end: a spinner, the operation
# counter, a bar and Flatpak's own rate. Ctrl-C stops following; the update
# was started in its own session (`setsid`), so it keeps running. Off a
# terminal nothing is drawn: it waits, then returns the final status.
def flatpak-watch []: nothing -> record {
  let log = (flatpak-log)
  if not (flatpak-running) {
    print -e "no Flatpak update running"
    return (flatpak-status)
  }
  let live = (bravais-live)
  # The Linux console font has no braille and no partial blocks.
  let ascii = (($env | get -o TERM) == "linux") or not (($env | get -o LANG | default "") =~ '(?i)utf-?8')
  let frames = if $ascii { ["|" "/" "-" "\\"] } else { ["⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏"] }
  let glyphs = if $ascii { ["#" "-"] } else { ["█" "░"] }
  if $live { print -e "following the Flatpak update — Ctrl-C stops following; the update keeps running (resume: flatpak-watch)" }
  let start = (date now)
  mut tick = 0
  mut prog: any = {percent: null, line: null}
  loop {
    # Re-read the log and re-check the process every fifth frame: `ps -l`
    # walks every process, which is too costly for each redraw.
    if $tick mod 5 == 0 {
      if not (flatpak-running) { break }
      if ($log | path exists) { $prog = (flatpak-progress (^tail -c 16384 $log)) }
    }
    if $live {
      let took = (bravais-elapsed ((date now) - $start))
      let text = if $prog.percent == null {
        $"($frames | get ($tick mod ($frames | length))) flatpak: ($prog.line | default 'starting…')  \(($took)\)"
      } else {
        let n = ($prog.percent * 24 // 100)
        let bar = (("" | fill -c $glyphs.0 -w $n) + ("" | fill -c $glyphs.1 -w (24 - $n)))
        let ops = if $prog.op == null { "" } else { $" ($prog.op)/($prog.ops)" }
        let rate = if $prog.rate == null { "" } else { $"  ($prog.rate)" }
        $"($frames | get ($tick mod ($frames | length))) flatpak($ops)  ($bar) ($prog.percent | fill -a right -w 3)%($rate)  \(($took)\)"
      }
      # Cut to the terminal width: a wrapped line cannot be erased with \r.
      # A terminal that reports no size (0 columns) gets 80.
      let cols = (term size).columns
      let width = (if $cols > 0 { $cols } else { 80 }) - 1
      print -e -n $"\r\e[2K($text | str substring --grapheme-clusters 0..<$width)"
      sleep 200ms
    } else {
      sleep 2sec
    }
    $tick += 1
  }
  if $live { print -e -n "\r\e[2K" }
  flatpak-status
}

# Progress of the declared system Flatpaks: how many refs are still
# outdated, whether an update is running, free space, and the tail of
# its log.
def flatpak-status []: nothing -> record {
  let log = (flatpak-log)
  {
    pending: (^flatpak remote-ls --updates | lines | length)
    running: (flatpak-running)
    # /var/lib/flatpak, not / — this field exists to answer "is there
    # room for a 4.4 GB update", and / is a 16 GiB tmpfs that always
    # looks empty. The real target shares the nvme partition with /nix.
    free: (^df -h /var/lib/flatpak | lines | last | split row -r '\s+' | get 3)
    # Flatpak redraws its bar with carriage returns, so the log is
    # ONE enormous line. Without the split it reads as frozen while
    # still moving — which is exactly how a working download got
    # mistaken for a hung one.
    progress: (if ($log | path exists) {
      open --raw $log | str replace --all "\r" "\n" | lines | where $it != "" | last
    } else {
      "no run recorded"
    })
    # The same log, parsed: operation k of n, its download, the overall
    # percentage and Flatpak's rate. `flatpak-watch` draws these live.
    parsed: (if ($log | path exists) { flatpak-progress (^tail -c 16384 $log) } else { null })
  }
}

# Update every declared system Flatpak, detached, so it survives this
# shell and never blocks it. `--fork` returns in under a millisecond
# and the child inherits the redirection, so neither `sh -c` nor
# POSIX redirection is needed.
def flatpak-update []: nothing -> nothing {
  let log = (flatpak-log)
  mkdir ($log | path dirname)
  ^setsid --fork flatpak update --system -y o+e> $log
  print "flatpak update started — follow it with: flatpak-watch"
}

# ── git sync ──────────────────────────────────────────────────────
# `git -C <repo> ...args`, captured. Named for this file so it cannot
# collide with anything in config.nu, which embeds this text. `--wrapped`
# so git's own flags pass through instead of being parsed as this def's.
def --wrapped bravais-git [repo: string, ...args: string]: nothing -> record {
  ^git -C $repo ...$args | complete
}

# Bring the checkout up to date with origin before anything is built, so a
# rebuild compiles origin's code and not whatever the checkout happens to
# hold. Mirrors git_sync in pkgs/preflight/src/git_sync.rs, which carries the
# full reasoning; change all three. In short: carry uncommitted changes along
# (reported in `carried`; refused only when the incoming commits touch them
# too); fetch --prune;
# keep the current branch while its upstream exists, else (detached, or
# merged and deleted upstream) go to origin's default branch; refuse a
# local-only branch; fast-forward only.
#
# Returns a record rather than raising: `ok` false carries the same `code`,
# `exit` and `hint` preflight reports, and `rebuild` decides what to do with
# it (under --dry, only report).
def bravais-git-sync [repo: string, branch: any, dry: bool, lock_regenerated: bool]: nothing -> record {
  let refuse = {|exit: int, code: string, message: string, hint: string|
    { ok: false, exit: $exit, code: $code, message: $message, hint: $hint }
  }
  if ((bravais-git $repo rev-parse --is-inside-work-tree).stdout | str trim) != "true" {
    return (do $refuse 1 "NOT_A_CHECKOUT" $"($repo) is not a git checkout \(or git is not on PATH\)" "rebuild-classic --no-sync   # build the tree as it is")
  }
  # Porcelain columns 1-2 are the status, so the path starts at column 4.
  let paths = ((bravais-git $repo status --porcelain=v1 --untracked-files=no).stdout
    | lines | where $it != "" | each {|l| $l | str substring 3.. | split row " -> " | last })
  let carried = ($paths | where $it != "flake.lock")
  let dirty = (do $refuse 5 "DIRTY_TREE" $"uncommitted changes conflict with the incoming commits: ($carried | str join ', ')" $"git -C ($repo) stash   # then re-run; or build the tree as it is: rebuild-classic --no-sync")
  let lock_dirty = ("flake.lock" in $paths)

  let fetch = (bravais-git $repo fetch --prune origin)
  if $fetch.exit_code != 0 {
    print -e $fetch.stderr
    return (do $refuse 1 "FETCH_FAILED" "git fetch from origin failed, so the latest code is unknown" "rebuild-classic --no-sync --no-update   # offline: build the tree as it is")
  }

  let head = (bravais-git $repo symbolic-ref --quiet --short HEAD)
  let current = (if $head.exit_code == 0 { $head.stdout | str trim } else { null })
  let origin_head = (bravais-git $repo symbolic-ref --quiet --short refs/remotes/origin/HEAD)
  let default = (if $origin_head.exit_code == 0 { $origin_head.stdout | str trim | str replace --regex '^origin/' "" } else { "main" })

  let choice = if $branch != null {
    { want: $branch, why: "" }
  } else if $current == null {
    { want: $default, why: " (HEAD was detached)" }
  } else if (bravais-git $repo config --get $"branch.($current).merge").exit_code != 0 {
    return (do $refuse 5 "NO_UPSTREAM" $"branch '($current)' has no upstream on origin, so there is nothing to update it from" $"git -C ($repo) switch ($default)   # or build it as it is: rebuild-classic --no-sync")
  } else if (bravais-git $repo rev-parse --verify --quiet $"($current)@{upstream}").exit_code == 0 {
    { want: $current, why: "" }
  } else {
    { want: $default, why: $" \('($current)' was deleted on origin\)" }
  }
  let want = $choice.want
  let switching = ($want != $current)
  let target = if $switching {
    $"origin/($want)"
  } else {
    let u = (bravais-git $repo rev-parse --abbrev-ref $"($want)@{upstream}")
    if $u.exit_code == 0 { $u.stdout | str trim } else { $"origin/($want)" }
  }
  if (bravais-git $repo rev-parse --verify --quiet $"($target)^{commit}").exit_code != 0 {
    return (do $refuse 3 "NO_SUCH_BRANCH" $"origin has no branch '($want)'" $"git -C ($repo) branch --remotes   # the branches origin has")
  }

  # The last run's `nix flake update` leaves flake.lock modified. If the
  # incoming commits change it too, git would refuse to move; when an update
  # follows anyway the stale bump is worthless and is dropped. Under
  # --no-update the lock IS what gets built, so it is never dropped silently.
  let lock_conflicts = $lock_dirty and ((bravais-git $repo diff --quiet HEAD $target -- flake.lock).exit_code != 0)

  if $dry {
    let behind = (bravais-git $repo rev-list --count $"HEAD..($target)").stdout | str trim
    return { ok: true, carried: $carried, message: $"dry run; would move to ($want)($choice.why) at ($target) \(($behind) commit\(s\) behind\); building the tree as it is" }
  }
  if $lock_conflicts {
    if not $lock_regenerated {
      return (do $refuse 5 "LOCK_CONFLICT" $"flake.lock has an uncommitted bump and ($target) changes it too" $"git -C ($repo) restore flake.lock   # drop the local bump, then re-run")
    }
    if (bravais-git $repo restore --staged --worktree -- flake.lock).exit_code != 0 {
      return (do $refuse 1 "LOCK_CONFLICT" "could not discard the uncommitted flake.lock bump" $"git -C ($repo) status")
    }
  }
  if $switching {
    let local = ((bravais-git $repo rev-parse --verify --quiet $"refs/heads/($want)").exit_code == 0)
    let sw = if $local {
      bravais-git $repo switch $want
    } else {
      bravais-git $repo switch --create $want --track $target
    }
    if $sw.exit_code != 0 {
      print -e $sw.stderr
      if ($carried | is-not-empty) { return $dirty }
      return (do $refuse 1 "SWITCH_FAILED" $"could not switch to '($want)'" $"git -C ($repo) status")
    }
  }
  let before = ((bravais-git $repo rev-parse HEAD).stdout | str trim)
  if (bravais-git $repo merge --ff-only $target).exit_code != 0 {
    # A fast-forward that is possible in history can only have been stopped
    # by the working tree.
    let ancestor = ((bravais-git $repo merge-base --is-ancestor HEAD $target).exit_code == 0)
    if $ancestor and ($carried | is-not-empty) { return $dirty }
    return (do $refuse 5 "NOT_FAST_FORWARD" $"'($want)' has commits that ($target) does not, so it cannot be fast-forwarded" $"git -C ($repo) log --oneline ($target)..($want)   # the local-only commits")
  }
  let new = ((bravais-git $repo rev-list --count $"($before)..HEAD").stdout | str trim)
  let short = ((bravais-git $repo rev-parse --short HEAD).stdout | str trim)
  let note = (if $lock_conflicts { "; dropped the uncommitted flake.lock bump" } else { "" })
  { ok: true, carried: $carried, message: $"($want) at ($short)($choice.why); ($new) new commit\(s\)($note)" }
}

# Antigravity staleness probe.
#
# `nix flake update antigravity-nix` bumps the INPUT, but the Antigravity
# version is a `version` + `hash` pair inside that input's
# artifacts/versions.json — the same class of pin `update-vendored.nu`
# exists for here, and equally untouchable by a flake update. So a
# rebuild can report "antigravity-nix: unchanged" while being four IDE
# releases behind, which is exactly what happened between 2026-07-21 and
# 2026-08-19: upstream's daily update.yml was failing, no PR was ever
# opened, and every rebuild in that window looked completely healthy.
#
# Upstream advances those pins on a 07:00 UTC cron and auto-merges, so
# the normal path needs no help from here. This only catches the case
# that actually bit: that cron silently failing for weeks. It compares
# what the lock pins against what Google advertises, and never blocks —
# a probe that fails the rebuild when a Cloud Run endpoint is briefly
# unreachable would be worse than the staleness it reports.
def antigravity-status [] {
  let latest = (try {
    let r = (http get --max-time 10sec
      "https://antigravity-ide-auto-updater-974169037036.us-central1.run.app/releases")
    $"($r.0.version)-($r.0.execution_id)"
  } catch { null })
  let pinned = (try {
    # `open` dispatches on extension and does not know `.lock`, so it
    # hands back a byte stream rather than a record — hence the
    # explicit `--raw | from json`.
    let rev = (open --raw /spacecraft-software/bravais/flake.lock
      | from json | get nodes.antigravity-nix.locked.rev)
    ^nix eval --raw $"github:UnbreakableMJ/antigravity-nix/($rev)#packages.x86_64-linux.google-antigravity-ide.version"
  } catch { null })
  { pinned: $pinned, latest: $latest, current: ($pinned == $latest) }
}

# Full system rebuild for steelbore-thinkpad: load the signing key, bring
# the checkout up to date with origin (see `bravais-git-sync`), bump
# every flake input (a bare `nix flake update`, so an input added to
# flake.nix is tracked without an edit here), free disk while keeping a week of rollback targets,
# build + switch, then mirror the repo into /etc/nixos. A failed
# switch aborts before the mirror.
#   --dry        nixos-rebuild dry-build only; skips GC and the /etc mirror
#   --no-sync    build the checkout as it is; skip git fetch + fast-forward
#   --branch     switch to origin's <name> before building (testing a PR)
#   --no-update  skip `nix flake update`
#   --update-all accepted for compatibility; every run bumps every input
#   --no-gc      skip garbage collection + journal vacuum
#   --trace      add --show-trace --verbose (to diagnose eval failures)
def rebuild-classic [topic?: string, --dry, --no-sync, --branch (-b): string, --no-update, --update-all, --no-gc, --trace, --skills-only, --no-flatpak, --detach-flatpak, --yes] {
  # Explicit usage rather than `help rebuild`. That resolved to nothing when
  # this file is run as the `rebuild` BINARY (where the outer command is
  # `main`), printing an empty response instead of help — so spell it out and
  # get identical behaviour from both the Nu command and the binary.
  if $topic == "help" {
    print "Usage: rebuild-classic [help] [--dry] [--no-sync] [--branch <name>] [--no-update] [--update-all] [--no-gc] [--trace] [--skills-only] [--no-flatpak] [--detach-flatpak] [--yes]"
    print ""
    print "  --dry          nixos-rebuild dry-build only; skips GC and the /etc mirror"
    print "                 (the git sync fetches and reports, but does not move the checkout)"
    print "  --no-sync      build the checkout as it is; skip git fetch and fast-forward"
    print "  -b, --branch   switch to origin's <name> before building (testing a PR)"
    print "  --no-update    skip `nix flake update`"
    print "  --update-all   accepted for compatibility; every run bumps every input"
    print "  --no-gc        skip garbage collection + journal vacuum"
    print "  --trace        add --show-trace --verbose (to diagnose eval failures)"
    print "  --skills-only  bump only `construct`; skip GC, the /etc mirror and the mcpctl probe"
    print "  --no-flatpak   skip the detached Flatpak update"
    print "  --detach-flatpak  start the Flatpak update and return instead of following"
    print "                 its progress bar (always the case off a terminal)"
    print "  --yes          skip the question about using `preflight` instead"
    print ""
    print "Superseded by `preflight` (Rust), which takes all of the above and adds"
    print "--reclaim, --gc-all, --journal-days, --mcp-deploy, --update-vendored and --json. See: preflight --help"
    return
  }
  if $topic != null { print $"(ansi red)unknown argument '($topic)' — try: rebuild-classic help(ansi reset)"; return }
  # The one user-supplied string that reaches git: refuse anything that could
  # be read as a flag or that no branch name can contain (Agentic CLI §7).
  let branch = if $branch == null { null } else {
    if $no_sync { print $"(ansi red)--branch conflicts with --no-sync(ansi reset)"; return }
    if ($branch | str starts-with "-") or ($branch | str contains "..") or ($branch =~ '[\s\p{Cc}]') or ($branch | is-empty) {
      print $"(ansi red)invalid branch name '($branch)'(ansi reset)"; return
    }
    $branch | str replace --regex '^origin/' ""
  }
  if $update_all and ($no_update or $skills_only) {
    print $"(ansi red)--update-all conflicts with --no-update and --skills-only(ansi reset)"; return
  }
  if $detach_flatpak and $no_flatpak {
    print $"(ansi red)--detach-flatpak conflicts with --no-flatpak(ansi reset)"; return
  }

  # Deprecation gate. `preflight` (pkgs/preflight/, Rust) is the supported
  # rebuild orchestrator: it accepts every flag this command does — --dry,
  # --no-update, --no-gc, --trace, --skills-only, --no-flatpak — and adds
  # --reclaim, --gc-all, --journal-days, --mcp-deploy, --update-vendored and
  # --json on top. This
  # Nushell path is kept only as a fallback while preflight beds in, so make
  # choosing it deliberate rather than habitual.
  #
  # --yes skips the question. Non-interactive callers must pass it: `input`
  # on a closed stdin would otherwise return empty and silently abort, which
  # reads as "the command did nothing" in a script or a cron job.
  if not $yes {
    let interactive = ((do -i { ^test -t 0 } | complete | get exit_code) == 0)
    if not $interactive {
      print $"(ansi red)rebuild-classic: refusing to run non-interactively without --yes(ansi reset)"
      print $"(ansi dark_gray)  prefer: preflight(ansi reset)"
      return
    }
    print $"(ansi yellow)`rebuild-classic` is superseded by `preflight`, the Rust rebuild orchestrator.(ansi reset)"
    print $"(ansi dark_gray)  preflight takes the same flags and adds --reclaim, --gc-all,(ansi reset)"
    print $"(ansi dark_gray)  --journal-days, --mcp-deploy, --update-vendored and --json. See: preflight --help(ansi reset)"
    let answer = (input $"(ansi yellow)continue with rebuild-classic anyway? [y/N] (ansi reset)")
    if ($answer | str trim | str downcase) not-in ["y" "yes"] {
      print $"(ansi green)aborted — run `preflight` instead(ansi reset)"
      return
    }
  }
  cd /spacecraft-software/bravais
  # The signing key goes in first: both the git fetch and the flake update
  # can need it.
  if (not $no_sync) or (not $no_update) { gitway-add ~/.ssh/id_ed25519 }
  # Build origin's code, not whatever the checkout happens to hold.
  if $no_sync {
    print $"(ansi dark_gray)git-sync: skipped \(--no-sync\); building the tree as it is(ansi reset)"
  } else {
    let sync = (bravais-git-sync /spacecraft-software/bravais $branch $dry (not $no_update))
    if $sync.ok {
      print $"(ansi green)git-sync: ($sync.message)(ansi reset)"
      # The build is origin's code plus these, so say so.
      if ($sync.carried | is-not-empty) {
        print $"(ansi yellow)building with uncommitted changes: ($sync.carried | str join ', ')(ansi reset)"
      }
    } else if $dry {
      print $"(ansi yellow)git-sync: dry run; would refuse \(($sync.code)\): ($sync.message)(ansi reset)"
    } else {
      # `error make`, not `exit`: this text is also a def in the interactive
      # shell, where `exit` would close the user's terminal.
      error make --unspanned { msg: $"($sync.code): ($sync.message)", help: $"try: ($sync.hint)" }
    }
  }
  # Monthly vendored-binary reminder (elegance plan 5.1): claude-desktop,
  # chrome-remote-desktop, ollama, and BrowserOS pin upstream binaries
  # that `nix flake update` cannot bump.
  let stamp = ($nu.home-dir | path join ".cache" "bravais-vendored-check")
  let stale = (not ($stamp | path exists)) or ((date now) - (ls $stamp | get 0.modified) > 30day)
  if $stale {
    print $"(ansi yellow)vendored binaries unchecked for 30+ days — run: nu pkgs/update-vendored.nu --check(ansi reset)"
    mkdir ($stamp | path dirname); touch $stamp
  }
  # --skills-only is the fast path for a prose-only skill change: skills
  # come from `construct` alone, so bumping the other four inputs drags
  # unrelated rebuild work into an edit that touched a Markdown file.
  # It also drops the GC, the /etc/nixos mirror and the mcpctl probe —
  # none of which a skill edit can affect. What it does NOT drop is the
  # switch itself: a rebuild is what re-points `pinned`/`current` at the
  # new lock; `skills-sync` moves the pointer without one.
  if not $no_update {
    # Anonymous, Nix resolves `github:` inputs through the GitHub API at 60
    # requests an hour, which a bare `nix flake update` exhausts (HTTP 403,
    # 2026-09-27). Borrow the gh CLI's keyring token for the update only:
    # it lives in this one child's environment, never in a file.
    # `extra-access-tokens` keeps any configured tokens; see docs/rebuild.md.
    let gh_token = (try {
      let r = (^gh auth token --hostname github.com | complete)
      if $r.exit_code == 0 { $r.stdout | str trim } else { "" }
    } catch { "" })
    let nix_env = if ($gh_token | is-empty) {
      print $"(ansi dark_gray)github-token: no `gh auth token`; anonymous GitHub API limit \(60/h\)(ansi reset)"
      {}
    } else {
      let line = $"extra-access-tokens = github.com=($gh_token)"
      let prior = ($env.NIX_CONFIG? | default "")
      { NIX_CONFIG: (if ($prior | str trim | is-empty) { $line } else { $"($prior)\n($line)" }) }
    }
    with-env $nix_env {
      if $skills_only {
        nix flake update construct
      } else {
        # No input names = every input, stable nixpkgs and home-manager included.
        nix flake update
      }
    }
    # Report only, and only on the full path: --skills-only does not
    # touch this input, and the probe costs a network round trip.
    if not $skills_only {
      let ag = (antigravity-status)
      if $ag.pinned == null or $ag.latest == null {
        print $"(ansi dark_gray)antigravity: version probe unavailable — skipped(ansi reset)"
      } else if not $ag.current {
        print $"(ansi yellow)antigravity-nix pins IDE ($ag.pinned) but ($ag.latest) is out — its daily auto-update has probably stalled(ansi reset)"
        print $"(ansi dark_gray)  fix upstream: cd /spacecraft-software/antigravity-nix; ./scripts/update-version.sh; then PR to master(ansi reset)"
        print $"(ansi dark_gray)  then re-run: nix flake update antigravity-nix(ansi reset)"
      }
    }
  }
  if (not $no_gc) and (not $dry) and (not $skills_only) {
    try { sudo nix-collect-garbage --delete-older-than 7d }
    try { sudo journalctl --vacuum-time=7d }
  }
  if not $skills_only {
    # /nix, not / — on this host / is a 16 GiB tmpfs that is always
    # near-empty, so `df -h /` reported 0% used while the nvme partition
    # holding /nix and /mnt/nix-tmp was at 100% and builds were failing.
    print $"(ansi blue)── disk before ──(ansi reset)"; df -h /nix
  }
  # --option warn-dirty false silences the "Git tree is dirty" warning on
  # the local flake eval (also set declaratively via nix.settings.warn-dirty;
  # this covers the rebuild run before that lands in /etc/nix/nix.conf).
  # nixos-rebuild-ng rejects nix's --no-warn-dirty passthrough, so use the
  # forwarded --option form it does accept.
  let extra = (["--option" "warn-dirty" "false"] | append (if $trace { ["--show-trace" "--verbose"] } else { [] }))
  if $dry {
    sudo nixos-rebuild dry-build --flake .#steelbore-thinkpad ...$extra
  } else {
    sudo nixos-rebuild switch --flake .#steelbore-thinkpad ...$extra
  }
  if (not $dry) and (not $skills_only) {
    # Lean true mirror: prune stale files, but skip VCS internals,
    # the build symlink, and agent-local context (.claude is gitignored).
    # Measured no-op cost on this tree (333 files, 8.2 MB) is ~0.05 s, so
    # this is deliberately NOT gated on a diff — the gate would cost more
    # to maintain than the copy it skips.
    sudo rsync -av --delete --delete-excluded --exclude='.git/' --exclude='result' --exclude='.claude/' /spacecraft-software/bravais/ /etc/nixos/
    print $"(ansi green)── disk after ──(ansi reset)"; df -h /nix

    # MCP host configs are NOT part of this flake. They live in
    # /spacecraft-software/mcp-servers, are generated from that repo's
    # mcp.toml, and reach the machine only through `mcpctl deploy` — an
    # imperative write into files that Claude Code, goose, Codex and the
    # rest own. A rebuild cannot carry them along, so this only reports.
    #
    # Deliberately a warning and not an automatic deploy. `deploy` refuses
    # a host whose process is running, and a rebuild is usually run from an
    # agent session — so an auto-deploy would silently skip ~/.claude.json,
    # the file most likely to be stale, while reporting success. Surfacing
    # the skip is the useful half; the write stays a deliberate step.
    # mcpctl is invoked BY NAME, not by store path. The store path was
    # deliberate once — "no PATH probe, no cargo-artifact fallback" —
    # and it caused three consecutive false alarms, because the path is
    # baked into this function when Nushell parses config.nu at shell
    # startup. Activation rewrites config.nu, but a shell already
    # running keeps the definition it parsed, so the FIRST rebuild after
    # any mcpctl change probes with the PREVIOUS binary and reports on a
    # manifest it cannot parse. The switch had worked every time.
    #
    # The reason for pinning no longer holds: `~/.cargo/bin` is APPENDED
    # to PATH (see outOfBandDirs), so a Nix-provided mcpctl already wins
    # name resolution over a stray `cargo install` build — constraint
    # #23 says as much. Resolving by name costs nothing and self-heals
    # on the next activation, since the profile bin dir is what moves.
    #
    # Note the input is `github:`, which sees PUSHED content only: this
    # binary is the manifest logic as of the rev in flake.lock, so an
    # mcpctl or mcp.toml change that is merely committed — let alone
    # uncommitted — is not what runs here. Landing one takes commit,
    # push, then `nix flake update mcp-servers`; skip the last and this
    # probe compares deployed configs against the OLD manifest and
    # cheerfully reports no drift.
    let mcp_repo = "/spacecraft-software/mcp-servers"
    if ($mcp_repo | path exists) {
      # --dry-run --json is read-only; it never writes to $HOME.
      let probe = (^mcpctl deploy --dry-run --json --repo $mcp_repo | complete)
      if $probe.exit_code == 0 {
        let report = ($probe.stdout | from json | get data)
        let drifted = ($report.files | where dirty | length)
        if $drifted > 0 {
          # --repo is part of the hint, not decoration: `rebuild` runs
          # from the bravais checkout, so a bare `mcpctl deploy --yes`
          # exits with "no `mcp.toml` in … or any parent". A hint has
          # to be runnable as printed (CLI Standard §3).
          print $"(ansi yellow)($drifted) MCP host config\(s\) drifted from the manifest — run: mcpctl deploy --yes --repo ($mcp_repo)(ansi reset)"
        }
        if ($report.blocked | length) > 0 {
          print $"(ansi yellow)MCP deploy would skip a running host — close it, then: mcpctl deploy --yes --repo ($mcp_repo)(ansi reset)"
          # `for`, not `each`: `each` returns a list and Nushell renders it.
          for entry in $report.blocked { print $"  ($entry)" }
        }
      } else {
        print $"(ansi yellow)mcpctl drift probe failed:(ansi reset)"; print $probe.stderr
      }
    }

    # Flatpak updates, LAST and after the switch — not during it.
    #
    # `services.flatpak.update.onActivation = true` would also do this,
    # and is the more obviously declarative spelling, but it blocks
    # activation on an unbounded download: a browser is ~150 MB and a
    # runtime bump ~250 MB, and the whole set has run to several GB at
    # under 1 MB/s. A switch held open for hours — or interrupted
    # part-way — is a worse failure than a Flatpak being a few days
    # old, and these entries pin no version anyway, so "current" is a
    # property of the remote rather than of this flake.
    #
    # Started DETACHED via `flatpak-update`, not run inline. Inline was
    # the first shape and it made `rebuild` block for as long as the
    # download took — measured at roughly three hours for 4.4 GB at
    # ~0.4 MB/s. That is the same objection that rules out
    # `onActivation`, only moved later in the sequence; detaching is
    # what actually removes it. The switch is already complete by this
    # point, so nothing is left half-applied if the download is slow,
    # interrupted, or fails.
    #
    # Skippable with --no-flatpak. At a terminal the run then FOLLOWS
    # the detached update with a progress bar (`flatpak-watch`) until it
    # ends: detached still means Ctrl-C or a closed terminal only stops
    # the watching, never the update. --detach-flatpak returns at once,
    # as every run off a terminal (an agent, a script) always does;
    # `flatpak-watch` picks the bar up again later, `flatpak-status`
    # gives a one-shot record. The weekly timer in
    # modules/packages/flatpak.nix stays as the safety net for stretches
    # without a rebuild.
    if not $no_flatpak {
      let pending = (flatpak-status | get pending)
      if $pending > 0 {
        print $"(ansi blue)── flatpak: ($pending) update\(s\), detached ──(ansi reset)"
        flatpak-update
        if (not $detach_flatpak) and (bravais-live) {
          # Give the forked update a moment to exist, or the watcher
          # finds nothing running and returns at once.
          sleep 1sec
          let done = (flatpak-watch)
          print $"(ansi green)flatpak: ($done.progress)(ansi reset)"
        }
      } else {
        print $"(ansi green)flatpak: up to date(ansi reset)"
      }
    }
  }
}
