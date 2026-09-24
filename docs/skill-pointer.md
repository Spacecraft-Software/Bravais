# The skill pointer (no rebuild, no sudo)

The long form of the skill-pointer invariants in `AGENTS.md`: the link
layout, the commands that move it, and why each rule exists. Read it before
changing `skills-sync`, the Construct Home Manager wiring, or the
`constructSkills` binding in `flake.nix`.

`~/.agents/skills` is **not** a store path. It is a symlink to
`~/.local/state/construct/current`, and the layout is:

```
~/.local/state/construct/pinned   -> /nix/store/…-construct-skills   # home.file; GC-rooted by the HM generation
~/.local/state/construct/built    -> /nix/store/…-construct-skills   # `nix build --out-link`; GC-rooted by its own auto root
~/.local/state/construct/current  -> …/pinned  (tracking the lock)  or  …/built  (moved ahead)
~/.agents/skills                  -> ~/.local/state/construct/current
~/.<agent>/skills  (×9)           -> ~/.agents/skills
```

| Command | Effect |
|---------|--------|
| `skills-sync` | `nix flake update construct`, build `.#skills` at the **new lock**, move `current` — skills live in seconds |
| `skills-status` | Is the live tree the flake-pinned one? |
| `skills-reset` | Discard a moved pointer, back to the lock |
| `rebuild --skills-only` | Full switch, but only bumps `construct`; skips GC, the `/etc/nixos` mirror and the mcpctl probe |

Two rules that are not obvious and are easy to break:

1. **`current` only ever points at `pinned` or at `built`.** Never `ln -s` it at
   a bare `/nix/store/…` path: that shape has no GC root, and the next
   `nix-collect-garbage` deletes the skill tree out from under every agent on
   the machine. Both legal targets are rooted — `pinned` via the HM generation,
   `built` via the indirect root `--out-link` registers under
   `/nix/var/nix/gcroots/auto/`.

   `built` is why the pointer is a three-link layout rather than two: `nix build
   --out-link` **refuses** to replace a link whose current target is outside the
   store, and `current -> pinned` is exactly that after every rebuild. Building
   onto a dedicated link sidesteps the refusal, and lets `current` be swapped by
   an atomic rename so it is never momentarily dangling.
2. **Every activation re-points `current` at `pinned`,** so `flake.lock` stays
   authoritative and the pointer only runs ahead *between* rebuilds. Making the
   seed conditional (`if [ ! -L current ]`) looks kinder but is a trap: a later
   rebuild bumps `pinned` while `current` stays behind, and the machine silently
   runs stale skills.

`skill sync --build` builds **this flake's** `skills` output at the **locked**
rev — not `github:…/Construct#skills` at HEAD. Standalone would resolve
Construct's own locked nixpkgs (unrealised here: a tarball fetch plus a full
nixpkgs instantiation ahead of a ~3 MB copy), and building HEAD would let the
live tree diverge from the lock-derived vendored copy in `.github/skills/`
without any signal.

`flake.nix` binds `constructSkills` once and hands the **same derivation** to
both `packages.skills` and `spacecraft.construct.package`. That is load-bearing,
not tidiness — `construct` pins its own nixpkgs, this flake overrides it with
`follows`, and HM runs under `useGlobalPkgs` with overlays, so letting each side
build its own yields different store paths for a byte-identical tree and any
pinned-vs-live comparison reports drift forever.

Grok is the exception: `~/.grok/skills` is still a plain store link and still
needs a rebuild. It holds one skill, so the asymmetry is cosmetic.

Agents cache skills at session start — a sync mid-session is invisible until the
harness restarts.
