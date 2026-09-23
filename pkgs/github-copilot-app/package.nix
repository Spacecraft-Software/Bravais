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
  wrapGAppsHook3,
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
  version = "1.1.23";

  src = fetchurl {
    url = "https://github.com/github/app/releases/download/v${finalAttrs.version}/GitHub-Copilot-linux-x64.deb";
    hash = "sha256-HWNnLEliPzGzq8YySicZHNJqzoUr+9PxsRWdCw3pBmM=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
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

  dontWrapGApps = true;
  dontConfigure = true;
  dontBuild = true;

  # MANDATORY — without this the app dies before `main` with
  #   Inconsistency detected by ld.so: ../sysdeps/x86_64/dl-machine.h: 498:
  #   elf_machine_rela_relative: Assertion `ELFW(R_TYPE) (reloc->r_info) ==
  #   R_X86_64_RELATIVE' failed!
  # and, launched from the app menu, simply does nothing at all.
  #
  # `usr/bin/github` is a PIE with 155 677 dynamic relocations, shipped
  # UNSTRIPPED at 1003 MB. autoPatchelfHook has to relocate
  # `.dynstr`/`.rela.dyn`/`.dynamic` into fresh LOAD segments at the end of
  # the file to fit the store RUNPATH -- and it cannot do that correctly on a
  # STRIPPED copy of this binary. The result has exactly the first 16 bytes of
  # the moved `.rela.dyn` clobbered -- r_offset and r_info of entry 0 --
  # leaving that entry's addend and all 155 676 following entries intact.
  # glibc walks the first DT_RELACOUNT (154 824) entries down a fast path that
  # asserts every one is R_X86_64_RELATIVE, so one bad entry at index 0 aborts
  # the process.
  #
  # The order is strip-then-patchelf, not the reverse: nixpkgs strips in the
  # per-output `fixupOutput` pass while autoPatchelfHook registers itself in
  # `postFixupHooks`, which runs after it. So patchelf is the writer here and
  # the stripped input is what defeats it.
  #
  # That tiny blast radius is what makes this so misleading: nothing fails at
  # build time, `readelf -d` looks correct, RELA lands exactly inside the last
  # LOAD segment, and the corruption is 16 bytes in a 369 MB file. Restoring
  # just those 16 bytes by hand was enough to make the app start, which is how
  # this was confirmed rather than guessed.
  #
  # The cost is real and is NOT negligible: the binary goes from 369 MB
  # stripped to 1003 MB, so this trades ~634 MB of disk for an app that runs
  # at all. Worth knowing on a machine where /nix shares a 203 GiB partition
  # (AGENTS.md constraint #28).
  #
  # Do NOT try to win that back by stripping earlier, in `preFixup`. That was
  # measured on 2026-09-12 and it reproduces the failure EXACTLY -- entry 0
  # comes out as the same (0x24, 0x4, 0xe09d9e0) and the binary aborts in
  # ld.so identically -- which is the result that established the direction
  # above. Stripping this binary at any point before autoPatchelfHook breaks
  # it; there is no ordering that gives both a small binary and a working one.
  dontStrip = true;

  # EXPERIMENT: strip before autoPatchelfHook instead of leaving it unstripped.
  preFixup = ''
    strip -S $out/bin/github
  '';

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile $src | tar -x --no-same-permissions --no-same-owner
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib $out/share

    # Main launcher binary + credential helper
    cp usr/bin/github $out/bin/
    cp usr/bin/git-credential-copilot $out/bin/

    # App bundle (Tauri runtime, native plugins, terminal integration, .so libs).
    # `cp -r src dest/` where dest already exists copies src *inside* dest, so
    # the result is $out/lib/GitHub Copilot/ (preserving the upstream layout).
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
    # gappsWrapperArgs sets GSETTINGS_SCHEMAS_DIR (GLib schemas),
    # GDK_PIXBUF_MODULE_FILE (pixbuf loaders), and XDG_DATA_DIRS.
    # Prefix LD_LIBRARY_PATH with BOTH $out/lib (bundled .sos resolved here
    # by autoPatchelfHook RPATH) AND the "GitHub Copilot" subdir (original
    # upstream layout — the Tauri runtime may dlopen from there at runtime).
    makeWrapper $out/bin/github $out/bin/github-copilot \
      --prefix LD_LIBRARY_PATH : "$out/lib/GitHub Copilot" \
      --prefix LD_LIBRARY_PATH : $out/lib \
      --set-default WEBKIT_DISABLE_DMABUF_RENDERER 1 \
      "''${gappsWrapperArgs[@]}"
    # The upstream desktop file ships with Exec=github (the unwrapped
    # binary). Point it to the wrapper so LD_LIBRARY_PATH and the GTK
    # environment are set when launched from the app menu.
    substituteInPlace $out/share/applications/github-copilot.desktop \
      --replace-fail "Exec=github" "Exec=github-copilot"
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
