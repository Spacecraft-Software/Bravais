# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Games: classic FPS source ports and DOS emulation
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.steelbore.packages.games;

  inTreePkgs = import ../../pkgs { inherit pkgs; };

  # Every path in this module derives from this one string — the wrappers via
  # $HOME at run time, the tmpfiles rules via systemd's %h. Nothing else states
  # a path.
  dataDir = cfg.dataDir;

  # ── Why wrappers at all ────────────────────────────────────────────────────
  # Each engine locates its game data differently and none of them defaults to
  # a user-writable directory, because the Nix store is read-only and the FHS
  # paths they fall back on (/usr/share/games/doom …) do not exist here. The
  # path is baked into a thin wrapper per engine rather than exported as a
  # session variable — the `orcaPython` rationale in ./orca.nix: the setting
  # travels with the binary instead of depending on the session environment
  # being inherited, which a .desktop- or Flatpak-started process may not do.
  #
  # ── Why every wrapper is `play-`-prefixed ──────────────────────────────────
  # NOT cosmetic, and NOT merely collision-avoidance. `freedoom`'s own
  # bin/freedoom1 launcher searches PATH for the first of
  #   doom odamex gzdoom crispy-doom chocolate-doom prboom-plus
  # so a wrapper named plain `doom` HIJACKS it. And because
  # `config.system.path` is a buildEnv with ignoreCollisions = true, a wrapper
  # sharing an engine's binary name would not fail the build the way the
  # Home-Manager buildEnv does in AGENTS.md constraint #12 — an arbitrary one
  # would silently win, which is worse. One prefix also means `play-<TAB>`
  # enumerates everything playable, matching the `app …` / `theme …` /
  # `skills-*` command families.

  # GZDoom resolves IWADs only through gzdoom.ini's [IWADSearch.Directories],
  # one of whose stock Unix entries is the literal string "$DOOMWADDIR",
  # expanded per launch. Exec bin/gzdoom and never share/games/doom/gzdoom:
  # GZDoom derives its progdir (gzdoom.pk3, lights.pk3, soundfonts) from
  # argv[0], and the bin entry is the makeWrapper that keeps that right.
  #
  # CAVEAT: those defaults are written only when the section is ABSENT. If a
  # stale ~/.config/gzdoom/gzdoom.ini predates this module and lacks the entry,
  # the wrapper silently has no effect — delete its [IWADSearch.Directories]
  # section once and let GZDoom regenerate it.
  playDoom = pkgs.writeShellScriptBin "play-doom" ''
    export DOOMWADDIR="''${DOOMWADDIR:-$HOME/${dataDir}/doom}"
    exec ${lib.getExe pkgs.gzdoom} "$@"
  '';

  # QuakeSpasm-family -basedir points at the directory CONTAINING id1/, not at
  # id1/ itself, and is repeatable: the first goes through COM_SetBaseDir,
  # which errors unless id1/pak0.pak is there, and later ones through
  # COM_AddBaseDir unvalidated. So the user's directory comes first and
  # ironwail's own share/quake (holding ironwail.pak, its QoL menu pak) second.
  playQuake = pkgs.writeShellScriptBin "play-quake" ''
    exec ${lib.getExe pkgs.ironwail} \
      -basedir "$HOME/${dataDir}/quake" \
      -basedir ${pkgs.ironwail}/share/quake "$@"
  '';

  playQuakeVk = pkgs.writeShellScriptBin "play-quake-vk" ''
    exec ${lib.getExe pkgs.vkquake} -basedir "$HOME/${dataDir}/quake" "$@"
  '';

  # Raze has NO data-path environment variable and no -basedir. GRP
  # autodetection runs off [GameSearch.Directories] in raze.ini, whose
  # UNCONDITIONAL defaults (source/core/gameconfigfile.cpp, before the
  # per-platform #ifdef) are `Path=.` and `Path=./*` — the working directory.
  # Hence the chdir.
  #
  # Deliberately NOT `-j <dir>`: that flag lands in the Build-launcher
  # emulation branch of gamecontrol.cpp, which adds a directory as MOD content
  # to the load order, not as a GRP search path. It does not do what it looks
  # like it does.
  #
  # Deliberately NOT a generated raze.ini either: Raze writes its own settings
  # back to that file, so a Nix-managed copy would be the same read-only-config
  # breakage documented for appletsrc in users/mj/plasma.nix. Saves and config
  # stay in ~/.config/raze regardless of cwd, so nothing is written into the
  # data directory.
  playDuke3d = pkgs.writeShellScriptBin "play-duke3d" ''
    mkdir -p "$HOME/${dataDir}/duke3d"
    cd "$HOME/${dataDir}/duke3d"
    exec ${lib.getExe pkgs.raze} "$@"
  '';

  # nixpkgs already wraps eduke32 with
  #   --set-default EDUKE32_DATA_DIR /var/lib/games/eduke32
  #   --add-flags '-j"$EDUKE32_DATA_DIR"' --add-flags '-gamegrp DUKE3D.GRP'
  # so overriding that one variable is the entire change. Re-wrapping the flags
  # ourselves would drift from upstream's.
  playDuke3dEduke32 = pkgs.writeShellScriptBin "play-duke3d-eduke32" ''
    export EDUKE32_DATA_DIR="''${EDUKE32_DATA_DIR:-$HOME/${dataDir}/duke3d}"
    exec ${pkgs.eduke32}/bin/eduke32-wrapper "$@"
  '';

  # ── DOS game registry ──────────────────────────────────────────────────────
  # DOSBox Staging needs no MOUNT incantation: per docs/dosbox.1, "If PATH is a
  # DOS executable (.BAT/.COM/.EXE), its parent path is mounted as C: and the
  # executable is run. When the executable exits, DOSBox Staging quits."
  #
  # Seeding is a shell conditional rather than a tmpfiles `C` rule because `C`
  # copies with the SOURCE's mode, and every file in the store is r--r--r-- —
  # the game could not write its high-score table into the copy. Doing it in
  # the wrapper also keeps it running as the user, needs no root, and
  # self-heals if the directory is deleted.
  mkDosGame =
    game:
    pkgs.writeShellScriptBin "play-${game.slug}" ''
      set -eu
      dir="$HOME/${dataDir}/dos/${game.dir}"
      ${lib.optionalString (game.package != null) ''
        if [ ! -e "$dir/${game.exe}" ]; then
          mkdir -p "$dir"
          cp -r ${game.package}/${game.dataPath}/. "$dir/"
          chmod -R u+w "$dir"
        fi
      ''}
      if [ ! -e "$dir/${game.exe}" ]; then
        echo "play-${game.slug}: ${game.exe} not found in $dir" >&2
        echo "Put the game's files there, then run this again." >&2
        exit 1
      fi
      exec ${lib.getExe' pkgs.dosbox-staging "dosbox"} \
        --working-dir "$dir" ${lib.escapeShellArgs game.extraArgs} \
        "$dir/${game.exe}" "$@"
    '';

  mkDosDesktopItem =
    game:
    pkgs.makeDesktopItem {
      name = "steelbore-play-${game.slug}";
      desktopName = game.name;
      genericName = "DOS game";
      comment = game.comment;
      exec = "play-${game.slug}";
      categories = [ "Game" ];
      terminal = false;
    };
in
{
  options.steelbore.packages.games = {
    enable = lib.mkEnableOption "Classic FPS source ports and DOS emulation";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "Games";
      description = ''
        Directory holding game data, relative to the user's home. Every wrapper
        and every tmpfiles rule in this module derives its paths from this one
        string.
      '';
    };

    dosGames = lib.mkOption {
      description = ''
        DOS games to expose. Each entry generates a `play-<slug>` command that
        runs the game under dosbox-staging, plus a matching launcher entry.

        ADD A GAME HERE — one attrset is the whole change. Point `package` at
        a package installing to `share/games/dos/<dir>`, or leave it null and
        drop the files into ~/<dataDir>/dos/<dir> by hand.
      '';
      default = [ ];
      type = lib.types.listOf (
        lib.types.submodule (
          { config, ... }:
          {
            options = {
              slug = lib.mkOption {
                type = lib.types.strMatching "[a-z0-9-]+";
                description = "Identifier; the command becomes `play-<slug>`.";
              };
              name = lib.mkOption {
                type = lib.types.str;
                description = "Human-readable name shown in the app launcher.";
              };
              exe = lib.mkOption {
                type = lib.types.str;
                example = "SKYROADS.EXE";
                description = ''
                  The DOS executable, spelled EXACTLY as it appears on disk.
                  DOSBox is case-insensitive about DOS names, but this path is
                  resolved by the host kernel first and these archives are
                  upper-case.
                '';
              };
              dir = lib.mkOption {
                type = lib.types.str;
                description = "Directory under ~/<dataDir>/dos/ holding the game's files.";
              };
              package = lib.mkOption {
                type = lib.types.nullOr lib.types.package;
                default = null;
                description = ''
                  Optional package supplying the game data, seeded into
                  ~/<dataDir>/dos/<dir> on first run. Leave null for a game
                  whose files you drop in by hand (a commercial title you own).
                '';
              };
              dataPath = lib.mkOption {
                type = lib.types.str;
                default = "share/games/dos/${config.dir}";
                description = "Path inside `package` holding the game's files.";
              };
              comment = lib.mkOption {
                type = lib.types.str;
                default = "";
                description = "Launcher entry comment.";
              };
              extraArgs = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                example = [ "--fullscreen" ];
                description = "Extra dosbox flags for this game.";
              };
            };
          }
        )
      );
    };
  };

  # Game DATA is never shipped by this module, and that is a legal boundary
  # rather than an oversight. Three tiers, documented in PRD.md:
  #
  #   1. Free content — freedoom's three WADs, symlinked into ~/<dataDir>/doom
  #      below, so Doom is playable with nothing supplied at all.
  #   2. Freely redistributable shareware — Doom 1 DOOM1.WAD, Quake's shareware
  #      pak0.pak, the Duke3D shareware GRP. Legal to fetch, not fetched here.
  #   3. Commercial — DOOM.WAD, DOOM2.WAD, TNT/PLUTONIA, Quake pak1.pak, the
  #      full DUKE3D.GRP. These come from the user's own Steam/GOG copy.
  #      Nothing in this repo downloads them, and nothing should.
  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      (with pkgs; [
        # ── Doom engine ──────────────────────────────────────────────────────
        gzdoom # C++ — OpenGL/Vulkan Doom port (Doom 1/2/Ultimate/Final, Heretic, Hexen)
        freedoom # data — free BSD-3 replacement WADs; needs an engine

        # ── Quake 1 ──────────────────────────────────────────────────────────
        ironwail # C — performance-focused QuakeSpasm fork (the default)
        vkquake # C — Vulkan QuakeSpasm fork

        # ── Duke Nukem 3D (Build engine) ─────────────────────────────────────
        raze # C++ — ZDoom-tech Build port (Duke3D, Blood, Shadow Warrior, Redneck Rampage)
        eduke32 # C — the classic Duke3D port (also voidsw, Ion Fury)

        # ── DOS ──────────────────────────────────────────────────────────────
        dosbox-staging # C++ — modernized DOS emulator
      ])
      ++ [
        playDoom
        playQuake
        playQuakeVk
        playDuke3d
        playDuke3dEduke32
      ]
      ++ map mkDosGame cfg.dosGames
      ++ map mkDosDesktopItem cfg.dosGames;

    # systemd.user.tmpfiles (not systemd.tmpfiles) so %h expands to the
    # invoking user's home — no literal `mj`, no primaryUser threading, and the
    # honest semantics for "the games directory". NixOS's
    # system.userActivationScripts.tmpfiles runs `systemd-tmpfiles --user
    # --create`, so these appear at switch time, not only at next login.
    systemd.user.tmpfiles.rules =
      let
        d = path: "d %h/${path} 0755 - - -";
      in
      [
        (d dataDir)
        (d "${dataDir}/doom")
        (d "${dataDir}/quake")
        (d "${dataDir}/quake/id1")
        (d "${dataDir}/duke3d")
        (d "${dataDir}/dos")
      ]
      ++
        # Freedoom is data-only and lives in its own store path, which GZDoom
        # cannot see: gzdoom's progdir is ITS OWN share/games/doom (gzdoom.pk3
        # and friends), and the FHS fallbacks it also searches
        # (/usr/share/games/doom, …) do not exist on NixOS. Without these links
        # a fresh install dies on "Cannot find a game IWAD" even though the free
        # WADs are installed. Linking them into the same directory the user
        # drops commercial WADs into makes one directory the whole answer to
        # "where do WADs go".
        #
        # L+ (force) rather than L so a link left over from an older freedoom
        # store path is replaced. The trade-off is that it also replaces a real
        # file of the same name — acceptable for these three reserved names.
        map (wad: "L+ %h/${dataDir}/doom/${wad} - - - - ${pkgs.freedoom}/share/games/doom/${wad}") [
          "freedoom1.wad"
          "freedoom2.wad"
          "freedm.wad"
        ]
      ++ [
        # gzdoom's stock ini also lists $HOME/.local/share/games/doom, and
        # freedoom's own bin/freedoom1 launcher hardcodes that same path into
        # DOOMWADPATH. Aliasing it costs one line and makes both the upstream
        # launchers and a stock gzdoom.ini work with no further configuration.
        "L+ %h/.local/share/games/doom - - - - %h/${dataDir}/doom"
      ];
  };
}
