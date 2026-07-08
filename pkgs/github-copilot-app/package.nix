# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — GitHub Copilot app (official Tauri-based desktop app)
#
# The Linux app ships as a .deb with the main binary at /usr/bin/github
# (a 640 MB ELF) and the runtime bundle at /usr/lib/GitHub\ Copilot/.
# It is a Tauri app (not Electron), so it depends on webkit2gtk 4.1
# (the GTK3-based web renderer) rather than Chrome/Electron.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  # GTK / webkit2gtk stack (Tauri runtime)
  alsa-lib,
  atk,
  cairo,
  gdk-pixbuf,
  glib,
  gtk3,
  harfbuzz,
  libsoup_3,
  pango,
  webkitgtk_4_1,
  # GLib misc
  libpulseaudio,
  systemd,
  # OpenSSL 3 — linked by the main binary
  openssl,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github-copilot-app";
  version = "1.0.9";

  src = fetchurl {
    url = "https://github.com/github/app/releases/download/v${finalAttrs.version}/GitHub-Copilot-linux-x64.deb";
    hash = "sha256-mPOVlmRb72/4hNoJ1CxcDq90UXGPKZJPmwPM9yWRKAk=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    atk
    cairo
    gdk-pixbuf
    glib
    gtk3
    harfbuzz
    libsoup_3
    (lib.getLib openssl)
    libpulseaudio
    pango
    (lib.getLib systemd)
    webkitgtk_4_1
  ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile $src | tar -x --no-same-permissions --no-same-owner
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share

    # Main launcher binary + credential helper
    cp usr/bin/github $out/bin/
    cp usr/bin/git-credential-copilot $out/bin/

    # App bundle (Tauri runtime, native plugins, terminal integration, .so libs)
    cp -r "usr/lib/GitHub Copilot" $out/lib/

    # Icons
    cp -r usr/share/icons $out/share/

    # Desktop file (upstream has a space in the name)
    install -Dm644 "usr/share/applications/GitHub Copilot.desktop" \
      $out/share/applications/github-copilot.desktop

    runHook postInstall
  '';

  postFixup = ''
    # Tauri apps use webkit2gtk which supports Wayland natively via GDK.
    # `CPATH` is unset because we only need bundled .so files in the
    # library path — the main binary links against webkit2gtk from nixpkgs
    # while the bundled libonnxruntime etc. are vendored.
    # `GDK_BACKEND=wayland` ensures GTK renders under Wayland (Niri).
    makeWrapper $out/bin/github $out/bin/github-copilot \
      --prefix LD_LIBRARY_PATH : $out/lib \
      --set-default GDK_BACKEND wayland
  '';

  meta = {
    description = "GitHub Copilot app — agent-driven development from issue to merge (Tauri)";
    homepage = "https://github.com/features/ai/github-app";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "github-copilot";
    platforms = [ "x86_64-linux" ];
  };
})
