# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — steelbore-vpn, the AdGuard VPN inspector and teardown helper
{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "steelbore-vpn";
  version = "0.1.0";

  src = lib.cleanSource ./.;

  cargoLock.lockFile = ./Cargo.lock;

  # No nativeBuildInputs and no buildInputs: every dependency is pure Rust, and
  # `rustix` reaches the kernel through linux-raw-sys rather than libc, so there
  # is nothing for pkg-config to find. Same shape as preflight.
  #
  # Nothing is wrapped onto PATH either, and here that is a design property
  # rather than a preference: the implementation is a /proc walk plus kill(2)
  # and shells out to nothing at all. This tool is meant to still work when the
  # session it is diagnosing is already unhealthy.
  meta = {
    description = "AdGuard VPN tunnel inspector and teardown helper";
    longDescription = ''
      Reports what the AdGuard VPN client is actually running -- tunnel, sudo
      shims, orphans, and their signal state -- and tears a tunnel down in an
      order that strands nothing. Exists because `adguardvpn-cli disconnect`
      hangs indefinitely in TUN mode on a sudo-rs system: it signals the sudo
      shim recorded in vpn.pid, and that shim blocks SIGTERM.
    '';
    license = lib.licenses.gpl3Plus;
    mainProgram = "steelbore-vpn";
    platforms = lib.platforms.linux;
  };
}
