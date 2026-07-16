# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Google Chrome Remote Desktop (repackaged official .deb)
#
# CRD is not in nixpkgs. This repackages Google's official amd64 .deb:
# `dpkg -x` the tree, `autoPatchelfHook` the bundled ELF host binaries, and patch
# only the hardcoded *paths* in the Python management script (interpreter, Xorg /
# Xvfb / xrandr / xdpyinfo, the Xorg module dir, and sudo/pkexec) so the daemon
# finds its tools on NixOS. We deliberately do NOT patch CRD's session-launch
# logic — the normal headless-virtual-X flow is what we want (it runs
# ~/.chrome-remote-desktop-session). No setuid `user-session` helper exists in
# this release, so none is wrapped.
#
# Update: run `nu pkgs/update-vendored.nu chrome-remote-desktop` (plan 5.1),
# or by hand: bump `version` + `src.sha256` from the apt index:
#   https://dl.google.com/linux/chrome-remote-desktop/deb/dists/stable/main/binary-amd64/Packages
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  python3,
  cairo,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libxkbcommon,
  nspr,
  nss,
  pam,
  pango,
  systemd,
  libx11,
  libxcb,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxtst,
  xorg-server,
  xrandr,
  xdpyinfo,
}:

let
  crdDir = "/opt/google/chrome-remote-desktop";
  # Runtime Python deps come straight from the .deb's Depends line:
  # python3-dbus, python3-psutil, python3-xdg, python3-packaging.
  py = python3.withPackages (ps: with ps; [
    dbus-python
    psutil
    pyxdg
    packaging
  ]);
in
stdenv.mkDerivation (finalAttrs: {
  pname = "chrome-remote-desktop";
  version = "151.0.7922.13";

  src = fetchurl {
    url = "https://dl.google.com/linux/chrome-remote-desktop/deb/pool/main/c/chrome-remote-desktop/chrome-remote-desktop_${finalAttrs.version}_amd64.deb";
    sha256 = "94e8f7ca4e754d9179a396a8b5d1188252aad70b7a645635b913209b58539a33";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    cairo
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libxkbcommon
    nspr
    nss
    pam
    pango
    (lib.getLib stdenv.cc.cc) # libstdc++ / libgcc_s
    systemd # libsystemd
    libx11
    libxcb
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxtst
  ];

  # The host binaries dlopen libremoting_core.so from their own directory — add
  # it to the RUNPATH so autoPatchelf-fixed binaries can find it at runtime.
  # (This is the classic "libremoting_core.so: cannot open shared object" failure
  # on NixOS.)
  appendRunpaths = [ "${placeholder "out"}${crdDir}" ];

  dontConfigure = true;
  dontBuild = true;

  # Extract into $out (the module references $out/opt/google/... and
  # $out/lib/systemd/...). --no-same-permissions avoids any setuid restore.
  unpackPhase = ''
    runHook preUnpack
    mkdir -p $out
    dpkg-deb --fsys-tarfile $src | tar -x --no-same-permissions --no-same-owner -C $out
    runHook postUnpack
  '';

  # Path patches only — NOT behavior patches. Every substitution is
  # --replace-fail: they are all load-bearing, so a future .deb that moves
  # one of these strings must fail the build loudly rather than ship a
  # runtime-broken daemon with only a warning in the build log.
  patchPhase = ''
    runHook prePatch
    script=$out${crdDir}/chrome-remote-desktop
    substituteInPlace "$script" \
      --replace-fail '#!/usr/bin/python3' '#!${py}/bin/python3' \
      --replace-fail '"Xvfb"' '"${xorg-server}/bin/Xvfb"' \
      --replace-fail '"Xorg"' '"${xorg-server}/bin/Xorg"' \
      --replace-fail '"xrandr"' '"${xrandr}/bin/xrandr"' \
      --replace-fail 'xdpyinfo' '${xdpyinfo}/bin/xdpyinfo' \
      --replace-fail '/usr/lib/xorg/modules' '${xorg-server}/lib/xorg/modules' \
      --replace-fail '/usr/bin/sudo' '/run/wrappers/bin/sudo' \
      --replace-fail '/usr/bin/pkexec' '/run/wrappers/bin/pkexec'
    runHook postPatch
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    ln -s $out${crdDir}/chrome-remote-desktop $out/bin/chrome-remote-desktop
    ln -s $out${crdDir}/start-host $out/bin/start-host
    runHook postInstall
  '';

  meta = {
    description = "Google Chrome Remote Desktop host, repackaged from the official .deb";
    homepage = "https://remotedesktop.google.com/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "chrome-remote-desktop";
    platforms = [ "x86_64-linux" ];
  };
})
