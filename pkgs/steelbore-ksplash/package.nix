# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — KDE Plasma splash (ksplashqml): the boot animation
# again, after login, from the very frames the Plymouth theme plays.
#
# ksplashqml loads `contents/splash/Splash.qml` from the Look-and-Feel package
# named by ksplashrc `[KSplash] Theme=`; any file this package lacks falls
# back to Breeze, so it carries only the splash. users/mj/plasma.nix installs
# it under ~/.local/share/plasma/look-and-feel/ and selects it.
#
# The frames are NOT cut a second time: they are copied out of
# steelbore-plymouth, and the geometry, frame rate and loop point come from
# its `passthru.animation`, so the two splashes cannot drift. Same
# compositing as the Plymouth script: one backdrop, the moving strip on top.
# Plain QtQuick only — no QtMultimedia, whose plugins ksplashqml need not
# have — so a Timer steps an Image through the PNG strip frames.
#
# Preview without logging out: `ksplashqml <packageId> --test`.
{
  lib,
  stdenvNoCC,
  steelbore-plymouth,
  # "#RRGGBB" canvas around the image; users/mj/plasma.nix passes the active
  # palette's `background`.
  background ? "#000000",
  # See pkgs/steelbore-plymouth: never named plain `identity`.
  steelboreIdentity ? import ../../lib/identity.nix,
}:

let
  inherit (steelbore-plymouth.passthru) animation;
  packageId = "steelbore-splash";

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
in
stdenvNoCC.mkDerivation {
  pname = "steelbore-ksplash";
  inherit (steelbore-plymouth) version;

  dontUnpack = true;
  passAsFile = [ "metadata" ];
  inherit metadata;

  passthru = { inherit packageId; };

  installPhase = ''
    runHook preInstall

    pkg=$out/share/plasma/look-and-feel/${packageId}
    mkdir -p "$pkg/contents/splash/images"
    cp "$metadataPath" "$pkg/metadata.json"

    frames=${steelbore-plymouth}/${animation.dir}
    cp "$frames"/background.png "$frames"/strip-*.png "$pkg/contents/splash/images/"
    frameCount=$(find "$pkg/contents/splash/images" -name 'strip-*.png' | wc -l)

    cat > "$pkg/contents/splash/Splash.qml" <<EOF
    import QtQuick

    Rectangle {
        id: root
        color: "${background}"

        // Set by ksplashqml as Plasma starts up (Breeze fades on it); the
        // animation runs regardless, and ksplashqml closes the window itself.
        property int stage

        readonly property int frameCount: $frameCount
        readonly property int loopStart: ${toString animation.loopStart}

        // The clip's first frame, fitted and centred; the colour above fills
        // any letterbox.
        Image {
            id: backdrop
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            source: "images/background.png"

            // Clip pixels to screen pixels, and the painted image's origin.
            readonly property real fit: paintedWidth / implicitWidth
            readonly property real originX: (width - paintedWidth) / 2
            readonly property real originY: (height - paintedHeight) / 2
        }

        // The moving band, laid exactly over the backdrop's copy of it.
        Image {
            id: strip
            property int frame: 1
            x: backdrop.originX + ${toString animation.strip.x} * backdrop.fit
            y: backdrop.originY + ${toString animation.strip.y} * backdrop.fit
            width: ${toString animation.strip.width} * backdrop.fit
            height: ${toString animation.strip.height} * backdrop.fit
            // Synchronous, so a frame change never blanks the band.
            asynchronous: false
            source: "images/strip-" + frame + ".png"
        }

        // Plays the clip once, then loops loopStart..frameCount, as the
        // Plymouth theme does.
        Timer {
            interval: Math.round(1000 / ${toString animation.fps})
            repeat: true
            running: true
            onTriggered: strip.frame = strip.frame < root.frameCount ? strip.frame + 1 : root.loopStart
        }
    }
    EOF

    runHook postInstall
  '';

  meta = {
    description = "${steelboreIdentity.name} KDE Plasma splash screen playing the boot animation";
    license = lib.licenses.cc-by-sa-40;
    platforms = lib.platforms.linux;
  };
}
