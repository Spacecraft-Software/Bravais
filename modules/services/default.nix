# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Services (opt-in system services)
{
  imports = [
    ./chrome-remote-desktop.nix
    ./ollama.nix
    ./podman.nix
  ];
}
