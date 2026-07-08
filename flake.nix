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
      ...
    }:
    let
      system = "x86_64-linux";

      # Steelbore color palette — single canonical source in lib/colors.nix.
      steelborePalette = import ./lib/colors.nix;

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
      devPkgs = nixpkgs.legacyPackages.${system}.extend (_final: prev: {
        nixfmt-rfc-style = prev.nixfmt;
      });

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
      mkBravais =
        {
          host,
          channel ? "stable",
        }:
        let
          ch = channels.${channel};
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
          };
        in
        ch.pkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              steelborePalette
              primaryUser
              gitway
              construct
              rapg
              unstablePkgs
              antigravity-nix
              nil
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
                  primaryUser
                  gitway
                  construct
                  rapg
                  unstablePkgs
                  antigravity-nix
                  nil
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
        bravais = mkBravais { host = hosts.thinkpad; };
      };

      # ── In-tree packages (elegance plan 3.2) ─────────────────────────────
      # Same index the modules consume (pkgs/default.nix), exposed so each
      # vendored/first-party package can be built and tested standalone:
      #   nix build .#claude-desktop
      # Instantiated with allowUnfree (claude-desktop and chrome-remote-
      # desktop are unfree; legacyPackages carries no config).
      packages.${system} = import ./pkgs {
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
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
