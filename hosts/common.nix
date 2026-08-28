# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Common Host Configuration
#
# Machine-agnostic host config shared by every machine under hosts/<machine>/.
# Each machine imports this plus its own ./hardware.nix and sets the bits that
# are genuinely per-machine: networking.hostName and the steelbore.hardware.*
# toggles (fingerprint, intel + marchLevel). Everything below applies to all
# Bravais machines.
{
  pkgs,
  ...
}:

{
  networking.networkmanager.enable = true;

  # X11 (for LeftWM)
  services.xserver.enable = true;
  # Touchpad — natural (reverse) scrolling on X11 sessions (LeftWM, Plasma X11).
  # Niri sets its own equivalent in its config.kdl.
  services.libinput.touchpad.naturalScrolling = true;
  services.xserver.xkb = {
    layout = "us,ara";
    options = "grp:ctrl_space_toggle";
  };

  # ckbcomp can't resolve multi-layout XKB configs; keep console on US
  console.keyMap = "us";

  # Printing
  services.printing.enable = true;

  # User account `mj` is defined once in users/mj/default.nix (imported in
  # flake.nix's module list), not here — avoids a duplicate/drifting definition.

  # Root shell — Brush (Rust, Bash-compatible)
  users.users.root.shell = pkgs.brush;

  # Register shells as valid login shells
  # Ion kept as available; bash is present in NixOS internals but not a user shell
  environment.shells = [
    pkgs.nushell
    pkgs.brush
    pkgs.ion
  ];
  # Note: programs.bash.enable is intentionally left at its default (true) because
  # NixOS activation scripts and PAM tooling (userdel, useradd, etc.) depend on the
  # bash module being active. Bash is excluded from user shells via shell= and
  # environment.shells — no user or root has bash as their login shell.

  # Steelbore module toggles (software set shared across machines; a machine
  # MAY override individual toggles in its own default.nix).
  steelbore = {
    # Desktop environments
    desktops.gnome.enable = true;
    desktops.cosmic.enable = true; # stable pkgs (nixos-26.05)
    desktops.plasma.enable = true;
    desktops.niri.enable = true;
    desktops.niriUnmax.enable = true; # revert Chrome-style post-open self-maximize
    desktops.leftwm.enable = true;
    desktops.mouseWorkspaceNav.enable = true; # side buttons to workspace left/right (see modules/desktops/mouse-workspace-nav.nix)

    # Package bundles
    packages.browsers.enable = true;
    packages.terminals.enable = true;
    packages.editors.enable = true;
    packages.development.enable = true;
    packages.security.enable = true;
    packages.networking.enable = true;
    packages.multimedia.enable = true;
    packages.productivity.enable = true;
    packages.system.enable = true;
    packages.ai.enable = true;
    packages.games.enable = true; # source ports + DOSBox; game data lives in ~/Games (see modules/packages/games.nix)
    packages.games.steam.enable = true; # pulls the 32-bit graphics stack — separate toggle on purpose
    packages.orca.enable = true; # AT-SPI stack for Orca computer-use (see modules/packages/orca.nix)
    packages.flatpak.enable = true;
    packages.homebrew.enable = true; # Linuxbrew via FHS env (escape hatch; see modules/packages/homebrew.nix)

    # DOS games. Adding one is a single entry here: it becomes a `play-<slug>`
    # command and a launcher entry.
    #
    # `package` is the ONLY thing that differs between the two kinds of entry,
    # and the difference is legal, not technical. Set it when the rightsholder
    # has granted redistribution and Nix can therefore fetch the game (seeded
    # into ~/Games/dos/<dir> on first run). Omit it otherwise: the wrapper is
    # still generated, and tells you which file it wants and where, but you put
    # the files there from your own copy.
    #
    # DO NOT add a `package` to an entry below without first reading that
    # game's own licence terms. Shareware episodes are usually redistributable
    # and full versions usually are not, and the two ship the same filenames.
    #
    # `exe` varies between releases of the same game (a GOG re-release, a
    # shareware episode and a CD version often disagree). If a wrapper reports
    # the executable missing, `ls ~/Games/dos/<dir>` and correct it here.
    packages.games.dosGames = [
      {
        slug = "skyroads";
        name = "SkyRoads";
        exe = "SKYROADS.EXE";
        dir = "skyroads";
        comment = "1993 space-racing game (Bluemoon Interactive)";
        # Freeware by the publisher's own readme — see pkgs/skyroads/.
        package = (import ../pkgs { inherit pkgs; }).skyroads;
      }
      {
        slug = "prince";
        name = "Prince of Persia";
        exe = "PRINCE.EXE";
        dir = "prince";
        comment = "1989 cinematic platformer (Broderbund)";
      }
      {
        slug = "hocus";
        name = "Hocus Pocus";
        exe = "HOCUS.EXE";
        dir = "hocus";
        comment = "1994 platformer (Apogee)";
      }
      {
        slug = "rescue-rover";
        name = "Rescue Rover";
        exe = "ROVER.EXE";
        dir = "rescue-rover";
        comment = "1991 puzzle game (id Software)";
      }
      {
        slug = "keen1";
        name = "Commander Keen: Marooned on Mars";
        exe = "KEEN1.EXE";
        dir = "keen1";
        comment = "1990 platformer, episode 1 (id Software / Apogee)";
      }
      {
        slug = "duke1";
        name = "Duke Nukem";
        exe = "DN1.EXE";
        dir = "duke1";
        comment = "1991 platformer (Apogee)";
      }
      {
        slug = "duke2";
        name = "Duke Nukem II";
        exe = "DN2.EXE";
        dir = "duke2";
        comment = "1993 platformer (Apogee)";
      }
    ];

    # Services
    services.podman.enable = true;
    services.ollama.enable = true; # local LLM server (official prebuilt, CPU-only — version pinned in pkgs/ollama/)

    # Compatibility layers
    compat.appimage.enable = true;
  };

  system.stateVersion = "26.05";
}
