#!/usr/bin/env nu
# SPDX-FileCopyrightText: 2026 Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Steelbore Bravais — Copilot skill vendoring sync.
#
# `.github/skills/` is read by the GitHub Copilot coding agent, Copilot CLI and
# the VS Code / Visual Studio agent modes. Those runners get a plain `git clone`
# of this repo: they cannot follow a symlink into the Nix store, evaluate the
# `construct` flake input, or reach `/spacecraft-software/construct`. So the
# skills have to be vendored as real files — and vendored files drift.
#
# This script removes the drift by making `.github/skills/` a pure function of
# the `construct` rev already pinned in `flake.lock`. Same input as
# `~/.agents/skills` (the Home Manager path), so the local agents and the cloud
# agents read byte-identical skills.
#
# Usage (any directory inside the repo):
#   nu pkgs/sync-skills.nu           # rewrite .github/skills/ from the pinned rev
#   nu pkgs/sync-skills.nu --check   # report drift, change nothing (CI gate)
#
# To move to a newer skill set: `nix flake update construct` (or `skills-sync`),
# then re-run this script and commit both `flake.lock` and `.github/skills/`.
# Never hand-edit a file under `.github/skills/` — edit it in Construct and
# re-sync, or the next run silently reverts it.

# The vendored subset. Construct ships ~45 skills; the cloud agent matches a
# request against every skill's `description` frontmatter, so a full mirror is
# mostly context tax. These are the ones that fire on work that actually
# happens in this repo — Nix modules, Nushell, the in-tree Rust packages, and
# the CLI / theme / brand / Standard conventions.
const SKILLS = [
    "microsoft-rust-guidelines"        # pkgs/steelbore-audio-led, bravais-mcp (upstream MIT)
    "spacecraft-agentic-cli"           # AGENTS.md / CLAUDE.md authoring
    "spacecraft-brand-guidelines"      # Void Navy / Molten Amber identity
    "spacecraft-cli-preference"        # rg over grep, eza over ls, …
    "spacecraft-cli-shell"             # Nushell vs POSIX syntax
    "spacecraft-cli-standard"          # dual-mode self-documenting CLI
    "spacecraft-document-format"       # document deliverables
    "spacecraft-missing-pkg"           # packaging a missing dependency
    "spacecraft-nix-guidelines"        # every modules/**.nix in this repo
    "spacecraft-nu-guidelines"         # users/mj/shell.nix, pkgs/*.nu
    "spacecraft-rust-guidelines"       # house Rust style, pairs with the MS set
    "spacecraft-standard-constitution" # The Steelbore Standard
    "spacecraft-theme-factory"         # lib/terminal-theme.nix emitters
]

const VENDOR_DIR = ".github/skills"

# The `construct` rev pinned in flake.lock — the single source of truth.
# `open` does not infer JSON from a `.lock` extension, hence the explicit
# `--raw` + `from json`.
def pinned-rev [] {
    open --raw flake.lock | from json | get nodes.construct.locked.rev
}

# Fetch that exact rev into the store and return its path. Cheap: one repo,
# not `nix flake archive`, which would drag in nixpkgs for nothing.
def construct-source [rev: string] {
    (nix flake prefetch --json $"github:Spacecraft-Software/Construct/($rev)"
        | from json
        | get storePath)
}

# NAR hash of a directory tree, or null when it does not exist. NAR ignores
# read/write bits (store paths are 444) but records the executable bit, so a
# store→worktree copy compares equal.
def tree-hash [dir: path] {
    if not ($dir | path exists) { return null }
    nix hash path --type sha256 --sri $dir | str trim
}

# Replace one vendored skill with the upstream tree. `cp -r` out of the store
# yields read-only files, so restore write permission — otherwise a later
# `git checkout` or edit fails with EACCES.
def vendor-one [src: path, dest: path] {
    rm -rf $dest
    cp -r $src $dest
    chmod -R u+w $dest
}

def main [--check] {
    cd (git rev-parse --show-toplevel | str trim)

    let rev = (pinned-rev)
    print $"construct pinned at ($rev | str substring 0..7) \(flake.lock)"
    let src = (construct-source $rev)

    # Anything vendored but absent from SKILLS is an orphan — a skill renamed
    # or removed upstream. Leaving orphans behind is how `rust-guidelines` and
    # `spacecraft-standard` outlived their upstream names for months.
    let vendored = if ($VENDOR_DIR | path exists) {
        ls $VENDOR_DIR | where type == dir | get name | each {|p| $p | path basename }
    } else { [] }
    let orphans = ($vendored | where {|v| $v not-in $SKILLS })

    let results = ($SKILLS | each {|skill|
        let up = ($src | path join $skill)
        if not ($up | path exists) {
            error make {msg: $"($skill) is not in Construct at ($rev) — renamed or removed upstream; fix the SKILLS list"}
        }
        let dest = ($VENDOR_DIR | path join $skill)
        let have = (tree-hash $dest)
        let action = if $have == null {
            "missing"
        } else if $have == (tree-hash $up) {
            "in sync"
        } else {
            "drifted"
        }
        if $action != "in sync" and (not $check) {
            vendor-one $up $dest
        }
        {skill: $skill, action: $action}
    })

    let stale = ($results | where action != "in sync")
    let clean = ($stale | is-empty) and ($orphans | is-empty)

    if $check {
        print ($results | append ($orphans | each {|o| {skill: $o, action: "orphan"} }))
        if $clean {
            print $"($VENDOR_DIR) matches Construct ($rev | str substring 0..7)"
            return
        }
        print $"($VENDOR_DIR) is stale — run `nu pkgs/sync-skills.nu` and commit the result"
        exit 1
    }

    for o in $orphans {
        rm -rf ($VENDOR_DIR | path join $o)
    }
    print ($results | append ($orphans | each {|o| {skill: $o, action: "pruned"} }))
    if $clean {
        print "already up to date"
    } else {
        print "review with `git diff --stat .github/skills/` and commit"
    }
}
