#!/usr/bin/env nu
# SPDX-FileCopyrightText: 2026 Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Steelbore Bravais — vendored-binary updater (elegance plan 5.1).
#
# Seven packages pin upstream binaries that `nix flake update` cannot bump;
# this script reads each upstream source of truth, rewrites version + hash
# in place, and builds the result:
#
#   claude-desktop         pkgs/claude-desktop/package.nix         Anthropic apt index
#   chrome-remote-desktop  pkgs/chrome-remote-desktop/package.nix  Google apt index
#   ollama                 pkgs/ollama/package.nix                 GitHub releases
#   goose-desktop          pkgs/goose-desktop/package.nix          GitHub releases
#   opencode-desktop       pkgs/opencode-desktop/package.nix       GitHub releases
#   github-copilot-app     pkgs/github-copilot-app/package.nix     GitHub releases
#   browseros              modules/packages/browsers.nix           GitHub releases
#
# Usage (any directory inside the repo):
#   nu pkgs/update-vendored.nu              # bump all seven + nix build each
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
    nix build --no-link $".#($attr)"
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
def up-github [
  pkg: string, repo: string, asset: closure, check: bool,
] {
  let file = $"pkgs/($pkg)/package.nix"
  let cur = (extract $file 'version = "(?<x>[^"]+)"')
  let latest = (github-latest $repo)
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
    "goose-desktop" "opencode-desktop" "github-copilot-app" "browseros"
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
  let results = ($targets | each {|t|
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
      "browseros" => (up-browseros $check)
    }
  })
  $results
}
