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
  ];
}
