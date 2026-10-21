# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Core Module Entry Point
{
  imports = [
    ./boot.nix
    ./memory.nix
    ./nix.nix
    ./nix-tmp.nix
    ./locale.nix
    ./audio.nix
    ./security.nix
    ./keyring.nix
    ./dns.nix
    ./reticle.nix # mouse on the TTYs (pkgs/steelbore-reticle)
    ./console-font.nix # Terminus 24 on the TTYs, re-applied per VT (#52)
    ./identity.nix # Steelbore OS os-release / lsb-release (lib/identity.nix)
  ];
}
