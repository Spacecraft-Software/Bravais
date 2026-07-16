# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Goose Desktop (Block's open-source AI agent app, repackaged .deb)
#
# Goose Desktop has no Flathub listing (block/goose#6602 is open upstream) and
# is not in nixpkgs, so it's repackaged the same way as opencode-desktop,
# claude-desktop and github-copilot-app: extract the official amd64 .deb,
# apply autoPatchelfHook to fix the ELF interpreter/rpaths, and wrap the
# launcher.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  # Chromium/Electron runtime libraries
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libcap_ng,
  libdrm,
  libGL,
  libgbm,
  libnotify,
  libseccomp,
  libpulseaudio,
  libsecret,
  libuuid,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  systemd,
  wayland,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbfile,
  libxrandr,
  libxrender,
  libxscrnsaver,
  libxshmfence,
  libxtst,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "goose-desktop";
  version = "1.43.0";

  src = fetchurl {
    url = "https://github.com/block/goose/releases/download/v${finalAttrs.version}/goose_${finalAttrs.version}_amd64.deb";
    hash = "sha256-6pEqVxdUF1KAT+5OIDFBqahYerzbZiq+0uRv0lMmYMk=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libcap_ng
    libdrm
    libGL
    libgbm
    libnotify
    libpulseaudio
    libsecret
    libuuid
    libxkbcommon
    mesa
    nspr
    nss
    pango
    (lib.getLib stdenv.cc.cc) # libstdc++ / libgcc_s
    systemd # libudev
    wayland
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbfile
    libxrandr
    libxrender
    libxscrnsaver
    libxshmfence
    libxtst
  ];

  # Electron dlopen()s these at runtime (not in DT_NEEDED), so add them to rpath.
  runtimeDependencies = [
    libGL
    libpulseaudio
    (lib.getLib systemd)
  ];

  dontConfigure = true;
  dontBuild = true;

  # We wrap the launcher manually in postFixup; let wrapGAppsHook3 only collect
  # gappsWrapperArgs (GTK schemas / GDK_PIXBUF / XDG_DATA_DIRS).
  dontWrapGApps = true;

  sourceRoot = ".";
  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile $src | tar -x --no-same-permissions --no-same-owner
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/bin $out/share/applications $out/share/pixmaps
    cp -r usr/lib/goose $out/lib/Goose
    install -Dm644 usr/share/applications/goose.desktop \
      $out/share/applications/goose-desktop.desktop
    install -Dm644 usr/share/pixmaps/goose.png \
      $out/share/pixmaps/goose.png

    runHook postInstall
  '';

  postFixup = ''
    # autoPatchelfHook has already fixed the interpreter + rpaths of the bundled
    # Electron binaries at this point. Wrap the launcher.
    makeWrapper $out/lib/Goose/Goose $out/bin/goose-desktop \
      "''${gappsWrapperArgs[@]}" \
      --add-flags "--disable-setuid-sandbox" \
      --add-flags "--ozone-platform-hint=auto" \
      --add-flags "--enable-features=WaylandWindowDecorations"

    # Fix Exec and Icon paths in the desktop file
    substituteInPlace $out/share/applications/goose-desktop.desktop \
      --replace-fail "/usr/lib/goose/Goose" "$out/bin/goose-desktop" \
      --replace-fail "/usr/share/pixmaps/goose.png" "$out/share/pixmaps/goose.png"
  '';

  meta = {
    description = "Goose Desktop — open-source AI agent app by Block, repackaged from the .deb";
    homepage = "https://goose-docs.ai/";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "goose-desktop";
    platforms = [ "x86_64-linux" ];
  };
})
