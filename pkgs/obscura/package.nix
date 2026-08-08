# SPDX-License-Identifier: GPL-3.0-or-later
#
# obscura — headless browser for AI agents and web scraping.
#
# Fetches, runs JavaScript on a real V8 isolate, and speaks both CDP and MCP —
# without Chromium or Node. Ships two binaries: `obscura` and `obscura-worker`
# (the parallel `scrape` command spawns the latter, so both must be installed).
#
# Why this is source-built instead of `unstablePkgs.obscura`:
# nixpkgs-unstable carries 0.1.10, which PREDATES the obscura-render crate
# entirely — there is no `render` feature to switch on there at any price. The
# render layer (screenshots, getBoundingClientRect, elementFromPoint) first
# appears in v0.2.0, so getting it means building the tag ourselves and giving
# up the binary cache. `stealth` is enabled for the same reason: it is a build
# -time feature, not a runtime flag.
#
# Pinned by upstream tag rather than by the UnbreakableMJ fork: the fork is a
# zero-divergence mirror that carries no tags of its own (forks do not inherit
# them), and a tag is what lets update-vendored.nu bump this automatically.
#
# Version + hashes are declarative, NOT self-updating. Never bump them by hand:
#   nu pkgs/update-vendored.nu obscura
{
  lib,
  callPackage,
  fetchFromGitHub,
  rustPlatform,
  cmake,
  git,
  pkg-config,
}:

let
  librusty_v8 = callPackage ./librusty_v8.nix { };
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "obscura";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "h4ckf0r0day";
    repo = "obscura";
    rev = "v${finalAttrs.version}";
    hash = "sha256-f09I77mKhQA1mCt8YmtVqbK/QIb9MrvhpYav+FJdkRI=";
  };

  # The tree ships a Cargo.lock, but it also carries a [patch.crates-io] section
  # pointing at in-tree vendor/ copies of taffy and cosmic-text, so the vendored
  # dir is not reproducible from the lock alone — a vendor hash is the only
  # option. Regenerate on every version bump: set to lib.fakeHash, build, paste
  # the reported `got:` value. update-vendored.nu does this automatically.
  cargoHash = "sha256-tBuPQjjqXkF+vcBRXXyi9+gcBzg8L3QH2jjixBzGODE=";

  # All three are for btls-sys — the BoringSSL FFI that the `stealth` feature
  # pulls in through wreq. It compiles the BoringSSL copy vendored inside its own
  # crate, so nothing is fetched at build time, and Go is NOT needed: that tree
  # ships pre-generated sources under deps/boringssl/gen, and GO_EXECUTABLE is
  # only reached under the `fips` / `prefix-symbols` cargo features.
  #
  # git is the surprising one, and it is not a fetcher: btls-sys runs `git init`
  # over the BoringSSL copy it unpacks into $OUT_DIR and then `git apply`s four
  # patches to it. Nothing is cloned — it is purely a local patch tool.
  # BORING_BSSL_ASSUME_PATCHED=1 also silences the failure, but it SKIPS those
  # patches, and one of them is boring-pq.patch (post-quantum key exchange).
  # Modern Chrome offers X25519MLKEM768 in its ClientHello, so taking that
  # shortcut would quietly degrade the very TLS fingerprint `stealth` exists to
  # reproduce. Supplying git keeps upstream's behaviour intact.
  nativeBuildInputs = [
    cmake
    git
    pkg-config
    rustPlatform.bindgenHook
  ];

  # cmake is a dependency of a CRATE, not of this tree — this is a cargo build.
  # Without this, the generic cmake hook tries to configure the source root and
  # fails before cargo ever runs.
  dontUseCmakeConfigure = true;

  # A virtual workspace (no root package) rejects `--features` unless a package
  # is selected, so `-p` is load-bearing rather than an optimisation. This is
  # upstream's own documented build line.
  cargoBuildFlags = [
    "-p"
    "obscura-cli"
    "--bins"
  ];
  buildFeatures = [
    "render"
    "stealth"
  ];

  # Every obscura-js test builds a V8 isolate via deno_core::JsRuntime::new(),
  # and V8 initialisation is incompatible with the sandbox's user namespace and
  # resource limits. Nothing is skippable by name — it is all of them.
  doCheck = false;

  # The v8 crate downloads this archive itself unless pointed at a local copy.
  env.RUSTY_V8_ARCHIVE = "${librusty_v8}";

  passthru = { inherit librusty_v8; };

  meta = {
    description = "Headless browser for AI agents and web scraping";
    longDescription = ''
      Built here with the `render` and `stealth` features: render adds real box
      geometry and PNG screenshots, stealth routes requests through wreq for a
      Chrome TLS fingerprint plus tracker blocking. Note that `obscura --version`
      reports 0.1.0 regardless of the tag — upstream never bumped
      workspace.package.version, so the crate string and the release tag differ.
    '';
    homepage = "https://github.com/h4ckf0r0day/obscura";
    license = lib.licenses.asl20;
    mainProgram = "obscura";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    # Builds from source, but statically links the prebuilt V8 archive above.
    sourceProvenance = [
      lib.sourceTypes.fromSource
      lib.sourceTypes.binaryNativeCode
    ];
  };
})
