# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — OpenCode Desktop (official OpenCode app, repackaged .deb)
#
# OpenCode is packaged for Linux as a .deb. This repackages the official
# amd64 .deb: extracts the files, applies autoPatchelfHook to fix the ELF
# interpreter/rpaths, and wraps the launcher.
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
  vulkan-loader,
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
  pname = "opencode-desktop";
  version = "1.18.4";

  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${finalAttrs.version}/opencode-desktop-linux-amd64.deb";
    hash = "sha256-pnvEepje0QJ156jzL6PhZIC1WZbNUiMtqRRQQytNZZk=";
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

    mkdir -p $out/lib $out/bin $out/share
    cp -r opt/OpenCode $out/lib/
    cp -r usr/share/icons $out/share/
    install -Dm644 usr/share/applications/opencode-desktop.desktop \
      $out/share/applications/opencode-desktop.desktop
    install -Dm644 usr/share/applications/ai.opencode.desktop.desktop \
      $out/share/applications/ai.opencode.desktop.desktop

    # Delete unused musl binaries to prevent autoPatchelfHook from failing
    rm -rf $out/lib/OpenCode/resources/app.asar.unpacked/node_modules/@parcel/watcher-linux-x64-musl
    rm -f $out/lib/OpenCode/resources/app.asar.unpacked/node_modules/@msgpackr-extract/msgpackr-extract-linux-x64/*.musl.node

    runHook postInstall
  '';

  postFixup = ''
    # autoPatchelfHook has already fixed the interpreter + rpaths of the bundled
    # Electron binaries at this point. Wrap the launcher.
    # Chromium dlopen()s "libEGL.so.1" from the *bundled* ANGLE libEGL.so, not
    # from the main binary. DT_RUNPATH isn't transitive, so the libglvnd entry
    # runtimeDependencies added to the launcher's rpath is invisible to that
    # dlopen -- hence "Could not dlopen native EGL". LD_LIBRARY_PATH is searched
    # regardless of which object issues the dlopen, and is inherited by the
    # re-exec'd GPU process. Expose only GLVND/Vulkan *dispatch* libs here; the
    # vendor driver itself must keep coming from /run/opengl-driver.
    makeWrapper $out/lib/OpenCode/ai.opencode.desktop $out/bin/opencode-desktop \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath [
          libGL
          libgbm
          vulkan-loader
        ]
      }" \
      --add-flags "--disable-setuid-sandbox" \
      --add-flags "--ozone-platform-hint=auto" \
      --add-flags "--enable-features=WaylandWindowDecorations"

    # Fix Exec path in desktop files
    substituteInPlace $out/share/applications/opencode-desktop.desktop \
      --replace-fail "/opt/OpenCode/ai.opencode.desktop" "$out/bin/opencode-desktop"
    substituteInPlace $out/share/applications/ai.opencode.desktop.desktop \
      --replace-fail "/opt/OpenCode/ai.opencode.desktop" "$out/bin/opencode-desktop"
  '';

  meta = {
    description = "OpenCode Desktop — official OpenCode agent app for Linux, repackaged from the .deb";
    homepage = "https://opencode.ai/";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "opencode-desktop";
    platforms = [ "x86_64-linux" ];
  };
})
