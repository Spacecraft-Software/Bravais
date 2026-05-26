# SPDX-License-Identifier: GPL-3.0-or-later
{
  description = "Bravais — A Steelbore OS NixOS Distribution";

  inputs = {
    # Core (Stable — 25.11)
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # Home Manager (Stable)
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
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

    # Kimi Code CLI — Moonshot's terminal coding agent (Python). Upstream
    # ships a flake with packages.${system}.default = `kimi`. Threaded the
    # same way as gitway (specialArgs + extraSpecialArgs) per CLAUDE.md
    # constraint #7, not as an overlay.
    kimi-cli.url = "github:MoonshotAI/kimi-cli";
    kimi-cli.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Antigravity 2 — UnbreakableMJ's app (tracks main)
    antigravity-nix.url = "github:UnbreakableMJ/antigravity-nix";
    antigravity-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Construct — Spacecraft Software agent skill catalogue (tracks main).
    # Provides homeManagerModules.default which installs skills into
    # ~/.agents/skills/ and symlinks every agent harness to it.
    construct.url = "github:Spacecraft-Software/Construct";
    construct.inputs.nixpkgs.follows = "nixpkgs-unstable";
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
      kimi-cli,
      antigravity-nix,
      construct,
      ...
    }:
    let
      system = "x86_64-linux";

      # Steelbore color palette as a reusable attribute set
      steelborePalette = {
        voidNavy    = "#000027";
        moltenAmber = "#D98E32";
        steelBlue   = "#4B7EB0";
        radiumGreen = "#50FA7B";
        redOxide    = "#FF5C5C";
        liquidCool  = "#8BE9FD";
      };

      # ── Channel selector ──────────────────────────────────────────────────
      # Maps a channel name to the correct nixpkgs and home-manager input.
      channels = {
        stable   = { pkgs = nixpkgs;          hm = home-manager; };
        unstable = { pkgs = nixpkgs-unstable; hm = home-manager-unstable; };
      };

      # ── mkBravais ────────────────────────────────────────────────────────
      # Build a Bravais NixOS configuration for a given x86-64 march level
      # and nixpkgs channel.
      #
      # Usage:  nixos-rebuild switch --flake .#bravais-v3
      #         nixos-rebuild switch --flake .#bravais-unstable-v3
      #
      #   channel — "stable" (25.11) or "unstable" (rolling)
      #   v1 — baseline x86-64 (SSE2)        broadest compatibility
      #   v2 — SSE4.2 / POPCNT / CX16        ~2008+ CPUs
      #   v3 — AVX2 / BMI1/2 / FMA / MOVBE   ~2013+ CPUs (CachyOS default)
      #   v4 — AVX-512F/BW/CD/DQ/VL          Ice Lake+ / Zen 4+
      mkBravais =
        { marchLevel
        , channel ? "stable"
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
          specialArgs = { inherit steelborePalette gitway kimi-cli antigravity-nix construct unstablePkgs; };
          modules = [
            # External modules
            ch.hm.nixosModules.home-manager
            nix-flatpak.nixosModules.nix-flatpak
            gitway.nixosModules.default

            # Bravais modules
            ./hosts/bravais
            ./modules/core
            ./modules/theme
            ./modules/hardware
            ./modules/desktops
            ./modules/login
            ./modules/packages

            # Profile + Home Manager integration
            {
              steelbore.hardware.intel.marchLevel = marchLevel;

              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = { inherit steelborePalette gitway kimi-cli antigravity-nix construct unstablePkgs; };
              home-manager.users.mj = import ./users/mj/home.nix;
            }
          ];
        };

    in
    {
      nixosConfigurations = {
        # ── Stable (nixos-25.11) ────────────────────────────────────────────
        # Default — AVX-512 (same as bravais-v4)
        bravais    = mkBravais { marchLevel = "v4"; };

        # Explicit stable profiles
        bravais-v1 = mkBravais { marchLevel = "v1"; };   # baseline x86-64    (SSE2)
        bravais-v2 = mkBravais { marchLevel = "v2"; };   # x86-64-v2          (SSE4.2)
        bravais-v3 = mkBravais { marchLevel = "v3"; };   # x86-64-v3  AVX2    (CachyOS default)
        bravais-v4 = mkBravais { marchLevel = "v4"; };   # x86-64-v4  AVX-512 (Bravais default)

        # ── Unstable (nixos-unstable) ───────────────────────────────────────
        # Default unstable — AVX-512 (same as bravais-unstable-v4)
        bravais-unstable    = mkBravais { marchLevel = "v4"; channel = "unstable"; };

        # Explicit unstable profiles
        bravais-unstable-v1 = mkBravais { marchLevel = "v1"; channel = "unstable"; };
        bravais-unstable-v2 = mkBravais { marchLevel = "v2"; channel = "unstable"; };
        bravais-unstable-v3 = mkBravais { marchLevel = "v3"; channel = "unstable"; };
        bravais-unstable-v4 = mkBravais { marchLevel = "v4"; channel = "unstable"; };
      };
    };
}
