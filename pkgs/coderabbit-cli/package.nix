# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — CodeRabbit CLI (upstream prebuilt binary).
#
# Local AI code review before a PR exists; the same service reviews PRs on
# GitHub through its app (docs/ai-delegation.md). Not in nixpkgs on either
# channel. Upstream's route is `curl … | sh`, which drops `coderabbit` and its
# alias `cr` into ~/.local/bin; this pins the same release archive instead.
#
# The installer verifies an OpenSSL signature over SHA256SUMS before trusting
# the archive. Here the pinned `hash` does that job: a changed upload fails
# the build instead of running. Releases live at
#   https://cli.coderabbit.ai/releases/<version>/coderabbit-linux-x64.zip
# and https://cli.coderabbit.ai/releases/latest/VERSION names the newest one,
# which is what `nu pkgs/update-vendored.nu coderabbit-cli` reads.
#
# Closed source and not Rust; no memory-safe tool does the same job. Its own
# `coderabbit update` would write into the store and fail, so bump it only
# through update-vendored.nu.
{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "coderabbit-cli";
  version = "0.9.0";

  src = fetchurl {
    url = "https://cli.coderabbit.ai/releases/${finalAttrs.version}/coderabbit-linux-x64.zip";
    hash = "sha256-VuTJnenREQbD5r8xA0hk2490bLl8nq+UcK3PpkYdpm8=";
  };

  nativeBuildInputs = [
    unzip
    autoPatchelfHook
  ];
  buildInputs = [ stdenv.cc.cc.lib ];

  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  # Single-file executables of this kind often carry their payload appended
  # to the ELF; strip would cut it off. Same reasoning as constraint #40.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 coderabbit $out/bin/coderabbit
    ln -s coderabbit $out/bin/cr

    runHook postInstall
  '';

  # `--version` must not need a sign-in or a writable config dir; a scratch
  # HOME keeps any first-run state out of the builder's default.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME=$(mktemp -d)
    $out/bin/coderabbit --version
    runHook postInstallCheck
  '';

  meta = {
    description = "CodeRabbit CLI — AI code review of local changes";
    homepage = "https://docs.coderabbit.ai/cli/overview";
    downloadPage = "https://www.coderabbit.ai/cli";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "coderabbit";
    platforms = [ "x86_64-linux" ];
  };
})
