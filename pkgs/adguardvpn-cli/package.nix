# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — AdGuard VPN CLI (upstream static binary).
#
# Not in nixpkgs on either channel (26.05 or unstable ship only `adguardhome`,
# the DNS blocker, and `adguardian` — different products), so the official
# release tarball is vendored the same way as the other pkgs/ entries.
#
# Unlike claude-desktop / goose-desktop / opencode-desktop, there is no
# autoPatchelfHook here and no buildInputs: upstream ships a *fully static*
# ELF (`file` reports "statically linked"), so the binary runs unmodified on
# NixOS. Patching or stripping it would only invalidate the shipped detached
# signature, hence dontStrip.
{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "adguardvpn-cli";
  version = "1.7.12";

  # Upstream tags carry a "-release" suffix that the version string does not.
  src = fetchurl {
    url = "https://github.com/AdguardTeam/AdGuardVPNCLI/releases/download/v${finalAttrs.version}-release/adguardvpn-cli-${finalAttrs.version}-linux-x86_64.tar.gz";
    hash = "sha256-pwaTPIfsiO7IV4zOltK5HDheCDz3OKgG5ps7zYd/uIw=";
  };

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 adguardvpn-cli $out/bin/adguardvpn-cli
    # Ships mode 0750 in the tarball; install it world-readable as a completion.
    install -Dm644 bash-completion.sh \
      $out/share/bash-completion/completions/adguardvpn-cli
    # Detached signature for the binary — kept for provenance, not executed.
    install -Dm644 adguardvpn-cli.sig $out/share/adguardvpn-cli/adguardvpn-cli.sig

    runHook postInstall
  '';

  # `adguardvpn-cli --version` writes into $XDG_DATA_HOME on first run, so the
  # check is confined to a scratch HOME rather than the builder's default.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME=$(mktemp -d)
    $out/bin/adguardvpn-cli --version
    runHook postInstallCheck
  '';

  meta = {
    description = "Command-line client for AdGuard VPN";
    homepage = "https://github.com/AdguardTeam/AdGuardVPNCLI";
    downloadPage = "https://github.com/AdguardTeam/AdGuardVPNCLI/releases";
    license = lib.licenses.unfree; # proprietary AdGuard EULA
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "adguardvpn-cli";
    platforms = [ "x86_64-linux" ];
  };
})
