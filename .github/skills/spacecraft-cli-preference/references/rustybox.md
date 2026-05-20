# rustybox

**Replaces:** `busybox` | **Language:** 🦀 Rust | **Install:** `cargo install rustybox`

## Purpose
100% Rust reimplementation of BusyBox — a single multicall binary providing tiny versions of common Unix tools. Suited for embedded / minimal container images where you want memory-safe primitives.

## Usage
Symlink `rustybox` under each applet name, or invoke via the multicall binary:
```
rustybox ls -la
rustybox cat /etc/os-release
```

## Examples
1. List applets: `rustybox --list`
2. Busybox-style applet call: `rustybox sh -c 'echo hi'`
3. Static Linux container with rustybox + distroless: ship a single `/bin/rustybox` binary with symlinks.

## Gotchas
- Not all BusyBox applets exist yet; coverage is growing but incomplete.
- Applet behaviour may differ slightly from BusyBox for edge cases; test CI.
