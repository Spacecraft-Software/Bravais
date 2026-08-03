# One-shot runners (`npx` / `uvx` / `pipx run`) — ephemeral, ecosystem-scoped

Band A, tier 3. These run a package **once** without a permanent install: the
payload lands in a throwaway cache, the command executes, and nothing is added
to `PATH`. They sit below Guix/Nix (which are general-purpose and reproducible)
but **above every Band B install** — when the tool you need is a Node or Python
package, prefer a one-shot runner over `cargo install` / `brew install` / a
Flatpak / an AppImage / a snap. **Run freely; no consent needed.**

**Always pass the non-interactive flag.** The agent's shell has no TTY, so an
uncached `npx <pkg>` hangs on its "Ok to proceed? (y)" prompt — use
`npx --yes`.

Scope is the language ecosystem, the way Cargo is scoped to Rust crates:

| Runner       | Ecosystem        | Provides the tool from |
|--------------|------------------|------------------------|
| `npx`        | Node / npm       | the npm registry       |
| `uvx`        | Python (via uv)  | PyPI (preferred)       |
| `pipx run`   | Python (via pipx)| PyPI (when uv absent)  |
| `pnpm dlx`   | Node / pnpm      | the npm registry       |
| `bunx`       | Node / Bun       | the npm registry       |

## Syntax

```bash
# Node / npm — run a CLI published to npm, once
npx <pkg> [<args>]
npx <pkg>@<version> [<args>]      # pin a version
npx --yes <pkg> [<args>]          # skip the install-confirmation prompt (non-interactive)
pnpm dlx <pkg> [<args>]           # pnpm's equivalent (use in pnpm projects)
bunx <pkg> [<args>]               # Bun's equivalent (fastest start-up; needs bun)

# Python — run a console-script package, once
uvx <pkg> [<args>]                # uv's runner (fast; preferred)
uvx --from <pkg> <command> [...]  # when the command name differs from the package
pipx run <pkg> [<args>]           # pipx equivalent when uv is not installed
```

### Key notes

- **Nothing is installed.** `npx` caches under `~/.npm/_npx`, `uvx` under uv's
  tool cache — both are disposable caches, not installs. There is no `PATH`
  entry to remove afterward; at most you can clear the cache (`npm cache clean
  --force`, `uv cache clean`).
- **Binary vs package name can differ.** `uvx --from <pkg> <command>` handles the
  case where the executable isn't named after the distribution. For npm,
  `npx <pkg>` runs the package's default bin.
- **Non-interactive contexts** (agents, CI): pass `npx --yes` so a
  not-yet-cached package doesn't block on the install prompt.
- **One-shot, not a daemon.** These are for run-and-exit tools (linters,
  formatters, scaffolders, generators). For something you'll invoke repeatedly
  in a long session, a Guix/Nix shell that stays open is cheaper than
  re-resolving the package each call.

## Bootstrapping the runtime ephemerally

A one-shot runner still needs its runtime (`node` / `uv`). When that runtime is
itself missing, **do not** drop to a permanent install to get it — provide it
ephemerally from Band A tier 1–2 and keep the whole operation stateless:

```bash
# Node absent → borrow it from Guix or Nix for the duration of the command
guix shell node -- npx --yes <pkg> [<args>]
nix-shell -p nodejs --run "npx --yes <pkg> [<args>]"

# uv absent → same pattern
guix shell uv   -- uvx <pkg> [<args>]
nix-shell -p uv  --run "uvx <pkg> [<args>]"
```

## Lookup

- npm: <https://www.npmjs.com/> — direct page `https://www.npmjs.com/package/<n>`
- PyPI: <https://pypi.org/> — direct page `https://pypi.org/project/<n>/`

Verify the package exists and exposes a CLI/console-script **before** invoking;
if the lookup returns nothing, move down to Band B. See
[lookup.md](lookup.md).

## Persisting the tool

If the same repo reaches for the same npm/PyPI tool on every run, put it in the
project's own manifest rather than re-resolving it each call — a
`devDependencies` entry plus an npm script, or a `pyproject.toml` dev group —
or list it in the repo's devShell ([project-env.md](project-env.md)). If the
user wants it machine-wide, propose a declarative entry
([declarative.md](declarative.md)); nixpkgs carries most popular npm and PyPI
CLIs. Never `npm install -g` or `pip install` outside a venv.

## Cleanup

None required — there is no install. The caches belong to the user; clearing
them is their call, not a cleanup step you owe them:

```bash
npm cache clean --force      # npx cache
uv cache clean               # uvx cache
```
