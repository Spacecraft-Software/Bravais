# SPDX-License-Identifier: GPL-3.0-or-later
#
# librusty_v8 — the prebuilt V8 static library Obscura links against.
#
# The `v8` crate's build script downloads this archive from the denoland/rusty_v8
# releases at build time. The Nix sandbox has no network, so it is fetched here
# and handed over via $RUSTY_V8_ARCHIVE (see ../obscura/package.nix).
#
# This file exists instead of `pkgs.deno.librusty_v8` because the two are pinned
# to DIFFERENT V8 versions: deno tracks 149.3.0, while Obscura's Cargo.lock pins
# deno_core 0.412 -> v8 150.4.0 (as of Obscura 0.2.3). Reusing deno's would link the wrong ABI. Do not
# "simplify" this away — check the lock first.
#
# The version below must match the `v8` entry in Obscura's Cargo.lock exactly.
# `nu pkgs/update-vendored.nu obscura` does NOT bump it: an Obscura release that
# moves deno_core is the one case that needs a manual edit here. It presents as
# a LINK failure in the obscura-js build script (undefined `simdutf__*` symbols),
# not as a version error -- read the `v8` entry in the lock, then bump both
# hashes with `nix-prefetch-url` on the per-target `.a.gz`.
#
# The SAME link failure also means a wrong archive VARIANT. The v8 build script
# picks the prebuilt by Cargo feature (`prebuilt_features_suffix()` in its
# build.rs: `_ptrcomp`, `_sandbox`, `_simdutf`, in that order), and
# $RUSTY_V8_ARCHIVE bypasses that choice entirely, so it must name the variant
# the features select. Since deno_core 0.412 goes through the `deno_v8` facade
# with `features = ["simdutf"]`, the plain archive lacks the simdutf shims.
# If a future lock turns on pointer compression or the sandbox, `features`
# below changes with it.
{
  lib,
  stdenv,
  fetchurl,
}:

let
  version = "150.4.0";
  features = "_simdutf";

  # Upstream publishes one archive per Rust target triple.
  hashes = {
    x86_64-linux = "0xml6268gjs2pj7xf50gx3ly337c63j5l724b9hgrwfi235651zl";
    aarch64-linux = "09x5ck4fh3i90dfx1apambmmif0pwm18p19jdxwsb5m32lw2i7jk";
  };
in
stdenv.mkDerivation {
  name = "librusty_v8-${version}";

  src = fetchurl {
    url = "https://github.com/denoland/rusty_v8/releases/download/v${version}/librusty_v8${features}_release_${stdenv.hostPlatform.rust.rustcTarget}.a.gz";
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
