# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — SkyRoads (1993, Bluemoon Interactive) game data
#
# Data only: the DOS executable and its assets. It is run through
# dosbox-staging by the `play-skyroads` wrapper that modules/packages/games.nix
# generates from the steelbore.packages.games.dosGames registry.
#
# LICENSING — this is freeware, released by the original publisher, not
# abandonware scraped from a ROM site. The bundled readme.txt says, verbatim:
#
#   "This program is freeware. You can distribute this program freely, as long
#    as you don't reverse engineer, and/or modify this program or any of its
#    accompanying files. This program must be distributed as a single unit,
#    with all accompanying files included and intact in their original form."
#
# Two consequences are load-bearing and must not be "tidied":
#   - ALL 29 files are installed unmodified, readme.txt included. Do not prune
#     assets, do not repackage, do not convert anything. "Single unit, intact"
#     is the condition the redistribution grant is attached to.
#   - meta.license is unfreeRedistributable, not a free licence: modification
#     and reverse engineering are forbidden, so it fails the FSF/OSI tests even
#     though redistribution is granted. allowUnfree is already true
#     (modules/core/nix.nix).
#
# NOT in pkgs/update-vendored.nu, deliberately. That script exists for upstreams
# that ship new releases; this archive has been frozen since 1995 and Bluemoon
# publishes no release feed to poll. There is nothing for a bumper to check.
{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "skyroads";
  version = "1.0";

  # HTTP only — bluemoon.ee serves no HTTPS on this path (a TLS connection is
  # refused outright, not merely untrusted). That is acceptable here because
  # integrity comes from the pinned hash below, which is what Nix verifies;
  # the transport is not the trust anchor. Do not "fix" the scheme to https,
  # it fails the fetch.
  src = fetchurl {
    url = "http://www.bluemoon.ee/history/skyroads/skyroads.zip";
    hash = "sha256-JHYv4UGWpkIiQoj+IGPJ0MADO+nFtLL5f97Qk5CAPuQ=";
  };

  nativeBuildInputs = [ unzip ];

  # The archive has no top-level directory — the 29 files sit at its root — so
  # unpack into one we make ourselves rather than letting them spill.
  unpackPhase = ''
    runHook preUnpack
    mkdir -p source
    unzip -q $src -d source
    runHook postUnpack
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/games/dos/skyroads
    cp -r source/. $out/share/games/dos/skyroads/
    runHook postInstall
  '';

  meta = {
    description = "SkyRoads — 1993 DOS space-racing game, released as freeware by its publisher";
    longDescription = ''
      A puzzle-racing game in which a spacecraft jumps between floating roads,
      published by Bluemoon Interactive in 1993 and later released as freeware
      from the publisher's own site.

      This package ships the game data only. Run it with `play-skyroads`, which
      modules/packages/games.nix generates from the dosGames registry; the data
      is seeded once into ~/Games/dos/skyroads so the game can write its
      high-score table (the Nix store is read-only).
    '';
    homepage = "http://www.bluemoon.ee/history/skyroads/";
    license = lib.licenses.unfreeRedistributable;
    platforms = lib.platforms.all; # data only — DOSBox supplies the machine
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
