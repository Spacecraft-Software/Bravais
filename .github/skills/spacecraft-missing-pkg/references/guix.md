# Guix (`guix shell`) — preferred provisioner (Band A, tier 1)

Ephemeral, no sudo, any tool in the Guix package set (~31,000 packages).
Leaves no durable state on the host — the store is garbage-collected later on
the user's own schedule. **Run freely; no consent needed.**

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
- **One invocation, one environment.** Each agent tool call is a fresh
  process, so a `guix shell` environment does not survive to the next call —
  wrap every command.

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

## Never do these

- **`guix install <pkg>`** — imperative profile install. It writes a durable
  entry into `~/.guix-profile`, outside any declarative home configuration, and
  is exactly the drift this skill exists to prevent.
- **`guix gc` as "cleanup"** — that collects the user's whole store, not just
  what you pulled in. Not yours to run.

If the tool should persist, it belongs in a manifest or the host's Guix Home
configuration ([declarative.md](declarative.md)), or in the repo's `guix.scm`
([project-env.md](project-env.md)) — never in an ad-hoc profile.

## Related

- Repo needs it repeatedly → `guix.scm` / `manifest.scm`:
  [project-env.md](project-env.md)
- User wants it permanently → Guix Home / `~/.config/guix/manifest.scm`:
  [declarative.md](declarative.md)

## Lookup

- Online: <https://packages.guix.gnu.org/>
- CLI: `guix search <regex>` or `guix package -s <regex>`
- See [lookup.md](lookup.md) for details.

## Cleanup

None required. The store is garbage-collected by `guix gc`. Profiles created
by `guix shell` are short-lived unless anchored with `-r <file>`.
