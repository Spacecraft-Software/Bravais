# uutils (coreutils)

**Replaces:** GNU coreutils | **Language:** 🦀 Rust | **Install:** via `spacecraft-missing-pkg` (upstream crate: `coreutils`; distro package: `rust-coreutils`)

## Purpose
Cross-platform, memory-safe rewrite of GNU coreutils (`ls`, `cp`, `mv`, `rm`, `mkdir`, `cat`, `sort`, `uniq`, …). Aims for GNU compatibility; used as default coreutils in Ubuntu 25.10 and beyond.

## Usage
Invoke individual utilities either by symlink name (`ls`, `cp`, …) or via the multicall binary:
```
coreutils ls -la
coreutils sort file
```

## Install as system coreutils
Route provisioning through `spacecraft-missing-pkg`. Making uutils *the*
system coreutils is a durable, system-wide change — propose it, don't perform
it:
- NixOS: `environment.systemPackages = [ pkgs.uutils-coreutils ];` and prefer via PATH order.
- Home Manager: `home.packages = [ pkgs.uutils-coreutils ];`
- Arch: distro package `uutils-coreutils` (community).
- Elsewhere: the `coreutils` crate, symlinked per tool.

## Examples
1. Drop-in GNU replacement on a test shell: `PATH="$HOME/.cargo/bin:$PATH" ls -la`
2. List available tools: `coreutils --list`
3. Multicall invocation: `coreutils cp src dst`

## Gotchas
- A few flags from GNU coreutils are not yet implemented — check `<tool> --help`.
- Switching system coreutils wholesale can break scripts that depend on GNU-specific edge cases; migrate gradually.
