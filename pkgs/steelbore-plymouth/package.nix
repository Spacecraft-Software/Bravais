# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Plymouth splash: assets/boot/splash.mp4 played as an
# animation at boot, assets/boot/shutdown.png shown as a still at shutdown
# and reboot, both by one Plymouth `script` theme (it branches on
# Plymouth.GetMode(); plymouth-{poweroff,halt}.service run `--mode=shutdown`,
# plymouth-reboot.service `--mode=reboot`).
#
# Plymouth cannot decode video, so the clip is cut into PNG frames at build
# time. The theme is copied into EVERY initrd, and the 196 MiB ESP keeps three
# of them (constraint #42), so the frames are budgeted hard (#43). Only the
# progress bar and the dots under the logo move in this clip, so the theme
# ships ONE full frame as the backdrop plus a sequence of `strip` crops of the
# moving band, composited by the script — 2.1 MiB with the shutdown still,
# at the clip's full resolution, against 4.8 MiB for the 2026-10-05 clip's
# whole frames at 480 px. A new clip
# must be re-checked for where it moves: accumulate
# `tblend=all_mode=difference,tmix` over it and look, then set `strip`.
#
# The clip plays once, then loops from `loopFrom` to the end (the bar is full
# by then; only the dots cycle), so a long boot never freezes or rewinds the
# bar. Check the size with `nix path-info -Sh .#steelbore-plymouth` after
# changing the clip, `fps`, `strip` or `loopFrom`, then measure the built
# initrd (constraint #43).
#
# pkgs/steelbore-ksplash plays these same frames as the Plasma splash, so the
# two cannot drift; it reads `passthru.animation`.
{
  lib,
  stdenvNoCC,
  ffmpeg-headless,
  steelbore-quantize,
  # sRGB float channels ("0.15294118") of the canvas around the image;
  # modules/theme/boot-splash.nix passes the active palette's `background`.
  background ? {
    red = "0.0";
    green = "0.0";
    blue = "0.0";
  },
  fps ? 12,
  # Seconds into the clip where the loop restarts once it has played through.
  loopFrom ? 5,
  # The moving band, in the clip's own pixels (it is 1280x720).
  strip ? {
    x = 440;
    y = 552;
    width = 400;
    height = 136;
  },
  # The shutdown still is scaled down to at most this width (never up).
  width ? 1920,
  # The OS identity (lib/identity.nix). Packages get no specialArgs, so the
  # default imports the file directly; an argument rather than a `let` so a
  # caller can override it like `background`. Supplies the OS name in the
  # theme Description and meta, which used to be literals. NOT named plain
  # `identity`: callPackage auto-fills any argument that names a nixpkgs
  # attribute, and `pkgs.identity` is a package, so the default would be
  # silently replaced by its store name ("identity-26.03 boot splash").
  steelboreIdentity ? import ../../lib/identity.nix,
}:

let
  # 1-based frame the loop restarts at, as Plymouth and QML both count.
  loopStart = loopFrom * fps + 1;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "steelbore-plymouth";
  version = "3.0.0";

  clip = ../../assets/boot/splash.mp4;
  still = ../../assets/boot/shutdown.png;
  dontUnpack = true;

  nativeBuildInputs = [
    ffmpeg-headless
    steelbore-quantize
  ];

  passthru = {
    themeName = "steelbore";
    # Everything a second player needs to composite the frames identically.
    animation = {
      inherit fps loopStart strip;
      dir = "share/plymouth/themes/${finalAttrs.passthru.themeName}";
    };
  };

  buildPhase = ''
    runHook preBuild

    # The first frame is the backdrop; the strip frames cover its band.
    ffmpeg -loglevel error -i "$clip" -frames:v 1 background.png
    # -an: the clip's audio never reaches the theme (Plymouth has no audio path).
    ffmpeg -loglevel error -i "$clip" -an \
      -vf "fps=${toString fps},crop=${toString strip.width}:${toString strip.height}:${toString strip.x}:${toString strip.y}" \
      strip-%d.png
    ffmpeg -loglevel error -i "$still" -vf "scale='min(${toString width},iw)':-2" shutdown.png

    for f in background.png shutdown.png strip-*.png; do
      steelbore-quantize --quality 60-85 "$f" "$f" > /dev/null
    done
    frameCount=$(find . -maxdepth 1 -name 'strip-*.png' | wc -l)
    if [ "$frameCount" -lt ${toString loopStart} ]; then
      echo "the clip has $frameCount frames, fewer than loopFrom (${toString loopFrom} s) needs" >&2
      exit 1
    fi

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    dir=$out/${finalAttrs.passthru.animation.dir}
    mkdir -p "$dir"
    cp background.png shutdown.png strip-*.png "$dir/"

    # Name= is the theme's own name (it matches themeName, the directory
    # Plymouth selects it by), not the OS name, so it stays "Steelbore";
    # Description= is where the OS is named, and that comes from the identity.
    cat > "$dir/${finalAttrs.passthru.themeName}.plymouth" <<EOF
    [Plymouth Theme]
    Name=Steelbore
    Description=${steelboreIdentity.name} boot and shutdown splash
    ModuleName=script

    [script]
    ImageDir=$dir
    ScriptFile=$dir/${finalAttrs.passthru.themeName}.script
    EOF

    cat > "$dir/${finalAttrs.passthru.themeName}.script" <<EOF
    Window.SetBackgroundTopColor(${background.red}, ${background.green}, ${background.blue});
    Window.SetBackgroundBottomColor(${background.red}, ${background.green}, ${background.blue});

    frame_count = $frameCount;
    loop_start = ${toString loopStart};
    fps = ${toString fps};
    // The script plugin calls the refresh function at a fixed 50 Hz.
    refresh_hz = 50;

    // Plays the clip once, then loops loop_start..frame_count. Loads and
    // scales one strip frame per change rather than holding all of them.
    fun refresh_callback() {
      global.tick = global.tick + 1;
      frame = Math.Int(global.tick * global.fps / global.refresh_hz) + 1;
      if (frame > global.frame_count) {
        span = global.frame_count - global.loop_start + 1;
        offset = frame - global.loop_start;
        frame = global.loop_start + offset - Math.Int(offset / span) * span;
      }
      if (frame != global.shown) {
        global.strip.SetImage(Image("strip-" + frame + ".png").Scale(global.strip_w, global.strip_h));
        global.shown = frame;
      }
    }

    mode = Plymouth.GetMode();
    if (mode == "shutdown" || mode == "reboot")
      canvas = Image("shutdown.png");
    else
      canvas = Image("background.png");

    // Fit the whole image on screen, centred; the canvas colour fills any
    // letterbox left by a screen whose aspect differs from the image's.
    scale = Math.Min(Window.GetWidth() / canvas.GetWidth(), Window.GetHeight() / canvas.GetHeight());
    w = Math.Int(canvas.GetWidth() * scale);
    h = Math.Int(canvas.GetHeight() * scale);
    x0 = Window.GetX() + Math.Int((Window.GetWidth() - w) / 2);
    y0 = Window.GetY() + Math.Int((Window.GetHeight() - h) / 2);

    backdrop = Sprite(canvas.Scale(w, h));
    backdrop.SetX(x0);
    backdrop.SetY(y0);
    backdrop.SetZ(0);

    if (mode != "shutdown" && mode != "reboot") {
      // background.png is the clip's own size, so the strip's clip-pixel
      // offsets take the same scale.
      strip_w = Math.Int(${toString strip.width} * scale);
      strip_h = Math.Int(${toString strip.height} * scale);
      strip = Sprite(Image("strip-1.png").Scale(strip_w, strip_h));
      strip.SetX(x0 + Math.Int(${toString strip.x} * scale));
      strip.SetY(y0 + Math.Int(${toString strip.y} * scale));
      strip.SetZ(1);
      tick = 0;
      shown = 1;
      Plymouth.SetRefreshFunction(refresh_callback);
    }
    EOF

    runHook postInstall
  '';

  meta = {
    description = "${steelboreIdentity.name} Plymouth theme: boot animation and shutdown splash";
    license = lib.licenses.cc-by-sa-40;
    platforms = lib.platforms.linux;
  };
})
