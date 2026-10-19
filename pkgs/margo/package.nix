# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — margo: Rust/Smithay port of the mango Wayland compositor
#
# Packaged in-tree rather than taken from upstream's flake: Bravais carries no
# third-party DE flakes, and upstream's `nixosModules.margo` still targets
# `programs.mango` and a `packages.mango` attribute that no longer exists.
#
# Only the compositor half of the workspace is built — `margo` (compositor),
# `mctl` (IPC client and `check-config`) and `start-margo` (crash-budget
# supervisor). The rest of the workspace (the mshell GTK desktop shell, mlock,
# mlogind, mtune and friends) is left out: Bravais already supplies the bar,
# launcher, notifier, locker and login manager from the Niri stack.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  makeWrapper,
  pkg-config,
  wayland-scanner,
  wayland,
  libxkbcommon,
  libinput,
  seatd,
  libgbm,
  libGL,
  libdrm,
  pixman,
  systemd,
  lcms2,
  dbus,
  pipewire,
  xwayland,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "margo";
  version = "4.1.0";

  src = fetchFromGitHub {
    owner = "kenanpelit";
    repo = "margo";
    tag = "v${finalAttrs.version}";
    hash = "sha256-5UKWJOuxU+wbSiWtfecZu5vsDtUNJXTEeLpMGSwhTfM=";
  };

  cargoHash = "sha256-jIN9M5nV42SGpaM5VQhLYhryC5hXd6Rl2RHx0PyS2Wg=";

  cargoBuildFlags = [
    "-p"
    "margo"
    "-p"
    "mctl"
    "-p"
    "start-margo"
  ];

  # The workspace tests want a live Wayland/D-Bus/GPU seat.
  doCheck = false;

  nativeBuildInputs = [
    pkg-config
    wayland-scanner
    makeWrapper
    rustPlatform.bindgenHook # pipewire-sys
  ];

  buildInputs = [
    wayland
    libxkbcommon
    libinput
    seatd
    libgbm
    libGL
    libdrm
    pixman
    systemd # libudev for the smithay udev backend
    lcms2
    dbus
    pipewire
  ];

  # The session runs start-margo, which spawns `margo` and runs
  # `mctl check-config` by bare name; pin both to this package rather than
  # whatever PATH the greeter hands over. margo starts Xwayland on demand.
  postInstall = ''
    wrapProgram $out/bin/start-margo --prefix PATH : $out/bin
    wrapProgram $out/bin/margo --prefix PATH : ${lib.makeBinPath [ xwayland ]}

    install -Dm644 margo/src/config.example.conf $out/share/doc/margo/config.example.conf

    mkdir -p $out/share/wayland-sessions
    cat > $out/share/wayland-sessions/margo.desktop <<EOF
    [Desktop Entry]
    Name=Margo
    Comment=Mango-style tag-based Wayland compositor (Rust/Smithay)
    Exec=$out/bin/start-margo
    TryExec=$out/bin/start-margo
    Type=Application
    DesktopNames=margo
    EOF
  '';

  # Smithay dlopen()s libwayland-server, libwayland-egl and libEGL rather
  # than linking them, so nothing puts them on the RUNPATH and margo exits
  # with "could not load libwayland-server.so" before opening a socket.
  # postFixup, not postInstall: fixupPhase's --shrink-rpath would drop them.
  postFixup = ''
    patchelf --add-rpath ${
      lib.makeLibraryPath [
        wayland
        libGL
      ]
    } $out/bin/.margo-wrapped
  '';

  passthru.providedSessions = [ "margo" ];

  meta = {
    description = "Tag-based Wayland compositor: a Rust/Smithay port of mango (dwl)";
    homepage = "https://github.com/kenanpelit/margo";
    license = lib.licenses.gpl3Plus;
    mainProgram = "margo";
    platforms = lib.platforms.linux;
  };
})
