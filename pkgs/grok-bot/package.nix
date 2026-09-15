# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Grok Bot desktop agent (official .deb, repackaged)
#
# Not in nixpkgs on either channel (checked 26.05 and unstable — the only
# `grok` attribute is `grok-cli` 0.0.33, an unrelated terminal client). So this
# is the delivery policy's fallback case, not a preference.
#
# Published by Cursor/Anysphere, not by xAI, despite the name: the control file
# reads `Vendor: SpaceXAI <hi@cursor.com>` with `Homepage: https://cursor.com`,
# and the artifact is served from Cursor's own CDN. It also declares
# `Conflicts/Provides/Replaces: sand` and registers an `x-scheme-handler/sand`
# URL scheme, `sand` evidently being the pre-release codename — do not "fix"
# either to `grok-bot`, they are upstream's identifiers.
#
# Standard Electron .deb: app tree under /opt, a launcher symlink the postinst
# makes, hicolor icons and one desktop entry.
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
  pname = "grok-bot";
  version = "0.47.0";

  # The path carries an opaque BUILD hash that is not derivable from the
  # version, so a bump is two edits, not one — see pkgs/update-vendored.nu.
  # Strip the `?_gl=...` analytics parameter off any URL copied from the
  # download page; it is a Google Analytics linker token, not part of the
  # artifact address, and it would make the fetch unreproducible.
  src = fetchurl {
    url =
      "https://downloads.cursor.com/grokbot/stable/"
      + "c1e7d7a46549956d25f53e9c0b9f59666e03aa3a/linux/x64/"
      + "grok-bot_${finalAttrs.version}_amd64.deb";
    hash = "sha256-EcoPUaU1uXr1GjUq35wPns0uGwQwpprpRRtoinoGWAg=";
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

  # Wrapped by hand in postFixup; let wrapGAppsHook3 only collect
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

    # Upstream's directory is "Grok Bot", with a space. Landed here without
    # one: nothing inside resolves by that name (Electron finds app.asar and
    # chrome-sandbox relative to the executable), and every later reference —
    # wrapper, desktop Exec, any future debugging — stops needing quotes.
    cp -r "opt/Grok Bot" $out/lib/grok-bot

    cp -r usr/share/icons $out/share/
    install -Dm644 usr/share/applications/grok-bot.desktop \
      $out/share/applications/grok-bot.desktop

    runHook postInstall
  '';

  postFixup = ''
    # Chromium dlopen()s "libEGL.so.1" from the *bundled* ANGLE libEGL.so
    # rather than from the main binary, and DT_RUNPATH is not transitive, so
    # the runtimeDependencies rpath is invisible to that dlopen. LD_LIBRARY_PATH
    # is searched whichever object issues the dlopen, and is inherited by the
    # re-exec'd GPU process. Dispatch libraries only — the vendor driver must
    # keep coming from /run/opengl-driver.
    makeWrapper $out/lib/grok-bot/grok-bot $out/bin/grok-bot \
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

    # The shipped Exec is the bare name `grok-bot`, which only resolves because
    # the postinst symlinks it into /usr/bin. Point it at the wrapper instead —
    # the unwrapped binary would start but with no GTK schemas and no EGL.
    substituteInPlace $out/share/applications/grok-bot.desktop \
      --replace-fail "Exec=grok-bot" "Exec=$out/bin/grok-bot"
  '';

  meta = {
    description = "Grok Bot — desktop agent, repackaged from the official .deb";
    homepage = "https://cursor.com";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "grok-bot";
    platforms = [ "x86_64-linux" ];
  };
})
