# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Claude Desktop (official Anthropic Linux beta, repackaged .deb)
#
# Anthropic ships Claude Desktop for Linux only as a .deb + apt repo (no nixpkgs
# package). This repackages the OFFICIAL .deb: `dpkg -x` the bundled Electron app,
# `autoPatchelfHook` to fix the ELF interpreter/rpaths against nixpkgs libraries,
# then wrap the launcher for Wayland + MCP.
#
# Update on new releases: bump `version` and `src.hash`. Get the current version,
# pool path and SHA256 from the apt index:
#   https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages
# The Linux app does NOT self-update (updates via apt only), so a pinned Nix
# install is safe.
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
  # MCP launchers must resolve at runtime (npx / uvx)
  nodejs,
  uv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "claude-desktop";
  version = "1.17377.2";

  src = fetchurl {
    url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_${finalAttrs.version}_amd64.deb";
    hash = "sha256-7AjUGqeYjS06P19P/fONIHtBLmYmOfQNeiZbivriEqs=";
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
    libcap_ng # virtiofsd (Cowork VM helper)
    libdrm
    libGL
    libgbm
    libnotify
    libpulseaudio
    libseccomp # virtiofsd (Cowork VM helper)
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
  # `dpkg-deb -x` tries to restore chrome-sandbox's setuid bit (rwsr-xr-x), which
  # the Nix build sandbox forbids. Pipe the filesystem tarball through tar with
  # --no-same-permissions so the setuid bit is dropped (the store can't hold
  # setuid binaries anyway; the wrapper uses --disable-setuid-sandbox).
  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile $src | tar -x --no-same-permissions --no-same-owner
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/bin $out/share
    cp -r usr/lib/claude-desktop $out/lib/
    cp -r usr/share/icons $out/share/
    install -Dm644 usr/share/applications/claude-desktop.desktop \
      $out/share/applications/claude-desktop.desktop

    runHook postInstall
  '';

  postFixup = ''
    # autoPatchelfHook has already fixed the interpreter + rpaths of the bundled
    # Electron binaries at this point. Wrap the launcher:
    #  - gappsWrapperArgs: GTK settings schemas / icon + pixbuf loaders.
    #  - PATH prefix: node/uv so MCP servers spawned via npx/uvx resolve.
    #  - --disable-setuid-sandbox: the bundled chrome-sandbox can't be setuid in
    #    the Nix store; this keeps Chromium's user-namespace sandbox (still
    #    sandboxed — unlike --no-sandbox) and works on NixOS (unprivileged userns
    #    is enabled by default).
    #  - Ozone hints: crisp rendering + client-side decorations under Wayland/Niri.
    makeWrapper $out/lib/claude-desktop/claude-desktop $out/bin/claude-desktop \
      "''${gappsWrapperArgs[@]}" \
      --prefix PATH : ${lib.makeBinPath [ nodejs uv ]} \
      --add-flags "--disable-setuid-sandbox" \
      --add-flags "--ozone-platform-hint=auto" \
      --add-flags "--enable-features=WaylandWindowDecorations"
  '';

  meta = {
    description = "Claude Desktop — official Anthropic app for Linux (beta), repackaged from the .deb";
    homepage = "https://claude.com/download";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "claude-desktop";
    platforms = [ "x86_64-linux" ];
  };
})
