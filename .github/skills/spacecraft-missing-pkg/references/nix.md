# Nix — ephemeral provisioner (Band A, tier 2)

Ephemeral, no sudo, massive package set (nixpkgs, ~120,000 packages). Leaves no
durable state on the host — the store is garbage-collected later on the user's
own schedule. **Run freely; no consent needed.**

Two forms. `nix run` is the modern one-shot, preferred wherever flakes are
enabled; `nix-shell -p … --run` works on every Nix install.

## Syntax

```sh
# Flakes enabled (check: `experimental-features = nix-command flakes`)
nix run nixpkgs#<pkg> -- <args>
nix shell nixpkgs#<pkg1> nixpkgs#<pkg2> --command <cmd> <args>   # multiple tools

# Works everywhere (no flakes required)
nix-shell -p <pkg> --run "<command and args>"
nix-shell -p pkg1 -p pkg2 -p pkg3 --run "<command>"
```

Check whether flakes are on:

```sh
grep -s experimental-features /etc/nix/nix.conf ~/.config/nix/nix.conf
```

### Key notes

- **Always use `--run` / `--command` / `nix run`** rather than dropping into an
  interactive shell. Each agent tool call is a fresh process, so an interactive
  `nix-shell` does not survive it.
- `nix run nixpkgs#<pkg>` runs the flake's default app; when the binary name
  differs from the attribute, use `nix shell nixpkgs#<pkg> --command <binary>`.
- `--run` executes through a shell, so pipes, redirects, and globs work
  naturally inside the quoted string. `nix run … --` passes arguments straight
  to the program, so a pipeline needs an explicit `sh -c '…'`.
- Attribute paths use dotted notation (`nodePackages.prettier`,
  `python3Packages.requests`).

## Examples

```sh
# Static analysis of a shell script
nix run nixpkgs#shellcheck -- script.sh
nix-shell -p shellcheck --run "shellcheck script.sh"

# Benchmark two commands
nix run nixpkgs#hyperfine -- 'command_a' 'command_b'

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
nix run nixpkgs#nushell -- -c 'ls | where size > 1kb'
```

## Extras

### Pin nixpkgs to a specific commit

```sh
nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/<commit>.tar.gz \
  -p <pkg> --run "<cmd>"

nix run github:NixOS/nixpkgs/<commit>#<pkg> -- <args>
```

### Pure environment (unset host env vars)

```sh
nix-shell --pure -p <pkg> --run "<cmd>"
```

### Unfree packages

```sh
NIXPKGS_ALLOW_UNFREE=1 nix run --impure nixpkgs#<pkg> -- <args>
```

In Nushell, inline `VAR=x cmd` is not valid syntax — route it through
`^bash -c '…'`. See [local-host.md](local-host.md).

## Never do these

- **`nix-env -i` / `nix-env -iA`** — imperative profile install. Leaves durable
  state outside the host's configuration, survives rebuilds, and is exactly the
  drift this skill exists to prevent.
- **`nix profile install`** — the same problem in the flakes-era CLI.
- **`nix-collect-garbage -d` / `nix profile remove` as "cleanup"** — those act
  on the user's real profile and generations. Not yours to run.

If the tool should persist, it belongs in the host's config
([declarative.md](declarative.md)) or the repo's devShell
([project-env.md](project-env.md)) — never in an imperative profile.

## Related

- Repo needs it repeatedly → `flake.nix` devShell or `shell.nix`:
  [project-env.md](project-env.md)
- User wants it permanently → `environment.systemPackages` / `home.packages`:
  [declarative.md](declarative.md)
- Idiomatic Nix authoring → the `spacecraft-nix-guidelines` skill

## Lookup

- Online: <https://search.nixos.org/packages>
- CLI: `nix search nixpkgs <tool-name>`
- Verify an attribute resolves: `nix eval --raw nixpkgs#<pkg>.name`
- See [lookup.md](lookup.md) for details.

## Cleanup

None required. The store is garbage-collected by the user's own
`nix-collect-garbage` / `nix store gc`. Short-lived `nix run` and `nix-shell`
invocations leave no profile entry behind.
