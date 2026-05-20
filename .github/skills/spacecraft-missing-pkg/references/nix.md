# Nix (`nix-shell`) — ephemeral fallback

Ephemeral, no sudo, massive package set (nixpkgs, ~120,000 packages).
Leaves no durable state on the host — the store is garbage-collected later.

## Syntax

```bash
# Single tool
nix-shell -p <pkg> --run "<command and args>"

# Multiple tools in one environment
nix-shell -p pkg1 -p pkg2 -p pkg3 --run "<command>"
```

### Key notes

- **Always use `--run`** rather than dropping into an interactive shell.
- `--run` executes through a shell, so pipes, redirects, and globs work
  naturally inside the quoted string.
- Attribute paths use dotted notation (`nodePackages.prettier`,
  `python3Packages.requests`).

## Examples

```bash
# Static analysis of a shell script
nix-shell -p shellcheck --run "shellcheck script.sh"

# Benchmark two commands
nix-shell -p hyperfine --run "hyperfine 'command_a' 'command_b'"

# Search a codebase
nix-shell -p ripgrep --run "rg 'fn main' src/"

# Multi-tool pipeline (pipes work naturally inside --run)
nix-shell -p ripgrep -p fd --run "fd -e rs | xargs rg 'fn'"

# Plain Python
nix-shell -p python3 --run "python3 script.py"

# Python with libraries via withPackages
nix-shell -p "python3.withPackages(ps: with ps; [ requests rich numpy ])" \
  --run "python3 script.py"

# Quick QEMU VM
nix-shell -p qemu --run "qemu-system-x86_64 -nographic -m 512 disk.img"

# Nushell
nix-shell -p nushell --run "nu -c 'ls | where size > 1kb'"
```

## Extras

### Pin nixpkgs to a specific commit

```bash
nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/<commit>.tar.gz \
  -p <pkg> --run "<cmd>"
```

### Pure environment (unset host env vars)

```bash
nix-shell --pure -p <pkg> --run "<cmd>"
```

### `nix shell` (flakes, modern CLI)

If Nix is configured with flakes enabled, the newer command is simpler:

```bash
nix shell nixpkgs#<pkg> --command <cmd> <args>
```

Prefer `nix-shell -p ... --run "..."` for broadest compatibility — it works
without flakes enabled and is the documented canonical form.

## Lookup

- Online: <https://search.nixos.org/packages>
- CLI: `nix search nixpkgs#<tool-name>`
- See [lookup.md](lookup.md) for details.

## Cleanup

None required. The store is garbage-collected by `nix-collect-garbage` or
`nix store gc`. Short-lived `nix-shell` invocations leave no lasting profile.
