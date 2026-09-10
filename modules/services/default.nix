# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Services (opt-in system services)
{
  imports = [
    ./adguardvpn.nix
    ./chrome-remote-desktop.nix
    ./ollama.nix
    ./podman.nix
    ./waydroid.nix
  ];
}
