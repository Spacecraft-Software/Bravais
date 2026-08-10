#!/usr/bin/env nu
# SPDX-FileCopyrightText: 2026 Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Steelbore Bravais — vendored-binary updater (elegance plan 5.1).
#
# Nine packages pin upstream versions that `nix flake update` cannot bump;
# this script reads each upstream source of truth, rewrites version + hash
# in place, and builds the result:
#
#   claude-desktop         pkgs/claude-desktop/package.nix         Anthropic apt index
#   chrome-remote-desktop  pkgs/chrome-remote-desktop/package.nix  Google apt index
#   ollama                 pkgs/ollama/package.nix                 GitHub releases
#   goose-desktop          pkgs/goose-desktop/package.nix          GitHub releases
#   opencode-desktop       pkgs/opencode-desktop/package.nix       GitHub releases
#   github-copilot-app     pkgs/github-copilot-app/package.nix     GitHub releases
#   adguardvpn-cli         pkgs/adguardvpn-cli/package.nix         GitHub releases
#   browseros              modules/packages/browsers.nix           GitHub releases
#   obscura                pkgs/obscura/package.nix                GitHub releases
#
# Eight of the nine vendor a prebuilt BINARY, so a bump is "swap the URL, hash
# the download". obscura is the exception: it is built from source and pins two
# hashes, neither of them a release asset. See up-obscura.
#
# Usage (any directory inside the repo):
#   nu pkgs/update-vendored.nu              # bump all nine + nix build each
#   nu pkgs/update-vendored.nu --check      # report only, change nothing
#   nu pkgs/update-vendored.nu ollama       # single package
#
# Rewrites are textual and idempotent — review with `git diff`, commit like
# any other change. The `rebuild` command nags monthly to run --check.

# Newest stanza for $package in a Debian Packages index → {version, sha256}.
def apt-latest [index_url: string, package: string] {
  http get --raw $index_url
  | decode utf-8
  | split row "\n\n"
  | where {|stanza| $stanza | lines | any {|l| $l == $"Package: ($package)" } }
  | each {|stanza| {
      version: ($stanza | parse -r '(?m)^Version: (?<v>.+)$' | get 0.v)
      sha256: ($stanza | parse -r '(?m)^SHA256: (?<h>[0-9a-f]{64})$' | get 0.h)
    } }
  | sort-by -n version
  | last
}

# Newest non-prerelease GitHub tag matching $pattern, without the leading
# "v". The BrowserOS repo interleaves unrelated product tags (agent-server/…)
# so /releases/latest alone is not trustworthy — filter and take the newest.
def github-latest [repo: string, pattern: string = '^v[0-9]'] {
  http get $"https://api.github.com/repos/($repo)/releases?per_page=30"
  | where {|r| (not $r.prerelease) and (not $r.draft) and ($r.tag_name =~ $pattern) }
  | get 0.tag_name
  | str replace -r '^v' ''
}

# Download $url into the store and return its SRI hash (sha256-…).
def prefetch-sri [url: string] {
  nix store prefetch-file --json $url | from json | get hash
}

# SRI hash of an UNPACKED GitHub tree at $tag — what fetchFromGitHub pins.
# prefetch-sri is wrong for this: fetchFromGitHub hashes the extracted tree,
# not the tarball, so hashing the file reports a value that never matches.
# (`nix store prefetch-file` has no --unpack; `nix flake prefetch` does the
# right thing here and does not require the repo to contain a flake.nix.)
def prefetch-github-tree [repo: string, tag: string] {
  nix flake prefetch --json $"github:($repo)/($tag)" | from json | get hash
}

def hex-to-sri [hex: string] {
  nix hash convert --hash-algo sha256 --to sri $hex | str trim
}

# First value captured by $pattern in $file (the current version or hash).
def extract [file: path, pattern: string] {
  open --raw $file | parse -r $pattern | get 0.x
}

# Apply exact from→to replacements; refuse to write if a pattern is missing.
def rewrite [file: path, pairs: list] {
  mut text = (open --raw $file)
  for p in $pairs {
    if not ($text | str contains $p.from) {
      error make {msg: $"pattern not found in ($file): ($p.from)"}
    }
    $text = ($text | str replace $p.from $p.to)
  }
  $text | save -f $file
}

# Shared driver: compare, optionally rewrite (hashes computed lazily only
# when an update is real), optionally `nix build` a flake attr.
def update-one [
  pkg: string, file: path, current: string, latest: string,
  check: bool, pairs: closure, attr?: string,
] {
  if $latest == $current {
    return {package: $pkg, current: $current, latest: $latest, action: "up to date"}
  }
  if $check {
    return {package: $pkg, current: $current, latest: $latest, action: "update available"}
  }
  rewrite $file (do $pairs)
  if $attr != null {
    print $"building .#($attr) …"
    # A failed build must NOT abort the run. `nix build` raising here used to
    # kill the whole `each` in main, so one broken package silently skipped
    # every package after it — which is exactly what happened on 2026-08-04,
    # when claude-desktop 1.24012.11 renamed its .desktop entry and the other
    # six were never attempted. Record the failure and carry on.
    #
    # The rewrite above has already landed at this point, and it is left in
    # place deliberately: the version/hash bump is nearly always correct and
    # the *packaging* is what needs fixing, so the modified file is the
    # starting point for that fix. `build failed` in the table means "file
    # modified, needs work" — check `git diff`.
    let built = (try { nix build --no-link $".#($attr)"; true } catch { false })
    if not $built {
      return {package: $pkg, current: $current, latest: $latest, action: "build failed"}
    }
  }
  {package: $pkg, current: $current, latest: $latest, action: "updated"}
}

def up-claude [check: bool] {
  let file = "pkgs/claude-desktop/package.nix"
  let cur = (extract $file 'version = "(?<x>[^"]+)"')
  let idx = (apt-latest "https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages" "claude-desktop")
  update-one "claude-desktop" $file $cur $idx.version $check {||
    [
      {from: $'version = "($cur)";', to: $'version = "($idx.version)";'}
      {from: (extract $file 'hash = "(?<x>sha256-[^"]+)"'), to: (hex-to-sri $idx.sha256)}
    ]
  } "claude-desktop"
}

def up-crd [check: bool] {
  let file = "pkgs/chrome-remote-desktop/package.nix"
  let cur = (extract $file 'version = "(?<x>[^"]+)"')
  let idx = (apt-latest "https://dl.google.com/linux/chrome-remote-desktop/deb/dists/stable/main/binary-amd64/Packages" "chrome-remote-desktop")
  update-one "chrome-remote-desktop" $file $cur $idx.version $check {||
    [
      {from: $'version = "($cur)";', to: $'version = "($idx.version)";'}
      {from: (extract $file 'sha256 = "(?<x>[0-9a-f]{64})"'), to: $idx.sha256}
    ]
  } "chrome-remote-desktop"
}

# Every GitHub-release package here pins the same two strings — `version =
# "X"` and an SRI `hash = "sha256-…"` — inside `pkgs/<name>/package.nix`, and
# is exposed as flake attr <name>. So a bump differs only in the repo and the
# asset URL: $asset receives the new version and returns the download URL.
#
# $tag_pattern / $strip_suffix exist for repos whose tags carry decoration the
# package's `version` string does not — AdGuardVPNCLI tags `v1.7.12-release`
# for version "1.7.12". $asset receives the *cleaned* version and re-adds the
# decoration where the URL needs it.
def up-github [
  pkg: string, repo: string, asset: closure, check: bool,
  tag_pattern: string = '^v[0-9]', strip_suffix: string = '',
] {
  let file = $"pkgs/($pkg)/package.nix"
  let cur = (extract $file 'version = "(?<x>[^"]+)"')
  let latest = (github-latest $repo $tag_pattern | str replace -r $"($strip_suffix)$" '')
  update-one $pkg $file $cur $latest $check {||
    [
      {from: $'version = "($cur)";', to: $'version = "($latest)";'}
      {
        from: (extract $file 'hash = "(?<x>sha256-[^"]+)"')
        to: (prefetch-sri (do $asset $latest))
      }
    ]
  } $pkg
}

# obscura is the only entry here built FROM SOURCE, and it pins two hashes
# rather than one — neither of which up-github can produce:
#
#   src        a fetchFromGitHub hash taken over the UNPACKED tree, so there is
#              no release asset to prefetch (see prefetch-github-tree).
#   cargoHash  the vendored dependency tree, which does not exist until cargo
#              has resolved the lock. No URL yields it. The only way to learn
#              it is to build against a deliberately wrong hash and read the
#              `got:` line back out of the failure.
#
# Hence the two-phase shape: rewrite version + src first, then discover
# cargoHash. Note the src hash is matched by the plain `hash = "…"` pattern and
# cargoHash by its own — the two never collide, because the regex is
# case-sensitive and `cargoHash = "` contains `Hash`, not `hash`.
#
# The v8 pin in pkgs/obscura/librusty_v8.nix is deliberately NOT touched here:
# it tracks Obscura's deno_core dependency, not its release, and changes far
# more rarely. If a bump fails to link, check that pin against the new lock.
def up-obscura [check: bool] {
  let file = "pkgs/obscura/package.nix"
  let repo = "h4ckf0r0day/obscura"
  let cur = (extract $file 'version = "(?<x>[^"]+)"')
  let latest = (github-latest $repo)

  # No build attr on this call: cargoHash is still the PREVIOUS release's at
  # this point, so a build here would fail on that rather than on anything real.
  let staged = (update-one "obscura" $file $cur $latest $check {||
    [
      {from: $'version = "($cur)";', to: $'version = "($latest)";'}
      {
        from: (extract $file 'hash = "(?<x>sha256-[^"]+)"')
        to: (prefetch-github-tree $repo $"v($latest)")
      }
    ]
  })
  if $staged.action != "updated" {
    return $staged
  }

  # Phase two. Poison cargoHash so the next build is guaranteed to report the
  # correct value rather than succeeding against a stale one.
  let fake = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  rewrite $file [{from: (extract $file 'cargoHash = "(?<x>sha256-[^"]+)"'), to: $fake}]

  print "resolving obscura cargoHash …"
  let probe = (do { nix build --no-link ".#obscura" } | complete)
  let got = ($"($probe.stdout)($probe.stderr)" | parse -r 'got:\s+(?<x>sha256-[A-Za-z0-9+/=]+)')
  if ($got | is-empty) {
    return {
      package: "obscura", current: $cur, latest: $latest
      action: "error: no cargoHash reported — cargoHash left poisoned, see `git diff`"
    }
  }
  rewrite $file [{from: $fake, to: ($got | get 0.x)}]

  # Now a real build, on the same terms as every other package: a failure
  # leaves the rewrite in place because the bump is nearly always right and
  # the packaging is what needs work.
  print "building .#obscura …"
  let built = (try { nix build --no-link ".#obscura"; true } catch { false })
  if not $built {
    return {package: "obscura", current: $cur, latest: $latest, action: "build failed"}
  }
  {package: "obscura", current: $cur, latest: $latest, action: "updated"}
}

def up-browseros [check: bool] {
  let file = "modules/packages/browsers.nix"
  let cur = (extract $file 'browserosVersion = "(?<x>[^"]+)"')
  let latest = (github-latest "browseros-ai/BrowserOS")
  let result = (update-one "browseros" $file $cur $latest $check {||
    [
      {from: $'browserosVersion = "($cur)";', to: $'browserosVersion = "($latest)";'}
      {
        from: (extract $file 'hash = "(?<x>sha256-[^"]+)"')
        to: (prefetch-sri $"https://github.com/browseros-ai/BrowserOS/releases/download/v($latest)/BrowserOS_v($latest)_x64.AppImage")
      }
    ]
  })
  if $result.action == "updated" {
    # Not a flake package — the AppImage was prefetch-verified above; the
    # wrapType2 derivation itself is exercised by the next system build.
    print "browseros: updated (built at next rebuild — not a flake package)"
  }
  $result
}

def main [package?: string, --check] {
  cd (git rev-parse --show-toplevel | str trim)
  let known = [
    "claude-desktop" "chrome-remote-desktop" "ollama"
    "goose-desktop" "opencode-desktop" "github-copilot-app"
    "adguardvpn-cli" "browseros" "obscura"
  ]
  let targets = if $package == null {
    $known
  } else if $package in $known {
    [$package]
  } else {
    error make {msg: $"unknown package '($package)' — one of: ($known | str join ', ')"}
  }
  # Collect before returning so the summary prints as one table (streaming
  # would split it around the slower network calls).
  #
  # Each package is isolated in its own try/catch so ANY failure — an upstream
  # API 404, a moved release asset, a prefetch timeout, a broken build — costs
  # you that one package instead of every package after it in the list.
  let results = ($targets | each {|t|
    try {
    match $t {
      "claude-desktop" => (up-claude $check)
      "chrome-remote-desktop" => (up-crd $check)
      "ollama" => (up-github "ollama" "ollama/ollama" {|v|
        $"https://github.com/ollama/ollama/releases/download/v($v)/ollama-linux-amd64.tar.zst"
      } $check)
      # block/goose was transferred to aaif-goose/goose; the old URLs still
      # redirect, but query the canonical org so this keeps working when they stop.
      "goose-desktop" => (up-github "goose-desktop" "aaif-goose/goose" {|v|
        $"https://github.com/aaif-goose/goose/releases/download/v($v)/goose_($v)_amd64.deb"
      } $check)
      "opencode-desktop" => (up-github "opencode-desktop" "anomalyco/opencode" {|v|
        $"https://github.com/anomalyco/opencode/releases/download/v($v)/opencode-desktop-linux-amd64.deb"
      } $check)
      "github-copilot-app" => (up-github "github-copilot-app" "github/app" {|v|
        $"https://github.com/github/app/releases/download/v($v)/GitHub-Copilot-linux-x64.deb"
      } $check)
      # Tags are "v1.7.12-release" but the version string is "1.7.12", so the
      # suffix is stripped for comparison and re-added in the download URL.
      "adguardvpn-cli" => (up-github "adguardvpn-cli" "AdguardTeam/AdGuardVPNCLI" {|v|
        $"https://github.com/AdguardTeam/AdGuardVPNCLI/releases/download/v($v)-release/adguardvpn-cli-($v)-linux-x86_64.tar.gz"
      } $check '^v[0-9].*-release$' '-release')
      "browseros" => (up-browseros $check)
      # Source-built, two hashes, no release asset — see up-obscura.
      "obscura" => (up-obscura $check)
    }
    } catch {|err|
      {package: $t, current: "?", latest: "?", action: $"error: ($err.msg)"}
    }
  })

  # Surface problems after the table rather than leaving them to be spotted in
  # a column — a bad row is easy to miss in an eight-row summary.
  let failed = ($results | where {|r| $r.action == "build failed" or ($r.action | str starts-with "error:") })
  if not ($failed | is-empty) {
    print ""
    print $"($failed | length) of ($results | length) package\(s\) need attention:"
    for f in $failed {
      print $"  ($f.package): ($f.action)"
    }
    print "Files may already carry the new version/hash — review with `git diff`."
  }
  $results
}
