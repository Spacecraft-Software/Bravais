# Guix (`guix shell`) — preferred provisioner

Ephemeral, no sudo, any tool in the Guix package set (~31,000 packages).
Leaves no durable state on the host — the store is garbage-collected later.

## Syntax

```bash
# Single tool
guix shell <pkg> -- <command> <args>

# Multiple tools in one environment
guix shell pkg1 pkg2 pkg3 -- <command> <args>
```

### Key notes

- **No `-p` flag** — package names are listed bare, before `--`.
- **`--` is the separator** between packages and the command.
- Everything after `--` is exec'd directly (no shell). Pipelines, redirects,
  and globs need an explicit `sh -c '...'`.
- Do not use the deprecated `guix environment --ad-hoc` form — it still
  works but is superseded.

## Examples

```bash
# Static analysis of a shell script
guix shell shellcheck -- shellcheck script.sh

# Benchmark two commands
guix shell hyperfine -- hyperfine 'command_a' 'command_b'

# Search a codebase
guix shell ripgrep -- rg 'fn main' src/

# Multi-tool pipeline (pipes require sh -c)
guix shell ripgrep coreutils -- sh -c 'ls *.rs | xargs rg pattern'

# Plain Python interpreter
guix shell python -- python3 script.py

# Python with libraries (verify each name on packages.guix.gnu.org)
guix shell python python-requests -- python3 script.py

# Quick QEMU VM
guix shell qemu -- qemu-system-x86_64 -nographic -m 512 disk.img

# Nushell (Spacecraft Software-preferred shell)
guix shell nushell -- nu -c 'ls | where size > 1kb'
```

## Extras

### Maximum isolation with `--container`

```bash
guix shell --container --network jq -- jq --version
```

`--container` runs inside an isolated namespace (Linux only, Linux-libre
3.19+). Add `--network` if the command needs network access.

### Reproducible manifest-based environment

```bash
# manifest.scm (verify names against packages.guix.gnu.org):
#   (specifications->manifest '("ripgrep" "hyperfine" "shellcheck"))
guix shell -m manifest.scm -- sh -c "shellcheck script.sh && hyperfine 'rg foo'"
```

### Pure environment (unset host env vars)

```bash
guix shell --pure <pkg> -- <cmd>
```

### Time-travel to a pinned Guix commit

```bash
guix time-machine --commit=<git-commit> -- shell <pkg> -- <cmd>
```

## Lookup

- Online: <https://packages.guix.gnu.org/>
- CLI: `guix search <regex>` or `guix package -s <regex>`
- See [lookup.md](lookup.md) for details.

## Cleanup

None required. The store is garbage-collected by `guix gc`. Profiles created
by `guix shell` are short-lived unless anchored with `-r <file>`.
