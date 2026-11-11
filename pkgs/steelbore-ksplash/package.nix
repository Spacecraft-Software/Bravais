# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — KDE Plasma splash (ksplashqml), drawn like Fairing's boot
# splash: the Steelbore logo in the accent role on the canvas, a rounded
# progress bar with a percentage under it, and a line saying what is loading.
#
# ksplashqml loads `contents/splash/Splash.qml` from the Look-and-Feel package
# named by ksplashrc `[KSplash] Theme=`; any file this package lacks falls
# back to Breeze, so it carries only the splash. users/mj/plasma.nix installs
# it under ~/.local/share/plasma/look-and-feel/ and selects it.
#
# GEOMETRY is Fairing's reference theme (themes/steelbore.ncl in the Fairing
# repository) in its 1920x1080 frame, scaled to the screen: logo box 600x257 at
# (660, 290), bar 640x14 at y=640, percentage 28 to its right, status line at 704.
# COLOURS are the same role tokens Fairing draws with — accent for the logo and
# the bar's fill, surface for its track, border for its outline, foreground
# for the text — passed in from the active palette, never retyped.
#
# THE LOGO is assets/brand/steelbore-logo.svg, recoloured to `accent` and
# rasterised at twice its box so QtQuick needs no SVG plugin.
#
# WHAT IT SAYS. ksplashqml hands the QML a `stage` integer, and the Plasma
# source (plasma-workspace ksplash/ksplashqml/splashapp.cpp) numbers it by the
# order the six stages arrive: initial, then wm (Wayland: at once), startPlasma,
# kcminit, ksmserver, and desktop, which closes the splash. On Wayland that
# order is fixed, so the line names what is being loaded NEXT after the stage
# that just finished, and the bar is stage/6. On X11 the window manager reports
# later, so the wording may run one step behind; the bar never moves backwards.
#
# Preview without logging out: `ksplashqml <packageId> --test` steps a stage
# every two seconds.
{
  lib,
  stdenvNoCC,
  resvg,
  # "#RRGGBB" role colours; users/mj/plasma.nix passes the active palette's.
  background ? "#000000",
  accent ? "#ffffff",
  surface ? "#222222",
  border ? "#888888",
  foreground ? "#ffffff",
  # See pkgs/steelbore-plymouth: never named plain `identity`.
  steelboreIdentity ? import ../../lib/identity.nix,
}:

let
  packageId = "steelbore-splash";

  hex = "#[0-9A-Fa-f]{6}";
  roles = { inherit background accent surface border foreground; };

  # Text shown while each stage is the latest to have arrived.
  labels = [
    "Starting KDE Plasma 6"
    "Starting Plasma services"
    "Applying system settings"
    "Starting the session manager"
    "Loading the desktop and panels"
    "Almost ready"
  ];

  metadata = builtins.toJSON {
    KPackageStructure = "Plasma/LookAndFeel";
    KPlugin = {
      Id = packageId;
      Name = "Steelbore Splash";
      Description = "${steelboreIdentity.name} splash screen";
      License = "CC-BY-SA-4.0";
      Website = steelboreIdentity.urls.home;
      Authors = [
        {
          Name = steelboreIdentity.maintainer;
          Email = steelboreIdentity.contact;
        }
      ];
    };
    X-Plasma-APIVersion = "2";
  };

  qmlString = s: builtins.toJSON s;

  splashQml = ''
    import QtQuick

    Rectangle {
        id: root
        color: ${qmlString background}

        // Set by ksplashqml as Plasma starts up: 1 .. 6, the number of
        // distinct stages that have reported. Stage 6 closes the splash.
        property int stage: 0

        readonly property var labels: ${builtins.toJSON labels}
        readonly property real target: Math.min(Math.max(stage, 1), 6) / 6
        // Never backwards, whatever order the stages arrive in.
        property real progress: 0
        onTargetChanged: if (target > progress) progress = target
        Component.onCompleted: progress = target

        // Fairing's 1920x1080 reference frame, fitted and centred.
        readonly property real s: Math.min(width / 1920, height / 1080)
        readonly property real ox: (width - 1920 * s) / 2
        readonly property real oy: (height - 1080 * s) / 2

        Image {
            x: root.ox + 660 * root.s
            y: root.oy + 290 * root.s
            width: 600 * root.s
            height: 257 * root.s
            source: "images/logo.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        // Track, fill and outline of the bar: 640x14, fully rounded.
        Rectangle {
            id: track
            x: root.ox + 640 * root.s
            y: root.oy + 640 * root.s
            width: 640 * root.s
            height: 14 * root.s
            radius: height / 2
            color: ${qmlString surface}
            border.color: ${qmlString border}
            border.width: Math.max(1, 1.5 * root.s)
            clip: true

            Rectangle {
                height: parent.height
                width: Math.max(parent.height, parent.width * root.progress)
                radius: height / 2
                color: ${qmlString accent}
                Behavior on width {
                    NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
                }
            }
        }

        // Beside the bar, 28 px past its right end, centred on it.
        Text {
            x: track.x + track.width + 28 * root.s
            y: track.y + (track.height - height) / 2
            color: ${qmlString foreground}
            font.pixelSize: Math.round(30 * root.s)
            text: Math.round(root.progress * 100) + "%"
        }

        Text {
            x: root.ox
            width: 1920 * root.s
            y: root.oy + 704 * root.s
            horizontalAlignment: Text.AlignHCenter
            color: ${qmlString foreground}
            font.pixelSize: Math.round(26 * root.s)
            text: root.labels[Math.min(Math.max(root.stage, 1), 6) - 1]
        }
    }
  '';
in

assert lib.assertMsg (lib.all (v: builtins.match hex v != null) (
  lib.attrValues roles
)) "steelbore-ksplash: every colour must be \"#RRGGBB\", got ${builtins.toJSON roles}";

stdenvNoCC.mkDerivation {
  pname = "steelbore-ksplash";
  version = "2.0.0";

  dontUnpack = true;

  nativeBuildInputs = [ resvg ];

  passAsFile = [
    "metadata"
    "splashQml"
  ];
  inherit metadata splashQml;

  passthru = { inherit packageId; };

  installPhase = ''
    runHook preInstall

    pkg=$out/share/plasma/look-and-feel/${packageId}
    mkdir -p "$pkg/contents/splash/images"
    cp "$metadataPath" "$pkg/metadata.json"
    cp "$splashQmlPath" "$pkg/contents/splash/Splash.qml"

    # The logo's own fill is a near-black navy; Fairing draws it in `accent`.
    sed 's/fill="#000027"/fill="${accent}"/g' ${../../assets/brand/steelbore-logo.svg} > logo.svg
    resvg --width 1200 logo.svg "$pkg/contents/splash/images/logo.png"

    runHook postInstall
  '';

  meta = {
    description = "${steelboreIdentity.name} KDE Plasma splash screen, styled like the Fairing boot splash";
    license = lib.licenses.cc-by-sa-40;
    platforms = lib.platforms.linux;
  };
}
