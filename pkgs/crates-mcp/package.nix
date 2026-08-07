# SPDX-License-Identifier: GPL-3.0-or-later
#
# crates-mcp — the `crates` MCP server (crates.io / docs.rs lookups).
#
# Third-party, so it is packaged here rather than consumed as a flake input:
# the first-party tools (vacuum, engram, mcpctl) ship their own flakes and are
# pinned by rev; this one is a published crate pinned by version + hash.
#
# It is the last binary in mcp-servers/mcp.toml that used to resolve to an
# imperative `cargo install` under ~/.cargo/bin. mcp.toml names it by BARE
# NAME, so this derivation is what every MCP host now spawns.
{ lib, rustPlatform, fetchCrate, pkg-config, openssl }:

rustPlatform.buildRustPackage rec {
  pname = "crates-mcp";
  version = "0.1.0";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-nHiDHc2VG5VUAIwoHdReQmDqBt6MENdGKXeps5oO6B0=";
  };

  # A crates.io tarball ships no Cargo.lock, so there is no `cargoLock.lockFile`
  # to point at the way vacuum and engram do — a vendor hash is the only option.
  # Unlike those two, this hash MUST be regenerated on every version bump:
  # set it to lib.fakeHash, build, and paste the reported `got:` value.
  cargoHash = "sha256-NV8ewbAqMerH+AMU5IBR+OINaZ0oyxgE2wxQXbhI7j4=";

  # It reaches crates.io/docs.rs over TLS through reqwest's default-features,
  # which pulls openssl-sys rather than rustls. openssl-sys shells out to
  # pkg-config and fails the build outright without it — it will not fall back
  # to a vendored build. (Upstream could switch to rustls and drop both of
  # these; that is a patch for them, not a local override.)
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  # Four of the nine unit tests are live integration tests against crates.io and
  # docs.rs, which the build sandbox has no network for. Skipped by name rather
  # than switching off `doCheck` wholesale, so the five offline tests still run
  # and a real regression in them still fails the build.
  checkFlags = [
    "--skip=crates_client::tests::test_get_crate_info"
    "--skip=crates_client::tests::test_search_crates"
    "--skip=docs_client::tests::test_docs_rs_url_accessibility"
    "--skip=docs_client::tests::test_fixed_crate_documentation_integration"
  ];

  meta = {
    description = "MCP server for querying Rust crates from crates.io and docs.rs";
    homepage = "https://github.com/pato/crates-mcp";
    license = lib.licenses.mit;
    mainProgram = "crates-mcp";
    platforms = lib.platforms.linux;
  };
}
