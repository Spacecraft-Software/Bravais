# Band C — Declarative installs (the right way to make a tool permanent)

When a tool should stay on the user's machine, the correct home for it is the
machine's **own configuration**, not an imperative install. A declaratively
managed host reconstructs its package set from that config on every rebuild; a
tool installed around the config is invisible to it, survives as drift, and
confuses whoever reads the config next.

**The agent proposes the edit. The user applies it.** Never run the rebuild.

---

## Step 1 — Identify which manager governs the host

| Host | Signals | Config lives in |
|---|---|---|
| **NixOS** | `nixos-rebuild` on `PATH`, `/etc/os-release` says `ID=nixos`, `/etc/nixos/` exists | `/etc/nixos/` (often a flake) |
| **Home Manager** | `~/.config/home-manager/`, a flake with `homeConfigurations`, `~/.nix-profile` managed by HM | `home.nix` / an HM module |
| **nix-darwin** | `darwin-rebuild` on `PATH`, macOS | `~/.config/nix-darwin/` or a flake |
| **Guix System / Guix Home** | `guix` on `PATH`, `/run/current-system` is a Guix system | `~/.config/guix/manifest.scm`, home config `.scm` |
| **macOS + Homebrew** | `brew` present, no Nix/Guix config | `Brewfile` |
| **None** | none of the above | → fall back to Band B (see the per-manager references) |

`home-manager` is frequently **not** on `PATH` even when Home Manager manages
the user — it is commonly imported as a NixOS or nix-darwin module rather than
installed standalone. Look for the config tree before concluding it is absent.

Locate the real file before proposing anything. Do not assume `/etc/nixos` —
the host may keep its config in a git repo elsewhere, with `/etc/nixos` as a
symlink or a thin entry point. `nixos-rebuild --flake` invocations, the value
of `nixpkgs.flake` inputs, and the maintainer's own `CLAUDE.md`/`AGENTS.md` are
better evidence than a guess.

---

## Step 2 — Propose a minimal diff

Name the exact attribute path and show only the lines that change.

### NixOS — system-wide

```nix
# /etc/nixos/configuration.nix   (or the module that owns systemPackages)
environment.systemPackages = with pkgs; [
  # …existing entries…
  hyperfine        # ← added
];
```

Applied by the user with:

```sh
sudo nixos-rebuild switch          # or: sudo nixos-rebuild switch --flake /etc/nixos#<host>
```

### Home Manager — user-scoped (prefer this for developer tools)

```nix
# home.nix / the HM module that owns home.packages
home.packages = with pkgs; [
  # …existing entries…
  hyperfine        # ← added
];
```

```sh
home-manager switch                # or: home-manager switch --flake ~/.config/home-manager#<user>
```

When Home Manager is imported as a NixOS module, there is no standalone
`home-manager` command — the edit is applied by the *system* rebuild instead:

```sh
sudo nixos-rebuild switch
```

Check which shape the host uses before naming a command.

### nix-darwin

```nix
environment.systemPackages = with pkgs; [ hyperfine ];
```

```sh
darwin-rebuild switch --flake ~/.config/nix-darwin
```

### Guix Home / Guix System

```scheme
;; ~/.config/guix/manifest.scm
(specifications->manifest
  '("ripgrep"
    "hyperfine"))          ; ← added
```

```sh
guix home reconfigure ~/.config/guix/home-configuration.scm
# or, for a bare manifest profile:
guix package -m ~/.config/guix/manifest.scm
```

### macOS + Homebrew (no Nix/Guix)

```ruby
# Brewfile
brew "hyperfine"
```

```sh
brew bundle --file=~/Brewfile
```

---

## Step 3 — Unblock the immediate task anyway

A proposed edit does nothing until the user rebuilds, and the rebuild is not
yours to run. So **pair every Band C proposal with a Band A invocation** that
satisfies the current need right now:

> I've added `hyperfine` to `home.packages` in `home.nix` — run
> `home-manager switch` when you're ready. In the meantime:
> `nix run nixpkgs#hyperfine -- 'cmd_a' 'cmd_b'`

---

## Package names

Declarative attributes use the same names as the corresponding ephemeral
manager — `nixpkgs` attribute paths for Nix hosts, Guix package names for Guix
hosts — so the lookups in [lookup.md](lookup.md) apply unchanged. Dotted
nixpkgs paths (`python3Packages.requests`, `nodePackages.prettier`) are written
out in full inside the list.

Verify the attribute resolves before proposing it:

```sh
nix eval --raw nixpkgs#hyperfine.name        # errors if the attribute is wrong
guix show hyperfine                          # errors if unpackaged
```

---

## Never do these

- **`nix-env -i`, `nix profile install`, `guix install`** — imperative profile
  installs on a declaratively managed host. They shadow the config, survive
  rebuilds, and are exactly the drift this band exists to prevent.
- **Running the rebuild** — `nixos-rebuild`, `home-manager switch`,
  `darwin-rebuild`, `guix home reconfigure` are the user's commands. They can
  take minutes, may need `sudo`, and can change the running system.
- **Editing a config you have not read.** Read the file, match its existing
  style (`with pkgs;` vs fully qualified, one-per-line vs inline), and keep the
  diff minimal.
- **Adding to system scope when user scope will do.** A developer tool belongs
  in `home.packages`, not `environment.systemPackages`.

---

## Cleanup

Removing the line and rebuilding removes the tool completely — that is the
point of this band. There is no separate uninstall command to remember, and
nothing is left behind in a profile.
