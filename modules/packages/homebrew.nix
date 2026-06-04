# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Homebrew (Linuxbrew) via a distrobox container
#
# Homebrew is the 4th-priority package source in the spacecraft-missing-pkg
# skill (Guix → Nix → Cargo → Homebrew → Flatpak → Snap). It is an *escape
# hatch* for software that has no Nix/Guix/Cargo packaging, not a primary
# package manager on this host. Keep it disabled unless you actually need it.
#
# Why distrobox (not an FHS sandbox): Homebrew on Linux ("Linuxbrew") expects a
# standard FHS layout, a working system compiler, and a real /home/linuxbrew
# prefix. A `buildFHSEnv` wrapper can provide that, but binaries installed *by*
# brew then link against the sandbox and only run inside it. Running brew inside
# a distrobox container instead makes it behave exactly as upstream intends:
# full FHS, a real apt-managed userland, passwordless sudo inside the box, and
# brew-installed tools that run normally (via `brew-box`). This host already
# ships distrobox + boxbuddy + rootless podman via modules/packages/system.nix.
#
# Dependency: distrobox drives the host's rootless podman, configured by the
# `system` bundle (virtualisation.podman.enable). The host enables both
# packages.system and packages.homebrew, so the coupling is always satisfied —
# but it is called out here so the dependency is explicit.
{ config, lib, pkgs, ... }:

let
  cfg = config.steelbore.packages.homebrew;

  # Container identity. Ubuntu toolbox is the best-tested Homebrew-on-Linux
  # base; swap the image here if you prefer Fedora/Debian.
  box = "brew";
  image = "quay.io/toolbx-images/ubuntu-toolbox:24.04";

  # `brew-box-init` — explicit ONE-TIME setup (pulls the image, apt-installs
  # brew's documented Linux deps, then runs the Homebrew installer). Kept
  # separate from `brew` so the first `brew` call is not a surprise multi-minute
  # image-pull + install. Idempotent: re-running only (re)bootstraps brew.
  brewBoxInit = pkgs.writeShellApplication {
    name = "brew-box-init";
    # podman: distrobox's backend, and the parse-stable source of truth for the
    # box-exists check (a distrobox container *is* a podman container named
    # exactly `${box}`) — far more robust than scraping `distrobox list`.
    runtimeInputs = [ pkgs.distrobox pkgs.podman ];
    # SC2016: the single-quoted inner script is intentional — $(...) and the
    # installer must expand *inside* the container, not on the host.
    excludeShellChecks = [ "SC2016" ];
    text = ''
      if ! podman ps -a --format '{{.Names}}' | grep -qx "${box}"; then
        echo "Creating distrobox container '${box}' from ${image} ..."
        distrobox create --name "${box}" --image "${image}" --yes
      else
        echo "Container '${box}' already exists; (re)bootstrapping Homebrew ..."
      fi
      # distrobox grants passwordless sudo inside the box, so apt needs no
      # host-side privilege. NONINTERACTIVE skips the installer's prompt.
      distrobox enter "${box}" -- bash -c '
        set -euo pipefail
        sudo apt-get update
        sudo apt-get install -y build-essential procps curl file git
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      '
      echo "Done. Use 'brew <args>' or enter the box with 'brew-box'."
    '';
  };

  # `brew` — run brew from the normal (Nushell) shell. Proxies into the box and
  # sources brew's shellenv first. The trailing `brew "$@"` passes args cleanly
  # via bash's positional parameters (no nested quoting games).
  brewWrapper = pkgs.writeShellApplication {
    name = "brew";
    runtimeInputs = [ pkgs.distrobox pkgs.podman ];
    # SC2016: the single-quoted inner script is intentional — `$@` and shellenv
    # must expand *inside* the container, not on the host.
    excludeShellChecks = [ "SC2016" ];
    text = ''
      if ! podman ps -a --format '{{.Names}}' | grep -qx "${box}"; then
        echo "Homebrew container '${box}' does not exist yet." >&2
        echo "Run 'brew-box-init' once to create it and install Homebrew." >&2
        exit 1
      fi
      exec distrobox enter "${box}" -- bash -lc \
        'if [ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
           echo "Homebrew is not installed in the box; run brew-box-init." >&2
           exit 1
         fi
         eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
         brew "$@"' brew "$@"
    '';
  };

  # `brew-box` — interactive shell inside the container (for poking around or
  # running brew-installed tools, which run normally in here).
  brewBox = pkgs.writeShellApplication {
    name = "brew-box";
    runtimeInputs = [ pkgs.distrobox pkgs.podman ];
    text = ''
      exec distrobox enter "${box}"
    '';
  };
in
{
  options.steelbore.packages.homebrew = {
    enable = lib.mkEnableOption "Homebrew (Linuxbrew) via a distrobox container";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      brewBoxInit  # `brew-box-init` — one-time: create box + install Homebrew
      brewWrapper  # `brew`          — run brew from the normal shell
      brewBox      # `brew-box`      — interactive shell inside the container
    ];
  };
}
