# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Ollama (official prebuilt, CPU-only)
#
# nixpkgs' ollama lags upstream badly (stable 26.05 = 0.24.0, unstable even
# older), and current models 412-reject anything that old. This repackages
# Ollama's OFFICIAL prebuilt Linux binary to track upstream directly.
#
# The official `ollama-linux-amd64.tar.zst` is ~1.4 GB because it bundles CUDA
# runners (cuda_v12 + cuda_v13 ≈ 2 GB unpacked). This ThinkPad has no NVIDIA GPU,
# so those (and the Vulkan runner) are stripped — leaving the ollama binary + the
# CPU `libggml-cpu-*` runners (~50 MB). Effectively the official "ollama-cpu".
#
# Update: bump `version` + `src.hash` from https://github.com/ollama/ollama/releases
# (asset `ollama-linux-amd64.tar.zst`). Ollama does not self-update here, so a
# pinned Nix install is deterministic.
{
  lib,
  stdenv,
  fetchurl,
  zstd,
  autoPatchelfHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "ollama";
  version = "0.31.1";

  src = fetchurl {
    url = "https://github.com/ollama/ollama/releases/download/v${finalAttrs.version}/ollama-linux-amd64.tar.zst";
    hash = "sha256-0pc4HvwTZFH2+rud1kSmf3D+UcFoFaDEqV/w4yejr7Q=";
  };

  nativeBuildInputs = [
    zstd
    autoPatchelfHook
  ];

  buildInputs = [
    (lib.getLib stdenv.cc.cc) # libstdc++ / libgcc_s / libgomp for the CPU runners
  ];

  # ollama dlopens the ggml runners from ../lib/ollama relative to the binary;
  # keep that directory on the RUNPATH.
  appendRunpaths = [ "${placeholder "out"}/lib/ollama" ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    mkdir -p source
    zstd -dc $src | tar -x -C source
    runHook postUnpack
  '';
  sourceRoot = "source";

  installPhase = ''
    runHook preInstall
    # Drop the GPU runners this CPU-only machine can't use (~2 GB CUDA + Vulkan).
    rm -rf lib/ollama/cuda_v12 lib/ollama/cuda_v13 lib/ollama/vulkan
    mkdir -p $out
    cp -r bin lib $out/
    runHook postInstall
  '';

  meta = {
    description = "Get up and running with large language models locally — official prebuilt (CPU-only)";
    homepage = "https://ollama.com";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "ollama";
    platforms = [ "x86_64-linux" ];
  };
})
