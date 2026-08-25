# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — OpenAI Codex Desktop (official ChatGPT/Codex app, repackaged .deb)
#
# OpenAI ships the Codex desktop app for Linux as a .deb whose package name is
# `chatgpt` (binary `chatgpt`, app dir /usr/lib/chatgpt, launcher
# `codex-launcher`). The pname here follows this tree's convention —
# claude-desktop, goose-desktop, opencode-desktop — rather than upstream's
# `chatgpt`, because what it is here is the Codex app.
#
# UPSTREAM OFFERS NO VERSIONED URL. Every other vendored binary in this tree
# pins a URL containing its version, so the exact artifact can always be
# refetched. OpenAI publishes only `…/linux/deb/latest/chatgpt_amd64.deb`, so
# the moment they push a new build this hash stops matching AND the pinned
# build becomes unfetchable — there is no archive path to fall back to. The
# `version` below is read out of the .deb's own control file and is therefore
# descriptive, not part of the URL. Expect this package to break on upstream's
# schedule rather than on ours; `nu pkgs/update-vendored.nu codex-desktop` is
# the fix.
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
  libusb1,
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
  pname = "codex-desktop";
  version = "26.820.60940";

  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb";
    hash = "sha256-MdlWqMbFFfjYfgt6zZ7JGffmhbpZMxtLl6pF+FOv39c=";
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
    libusb1 # node-hid / @serialport native addons (see Depends: libusb-1.0-0)
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

  # libqt5_shim.so / libqt6_shim.so are Electron's OPTIONAL Qt integration --
  # native Qt file dialogs and window decorations when running under a Qt
  # desktop. Electron dlopen()s them and falls back to GTK when the load fails,
  # so an unsatisfied Qt link is a downgrade in dialog styling under Plasma, not
  # a broken app. Ignored rather than satisfied because satisfying it means
  # dragging all of Qt5 AND Qt6 into the closure of a GTK/Electron app for a
  # cosmetic path; ignored rather than deleted so that a future decision to add
  # Qt needs no change here beyond dropping this list.
  autoPatchelfIgnoreMissingDeps = [
    "libQt5Core.so.5"
    "libQt5Gui.so.5"
    "libQt5Widgets.so.5"
    "libQt6Core.so.6"
    "libQt6Gui.so.6"
    "libQt6Widgets.so.6"
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
    cp -r usr/lib/chatgpt $out/lib/
    install -Dm644 usr/share/pixmaps/chatgpt.png $out/share/pixmaps/codex-desktop.png
    install -Dm644 usr/share/applications/chatgpt.desktop \
      $out/share/applications/chatgpt.desktop

    # Alpine/musl prebuilds of the bundled native addons (node-hid, serialport,
    # classic-level). autoPatchelfHook walks everything recursively and fails on
    # them for a glibc host — the same trap as constraint #15's opencode-desktop.
    # Matched by shape rather than by path: these live many node_modules deep
    # (…/@worklouder/device-kit-oai/…/node-hid/prebuilds/…), and a version bump
    # that reshuffles that nesting would silently defeat hardcoded paths.
    find $out/lib/chatgpt -type d -name '*-musl' -prune -exec rm -rf {} +
    find $out/lib/chatgpt -type f -name '*.musl.node' -delete

    runHook postInstall
  '';

  postFixup = ''
    # /usr/bin/chatgpt -> ../lib/chatgpt/codex-launcher, and codex-launcher is a
    # two-line sh shim that execs ./ChatGPT beside it. Wrap the Electron binary
    # directly and drop the shim: the indirection buys nothing once the wrapper
    # supplies an absolute path, and a wrapper around a shim would lose the
    # gappsWrapperArgs on the re-exec.
    makeWrapper $out/lib/chatgpt/ChatGPT $out/bin/codex-desktop \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath [
          libGL
          libgbm
          vulkan-loader
        ]
      }" \
      --add-flags "--ozone-platform-hint=auto" \
      --add-flags "--enable-features=WaylandWindowDecorations"

    substituteInPlace $out/share/applications/chatgpt.desktop \
      --replace-fail "Exec=chatgpt" "Exec=$out/bin/codex-desktop" \
      --replace-fail "Icon=chatgpt" "Icon=codex-desktop"

    # Upstream declares MimeType=x-scheme-handler/http;x-scheme-handler/https
    # plus csv/xls/xlsx/doc/docx/pptx. Shipping that verbatim puts an app that
    # claims to be a WEB BROWSER and a spreadsheet handler into the desktop
    # database, where constraint #22's failure mode -- an unbound or
    # ambiguously-bound type resolved by desktop-entry cache ordering -- can
    # hand it link clicks or a .xlsx. This tree decides handlers in exactly one
    # place (default-apps.nix, one xdg.mimeApps block, the ROLE owning the MIME
    # list), so an app's self-declaration is noise at best and a hijack at
    # worst. Keep only its own deep-link scheme, which nothing else claims.
    substituteInPlace $out/share/applications/chatgpt.desktop \
      --replace-fail \
      "MimeType=x-scheme-handler/codex;x-scheme-handler/http;x-scheme-handler/https;text/csv;application/vnd.openxmlformats-officedocument.wordprocessingml.document;application/vnd.openxmlformats-officedocument.presentationml.presentation;text/tab-separated-values;application/vnd.ms-excel;application/vnd.ms-excel.sheet.macroEnabled.12;application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;" \
      "MimeType=x-scheme-handler/codex;"
  '';

  # Cheap change detector for pkgs/update-vendored.nu. There is no release API
  # and no versioned URL here, and the version string lives INSIDE the .deb's
  # control file — so the only way to answer "is there a new build?" from the
  # URL alone is to download 378 MB. This is the blob ETag from the same HEAD
  # request that `--check` can make for free; when it still matches, nothing has
  # been published and the download is skipped entirely. It is metadata about
  # the pin, not an input to it: changing it cannot change what gets built.
  passthru.upstreamETag = "0x8DF02D871B6175D";

  meta = {
    description = "OpenAI Codex Desktop — official ChatGPT/Codex app for Linux, repackaged from the .deb";
    homepage = "https://developers.openai.com/codex/app";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "codex-desktop";
    platforms = [ "x86_64-linux" ];
  };
})
