# SPDX-License-Identifier: GPL-3.0-or-later
{
  description = "Bravais — A Steelbore OS NixOS Distribution";

  inputs = {
    # Core (Stable — 26.05)
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    # Home Manager (Stable)
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Core (Unstable — Rolling)
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home Manager (Unstable)
    home-manager-unstable = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Declarative Flatpak management
    nix-flatpak.url = "github:gmodena/nix-flatpak";

    # Gitway — Spacecraft Software's SSH transport for Git (tracks main)
    gitway.url = "github:Spacecraft-Software/Gitway";
    gitway.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Adit — Spacecraft Software's universal SSH_ASKPASS helper (GUI/TUI/keyring).
    # Replaces ksshaskpass as the askpass backend for gitway-add under Niri and
    # other non-KDE sessions. Currently in PRD stage (no flake.nix yet).
    # To activate once it ships:
    #   1. Uncomment the two lines below.
    #   2. Add `adit` to the outputs arg list and to specialArgs / extraSpecialArgs
    #      (same pattern as gitway per CLAUDE.md constraint #7).
    #   3. Import adit.nixosModules.default in mkBravais and set
    #      programs.ssh.askPassword = "${adit.packages.${system}.default}/bin/adit"
    #      in modules/core/security.nix (replacing the ksshaskpass references).
    # adit.url = "github:Spacecraft-Software/Adit";
    # adit.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Kimi Code CLI — disabled. Re-enable by uncommenting these two lines,
    # restoring `kimi-cli` to the outputs arg list, specialArgs, and
    # extraSpecialArgs, and un-commenting the package line in modules/packages/ai.nix.
    # kimi-cli.url = "github:MoonshotAI/kimi-cli";
    # kimi-cli.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Construct — Spacecraft Software agent skill catalogue (tracks main).
    # Provides homeManagerModules.default which installs skills into
    # ~/.agents/skills/ and symlinks every agent harness to it.
    construct.url = "github:Spacecraft-Software/Construct";
    construct.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # rapg — local-first secret manager for the AI-agent era.
    # Wrapper flake lives at flakes/rapg/flake.nix (upstream has no flake).
    # Populate hashes in flakes/rapg/flake.nix before first build.
    rapg.url = "path:./flakes/rapg";
    rapg.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Antigravity — Google's AI-native IDE. Upstream now ships separate
    # packages (google-antigravity-ide, google-antigravity-cli,
    # google-antigravity-ide-with-cli). editors.nix installs the IDE-only
    # package; the `agy` CLI stays out-of-band (upstream install script).
    antigravity-nix.url = "github:UnbreakableMJ/antigravity-nix";
    antigravity-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # nil — Nix language server (Rust). Fork by UnbreakableMJ; flake outputs
    # are identical to upstream oxalica/nil. Installed system-wide via
    # modules/packages/development.nix and used in the devShell below.
    nil.url = "github:UnbreakableMJ/nil";
    nil.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # mcp-servers — `mcpctl`, which generates each MCP host's config from that
    # repo's mcp.toml and deploys it. A git input rather than a `path:` input:
    # a path input is content-addressed and drifts its NAR hash on every source
    # edit (constraint #10, the reason the five local Rust-app path inputs were
    # dropped). A git input is pinned to a rev instead, so the tree can change
    # freely and only `nix flake update mcp-servers` moves it.
    #
    # `github:` rather than `git+file:///spacecraft-software/mcp-servers`. The
    # local URL resolved on this machine and NOWHERE else: a GitHub runner has
    # no such directory, so `nix flake check` failed with `Git repository
    # "/spacecraft-software/mcp-servers" does not exist` and the flake could not
    # be evaluated by CI, by a fresh clone, or by the Copilot coding agent —
    # which is the whole audience .github/skills/ is vendored for. An input
    # reachable from exactly one filesystem is not a dependency, it is a local
    # detail leaking into a published lock file.
    #
    # Consequence: `github:` sees PUSHED content only — one step further than
    # the committed-only rule this replaced. An mcpctl change must be committed
    # AND pushed before `nix flake update mcp-servers` can pick it up.
    mcp-servers.url = "github:Spacecraft-Software/mcp-servers";
    mcp-servers.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # vacuum — disk-space recovery CLI + TUI, first-party, developed at
    # /spacecraft-software/vacuum. `github:` for exactly the reasons spelled
    # out for mcp-servers above, including the same consequence: a vacuum
    # change must be committed AND pushed before `nix flake update vacuum`
    # can see it. (Capital V — the repo is Spacecraft-Software/Vacuum.)
    #
    # Supplies the binary only. The configuration is already declarative and
    # user-owned: users/mj/apps.nix writes ~/.config/vacuum/config.toml.
    # Vacuum's own `nixosModules.default` (programs.vacuum.enable) is
    # deliberately NOT imported — its entire body is
    # `environment.systemPackages`, which would put the binary in the system
    # profile while the `roots = ["~", …]` that bound its deletions stayed in
    # one user's $HOME. Binary and root-list belong in the same module.
    vacuum.url = "github:Spacecraft-Software/Vacuum";
    vacuum.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # engram — shared verbatim chat memory (CLI + MCP server + HTTP API),
    # first-party, developed at /spacecraft-software/engram. Same `github:`
    # rule and same push-before-update consequence as vacuum and mcp-servers.
    #
    # Load-bearing beyond "a tool on PATH": mcp-servers/mcp.toml registers this
    # server as `command = "engram"` — resolved by BARE NAME on PATH — so
    # whatever this input puts in the user profile is literally what every MCP
    # host spawns. Before this it was a `cargo install` build from an
    # uncommitted working tree.
    engram.url = "github:Spacecraft-Software/Engram";
    engram.inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nixpkgs-unstable,
      home-manager-unstable,
      nix-flatpak,
      gitway,
      construct,
      rapg,
      antigravity-nix,
      nil,
      mcp-servers,
      vacuum,
      engram,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      # nil — Nix language server. Overridden to disable tests due to upstream
      # Nix builtins documentation updates breaking tests, and to replace
      # upstream's own `CFG_DEFAULT_FORMATTER = lib.getExe nixfmt-rfc-style;`
      # (oxalica/nil flake.nix, built from *its own* unoverlaid nixpkgs input)
      # with canonical nixfmt. That line forces the deprecated alias the
      # moment nil's derivation is instantiated — evaluating ANY nixosConfig
      # that installs nil (dry-build, switch, flake check) always printed
      # "nixfmt-rfc-style is now the same as pkgs.nixfmt which should be used
      # instead.", regardless of the nixfmt-rfc-style overlay in
      # modules/core/nix.nix (that overlay only covers our own pkgs
      # instantiation, not nil's separate one). Overriding the attribute here
      # replaces the lazy thunk before it's ever forced, so the original
      # nixfmt-rfc-style reference is dead code and the warning never fires.
      nil = inputs.nil // {
        packages = builtins.mapAttrs (
          sys: pkgs:
          pkgs
          // (builtins.mapAttrs (
            name: pkg:
            if name == "default" || name == "nil" then
              pkg.overrideAttrs (oldAttrs: {
                doCheck = false;
                CFG_DEFAULT_FORMATTER = "${nixpkgs.legacyPackages.${sys}.nixfmt}/bin/nixfmt";
              })
            else
              pkg
          ) pkgs)
        ) inputs.nil.packages;
      };

      # ── Steelbore palette family (Standard §11) ───────────────────────────
      # §11 is a family of seven adoptable palettes, not one palette. Values
      # are read, never retyped (§11.4) — straight from the canonical TOML
      # shipped by the `construct` input, so an upstream palette fix lands
      # with `nix flake update construct`.
      #
      # The active theme is NOT set here — it lives in ./theme.nix so the one
      # word that re-themes the machine is not buried in build machinery.
      # Local themes live in ./themes/<slug>.nix and may shadow a registered
      # palette of the same name.
      defaultPalette = (import ./theme.nix).active;

      # ./themes/*.nix -> { <slug> = <definition>; }. The directory is optional.
      localThemes =
        let
          dir = ./themes;
          entries = if builtins.pathExists dir then builtins.readDir dir else { };
          isTheme = name: type: type == "regular" && nixpkgs.lib.hasSuffix ".nix" name;
          slugOf = name: builtins.substring 0 (builtins.stringLength name - 4) name;
        in
        builtins.listToAttrs (
          map (name: {
            name = slugOf name;
            value = import (dir + "/${name}");
          }) (builtins.attrNames (nixpkgs.lib.filterAttrs isTheme entries))
        );

      mkPalette =
        slug:
        import ./lib/palette.nix {
          tomlFile = "${construct}/steelbore-color-palette/assets/steelbore.toml";
          inherit slug localThemes;
        };

      # Every selectable theme — registered (7 palettes + 7 high-contrast
      # siblings) plus every local one. Drives both the per-theme
      # nixosConfigurations and the registry the `theme` command reads.
      allThemes = (mkPalette defaultPalette).meta.family;

      # ── Theme registry ───────────────────────────────────────────────────
      # Every theme, resolved, as JSON. Two consumers, one definition: the
      # `theme` command reads it via `nix build .#theme-registry` (it
      # evaluates only the palette library, never a system config, so
      # `theme list` is instant where walking nixosConfigurations would take
      # a minute per theme), and modules/theme/declaration.nix installs it at
      # /etc/steelbore/themes.json as the Standard §11.6.4 advisory registry.
      #
      #   nix build --no-link --print-out-paths .#theme-registry
      themeRegistry =
        let
          rp = nixpkgs.legacyPackages.${system};
          basePalette = mkPalette defaultPalette;
          roles = [
            "background"
            "surface"
            "surfaceAlt"
            "foreground"
            "accent"
            "structure"
            "success"
            "error"
            "warning"
            "info"
            "focus"
            "border"
          ];
          entry =
            slug:
            let
              p = mkPalette slug;
            in
            {
              inherit slug;
              source = if localThemes ? ${slug} then "local" else "construct";
              active = slug == defaultPalette;
              hasSurfaceClass = p.meta.hasSurfaceClass;
              # §11.6.2 — canvas polarity and the light/dark counterpart, so a
              # consumer can answer a platform color-scheme preference without
              # reading steelbore.toml itself.
              inherit (p.meta) polarity pair;
              # Hex for display, rgb for truecolor swatches — Nushell's
              # `ansi` builtin takes named colors, not arbitrary hex.
              colors = builtins.listToAttrs (
                map (r: {
                  name = r;
                  value = {
                    hex = p.${r};
                    rgb = p.convert.rgbTriple p.${r};
                    x256 = p.convert.x256.${r};
                  };
                }) roles
              );
            };
        in
        rp.writeText "steelbore-theme-registry.json" (
          builtins.toJSON {
            active = defaultPalette;
            # The pair actually in force, so a reader does not have to look the
            # active slug back up in `themes` to find its counterpart.
            dark = if basePalette.meta.polarity == "dark" then defaultPalette else basePalette.meta.pair;
            light = if basePalette.meta.polarity == "light" then defaultPalette else basePalette.meta.pair;
            standard = "11.6";
            themes = map entry allThemes;
          }
        );

      # ── Default applications ──────────────────────────────────────────────
      # Which program handles what. Same shape as the palette family above and
      # for the same reason: the active choice lives in ./default-apps.nix so
      # the one word that changes your editor is not buried in build
      # machinery, and no consumer ever names an application.
      #
      # Drop-ins live in ./apps/<slug>.nix and may shadow a built-in entry —
      # that is the whole integration cost of an app nixpkgs does not have.
      defaultApps = import ./default-apps.nix;

      # ./apps/*.nix -> { <slug> = <definition>; }. The directory is optional.
      localApps =
        let
          dir = ./apps;
          entries = if builtins.pathExists dir then builtins.readDir dir else { };
          isApp = name: type: type == "regular" && nixpkgs.lib.hasSuffix ".nix" name;
          slugOf = name: builtins.substring 0 (builtins.stringLength name - 4) name;
        in
        builtins.listToAttrs (
          map (name: {
            name = slugOf name;
            value = import (dir + "/${name}");
          }) (builtins.attrNames (nixpkgs.lib.filterAttrs isApp entries))
        );

      steelboreApps = import ./lib/default-apps.nix {
        selection = defaultApps;
        inherit localApps;
      };

      # Primary (single) user of every machine — stated once (elegance plan
      # 3.4) and threaded via specialArgs/extraSpecialArgs. The users/mj/
      # directory name is a stable path, not a duplicate of this fact.
      primaryUser = "mj";

      # ── Dev tooling pkgs ──────────────────────────────────────────────────
      # A nixpkgs instance with the nixfmt-rfc-style alias suppressed, used by
      # the flake formatter and devShell below. The alias fires a
      # `warnOnInstantiate` during any access; the overlay replaces it with a
      # direct pointer so the warning never fires from devShell / formatter
      # evaluation.
      devPkgs = nixpkgs.legacyPackages.${system}.extend (
        _final: prev: {
          nixfmt-rfc-style = prev.nixfmt;
        }
      );

      # ── Channel selector ──────────────────────────────────────────────────
      # Maps a channel name to the correct nixpkgs and home-manager input.
      channels = {
        stable = {
          pkgs = nixpkgs;
          hm = home-manager;
        };
        unstable = {
          pkgs = nixpkgs-unstable;
          hm = home-manager-unstable;
        };
      };

      # ── Machines ───────────────────────────────────────────────────────────
      # One entry per physical machine. Each path is a host module that imports
      # ./hosts/common.nix + its own ./hardware.nix and pins the machine's
      # hostname + steelbore.hardware.* + steelbore.platform.x86_64.marchLevel.
      # Adding a new machine = drop a hosts/<machine>/ dir here + two output
      # lines below.
      hosts = {
        thinkpad = ./hosts/thinkpad; # Intel i7-8665U (Whiskey Lake) — x86-64-v3
      };

      # ── mkBravais ────────────────────────────────────────────────────────
      # Build a Bravais NixOS configuration for a given machine and channel.
      # The x86-64 march level is pinned inside each machine's host config
      # (steelbore.platform.x86_64.marchLevel), not here.
      #
      # Usage:  nixos-rebuild switch --flake .#bravais-thinkpad
      #         nixos-rebuild switch --flake .#bravais-thinkpad-unstable
      #
      #   host    — a machine path from `hosts` above
      #   channel — "stable" (26.05) or "unstable" (rolling)
      #   palette — a Steelbore palette slug (see `defaultPalette` above).
      #             Per-machine override; the family default covers every
      #             machine that does not ask for something else.
      mkBravais =
        {
          host,
          channel ? "stable",
          palette ? defaultPalette,
        }:
        let
          ch = channels.${channel};
          steelborePalette = mkPalette palette;
          # Always-unstable nixpkgs instantiation, threaded into modules
          # via specialArgs. Used for claude-code so even stable variants
          # ship the latest claude-code from nixpkgs-unstable instead of
          # the (often older) channel-stable build. Re-instantiated with
          # config so unfree licenses (claude-code is unfree) are accepted
          # — `nixpkgs.config.allowUnfree` only covers the channel pkgs,
          # not this separate evaluation.
          unstablePkgs = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
            overlays = [
              (_final: prev: {
                nixfmt-rfc-style = prev.nixfmt;
              })
            ];
          };
        in
        ch.pkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              steelborePalette
              themeRegistry
              steelboreApps
              primaryUser
              gitway
              construct
              rapg
              unstablePkgs
              antigravity-nix
              nil
              mcp-servers
              ;
          };
          modules = [
            # External modules
            ch.hm.nixosModules.home-manager
            nix-flatpak.nixosModules.nix-flatpak
            gitway.nixosModules.default

            # Bravais modules
            host
            ./modules/core
            ./modules/theme
            ./modules/hardware
            ./modules/platform
            ./modules/desktops
            ./modules/login
            ./modules/services
            ./modules/compat
            ./modules/packages

            # System user account (mj) — single source of truth. Home Manager
            # session config lives in users/mj/home.nix (wired below).
            ./users/mj/default.nix

            # Home Manager integration (march level is pinned per-machine in
            # the host config, not here).
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = {
                inherit
                  steelborePalette
                  steelboreApps
                  primaryUser
                  gitway
                  construct
                  rapg
                  unstablePkgs
                  antigravity-nix
                  nil
                  mcp-servers
                  vacuum
                  engram
                  ;
              };
              home-manager.users.${primaryUser} = import ./users/mj/home.nix;
            }
          ];
        };

    in
    {
      nixosConfigurations = {
        # ── ThinkPad (Intel i7-8665U — x86-64-v3, pinned in hosts/thinkpad) ──
        bravais-thinkpad = mkBravais { host = hosts.thinkpad; };
        bravais-thinkpad-unstable = mkBravais {
          host = hosts.thinkpad;
          channel = "unstable";
        };

        # Convenience alias: bare `.#bravais` → the stable ThinkPad build.
        # Points at the attribute rather than calling mkBravais again: an
        # identical second call is a full duplicate evaluation, and
        # `nix flake check` walks every nixosConfigurations entry.
        bravais = self.nixosConfigurations.bravais-thinkpad;
      };

      # ── Per-theme systems (`theme try`) ───────────────────────────────────
      # A buildable system per selectable theme, so any theme can be applied
      # without editing theme.nix.
      #
      # Deliberately NOT in `nixosConfigurations`: `nix flake check` force-
      # evaluates every entry there, and a full system costs ~1.9 GB for the
      # first plus ~1.3 GB for each additional one held in the same evaluator.
      # Fifteen variants needed ~23 GB and were OOM-killed on this 31 GB
      # machine. As a non-standard output these stay lazy — `nix flake check`
      # skips them with a warning, and you pay only for the theme you build.
      #
      #   theme try tokyonight
      #   nix build .#themeSystems.x86_64-linux.tokyonight
      themeSystems.${system} = builtins.listToAttrs (
        map (slug: {
          name = slug;
          value =
            (mkBravais {
              host = hosts.thinkpad;
              palette = slug;
            }).config.system.build.toplevel;
        }) allThemes
      );

      # ── In-tree packages (elegance plan 3.2) ─────────────────────────────
      # Same index the modules consume (pkgs/default.nix), exposed so each
      # vendored/first-party package can be built and tested standalone:
      #   nix build .#claude-desktop
      # Instantiated with allowUnfree (claude-desktop and chrome-remote-
      # desktop are unfree; legacyPackages carries no config).
      packages.${system} =
        (import ./pkgs {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        })
        // {
          # ── Theme registry ─────────────────────────────────────────────────
          # Defined in the outer `let` because modules/theme/declaration.nix
          # installs the same derivation at /etc/steelbore/themes.json (§11.6.4).
          theme-registry = themeRegistry;

          # ── Default-application registry ───────────────────────────────────
          # Every handler role and every registered app, as JSON. What the
          # `app` command reads. `steelboreApps.registry` is deliberately
          # pkgs-free — the `package` / `exec` / `dbusExec` fields are
          # functions of pkgs and never reach here — so `app list` costs an
          # evaluation of one builtins-only library, not of a system config.
          #
          #   nix build --no-link --print-out-paths .#app-registry
          app-registry = nixpkgs.legacyPackages.${system}.writeText "steelbore-app-registry.json" (
            builtins.toJSON steelboreApps.registry
          );
        };

      # ── Developer tooling ────────────────────────────────────────────────
      # Quality-of-life outputs for `nix fmt`, `nix develop`, `nix flake check`.
      # Uses devPkgs (nixpkgs + nixfmt-rfc-style overlay) so the deprecation
      # alias warning never fires from devShell / formatter evaluation.
      formatter.${system} = devPkgs.nixfmt;

      devShells.${system}.default = devPkgs.mkShell {
        packages = [
          nil.packages.${system}.default # Nix language server (from flake input)
          devPkgs.nixfmt # Nix formatter (RFC-style; canonical attr)
          devPkgs.statix # Nix linter / antipattern checker
          devPkgs.deadnix # dead-code (unused binding) finder
        ];
      };

      # `nix flake check` evaluates *and* builds both real machine configs
      # (stable + unstable). The x86-64 march level is pinned per host, so
      # there is no v1–v4 matrix to enumerate here.
      checks.${system} = {
        bravais-thinkpad = self.nixosConfigurations.bravais-thinkpad.config.system.build.toplevel;
        bravais-thinkpad-unstable =
          self.nixosConfigurations.bravais-thinkpad-unstable.config.system.build.toplevel;

        # Niri config validation (elegance plan 5.5): the user config.kdl is a
        # generated string Nix cannot type-check; run niri's own parser over
        # the rendered file so a KDL/action-name error fails `nix flake check`
        # instead of surfacing at session start.
        niri-config =
          let
            checkPkgs = nixpkgs.legacyPackages.${system};
            rendered =
              self.nixosConfigurations.bravais-thinkpad.config.home-manager.users.${primaryUser}.xdg.configFile."niri/config.kdl".source;
          in
          checkPkgs.runCommand "niri-config-validate" { } ''
            ${checkPkgs.niri}/bin/niri validate -c ${rendered}
            touch $out
          '';

        # REUSE / SPDX compliance (elegance plan 4.6, Standard §4.3). The
        # flake source copy contains exactly the tracked files, so linting it
        # matches linting the checkout.
        reuse-lint =
          let
            checkPkgs = nixpkgs.legacyPackages.${system};
          in
          checkPkgs.runCommand "reuse-lint" { } ''
            ${checkPkgs.reuse}/bin/reuse --root ${self} lint
            touch $out
          '';
      };
    };
}
