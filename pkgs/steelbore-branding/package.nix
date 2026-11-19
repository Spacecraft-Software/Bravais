# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — the Steelbore OS logo as a freedesktop icon set.
#
# Installs the two marks under the icon names that
# lib/identity.nix states (`logo`, `logoText`), so os-release's LOGO= and
# every About page resolve them through the hicolor theme:
#
#   share/icons/hicolor/scalable/apps/<logo>.svg       emblem only
#   share/icons/hicolor/scalable/apps/<logoText>.svg   emblem + STEELBORE wordmark
#   share/icons/hicolor/<n>x<n>/apps/<logo>.png        64 / 128 / 256 raster
#   share/pixmaps/<logo>.{svg,png}                     legacy lookup path
#
# Raster copies exist because not every consumer loads SVG: some About
# dialogs and fetch tools only search the fixed-size directories or
# /run/current-system/sw/share/pixmaps. Only the square emblem is rasterised
# into hicolor/<n>x<n> — the wordmark is 600×257 and the icon theme spec
# assumes square sizes, so it ships scalable only (KDE Info Center, its sole
# consumer, renders SVG).
#
# Rendered with resvg (Rust, Standard rust-first) rather than librsvg's or
# ImageMagick's C paths.
#
# Both marks come from the Spacecraft-Software/Branding repository
# (`brandingSrc`, the `branding` flake input), the umbrella's single source
# for the marks: `logo` is logo/steelbore/sb_logo.svg and `logoText` is
# logo/steelbore/steelbore_logo.svg (the emblem over the stencil wordmark).
#
# Package files receive no specialArgs, so the names come from a direct
# import of lib/identity.nix and the colour arrives as an argument:
# modules/theme/branding.nix passes the active palette's `foreground` role.
{
  lib,
  stdenvNoCC,
  resvg,
  # The Branding repository's source tree; pkgs/default.nix passes it.
  brandingSrc ? null,
  # "#RRGGBB", or null to ship the artwork's own colour untouched (what a
  # bare `nix build .#steelbore-branding` produces).
  fill ? null,
}:

let
  identity = import ../../lib/identity.nix;
  sizes = [
    64
    128
    256
  ];
in

assert lib.assertMsg (
  fill == null || builtins.match "#[0-9A-Fa-f]{6}" fill != null
) "steelbore-branding: fill must be \"#RRGGBB\" or null, got ${toString fill}";

assert lib.assertMsg (brandingSrc != null)
  "steelbore-branding: brandingSrc is unset; import pkgs/default.nix with `branding` (the flake input).";

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "steelbore-branding";
  version = "1.0.0";

  dontUnpack = true;

  nativeBuildInputs = [ resvg ];

  passthru = {
    inherit (identity) logo logoText;
  };

  buildPhase = ''
    runHook preBuild

    cp "${brandingSrc}/logo/steelbore/sb_logo.svg" ${finalAttrs.passthru.logo}.svg
    cp "${brandingSrc}/logo/steelbore/steelbore_logo.svg" ${finalAttrs.passthru.logoText}.svg
    chmod u+w ./*.svg
  ''
  # Each supplied SVG is single-colour: every hex fill in it carries the same
  # value, set on each path in both marks (an older export set it once on the
# <g>, which the check accepts too). It
  # is matched by shape (any 6-digit hex fill), never by value, so no colour
  # is named in Nix (§11.4) and a re-export in another colour still works.
  # The check fails the build if an asset ever carries no hex fill or two
  # different ones, rather than silently recolouring part of it.
  + lib.optionalString (fill != null) ''
    for f in ./*.svg; do
      n=$(grep -oE 'fill="#[0-9A-Fa-f]{6}"' "$f" | sort -u | wc -l)
      if [ "$n" -ne 1 ]; then
        echo "steelbore-branding: $f has $n distinct hex fill colours, expected exactly 1" >&2
        exit 1
      fi
      sed -E -i 's/fill="#[0-9A-Fa-f]{6}"/fill="${fill}"/g' "$f"
    done
  ''
  + ''
    ${lib.concatMapStringsSep "\n" (n: ''
      resvg --width ${toString n} --height ${toString n} \
        ${finalAttrs.passthru.logo}.svg ${finalAttrs.passthru.logo}-${toString n}.png
    '') sizes}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    icons=$out/share/icons/hicolor
    install -Dm644 -t "$icons/scalable/apps" \
      ${finalAttrs.passthru.logo}.svg ${finalAttrs.passthru.logoText}.svg
    ${lib.concatMapStringsSep "\n" (n: ''
      install -Dm644 ${finalAttrs.passthru.logo}-${toString n}.png \
        "$icons/${toString n}x${toString n}/apps/${finalAttrs.passthru.logo}.png"
    '') sizes}

    install -Dm644 ${finalAttrs.passthru.logo}.svg "$out/share/pixmaps/${finalAttrs.passthru.logo}.svg"
    install -Dm644 ${finalAttrs.passthru.logo}-256.png "$out/share/pixmaps/${finalAttrs.passthru.logo}.png"

    runHook postInstall
  '';

  meta = {
    description = "${identity.name} logo and wordmark as a hicolor icon set";
    homepage = identity.urls.home;
    license = lib.licenses.cc-by-sa-40;
    platforms = lib.platforms.linux;
  };
})
