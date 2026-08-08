# SPDX-License-Identifier: GPL-3.0-or-later
#
# librusty_v8 — the prebuilt V8 static library Obscura links against.
#
# The `v8` crate's build script downloads this archive from the denoland/rusty_v8
# releases at build time. The Nix sandbox has no network, so it is fetched here
# and handed over via $RUSTY_V8_ARCHIVE (see ../obscura/package.nix).
#
# This file exists instead of `pkgs.deno.librusty_v8` because the two are pinned
# to DIFFERENT V8 versions: deno tracks 147.4.0, while Obscura's Cargo.lock pins
# deno_core 0.350 -> v8 137.3.0. Reusing deno's would link the wrong ABI. Do not
# "simplify" this away — check the lock first.
#
# The version below must match the `v8` entry in Obscura's Cargo.lock exactly.
# `nu pkgs/update-vendored.nu obscura` does NOT bump it: an Obscura release that
# moves deno_core is the one case that needs a manual edit here.
{
  lib,
  stdenv,
  fetchurl,
}:

let
  version = "137.3.0";

  # Upstream publishes one archive per Rust target triple.
  hashes = {
    x86_64-linux = "0rv5nl4gcbvdpk3mdwbqvw180nfx2wk173q1cqrvv2h1agg1ys52";
    aarch64-linux = "14kci8zl7i5cjrbf2jyky5i9gpa4bsjw8khfk4xc8yf1875x0s73";
  };
in
stdenv.mkDerivation {
  name = "librusty_v8-${version}";

  src = fetchurl {
    url = "https://github.com/denoland/rusty_v8/releases/download/v${version}/librusty_v8_release_${stdenv.hostPlatform.rust.rustcTarget}.a.gz";
    sha256 =
      hashes.${stdenv.hostPlatform.system}
        or (throw "librusty_v8: unsupported platform ${stdenv.hostPlatform.system}");
  };

  dontUnpack = true;

  # $out is the .a file itself, not a directory — that is the shape the v8
  # crate's build script expects $RUSTY_V8_ARCHIVE to point at.
  installPhase = ''
    runHook preInstall
    gzip -cd "$src" > "$out"
    runHook postInstall
  '';

  meta = {
    description = "Prebuilt V8 static library for the Rust v8 crate ${version}";
    homepage = "https://github.com/denoland/rusty_v8";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames hashes;
  };
}
