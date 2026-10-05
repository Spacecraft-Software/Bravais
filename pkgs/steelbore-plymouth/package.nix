# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Plymouth boot splash: assets/boot/splash.mp4 played once
# as a frame sequence by a Plymouth `script` theme.
#
# Plymouth cannot decode video, so the clip is cut into PNG frames at build
# time. The theme is copied into EVERY initrd, and the 196 MiB ESP keeps three
# of them (constraint #42), so the frames are budgeted hard: 12 fps, 480 px
# wide, palette-quantized — under 5 MiB against 80 MiB for the source's 24
# fps at 1280 px. The script scales them up to the screen. Check the size with
# `nix path-info -Sh .#steelbore-plymouth` after changing any of the three.
{
  lib,
  stdenvNoCC,
  ffmpeg-headless,
  pngquant,
  # sRGB float channels ("0.15294118") of the canvas behind the video;
  # modules/theme/boot-splash.nix passes the active palette's `background`.
  background ? {
    red = "0.0";
    green = "0.0";
    blue = "0.0";
  },
  fps ? 12,
  width ? 480,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "steelbore-plymouth";
  version = "1.0.0";

  src = ../../assets/boot/splash.mp4;
  dontUnpack = true;

  nativeBuildInputs = [
    ffmpeg-headless
    pngquant
  ];

  passthru.themeName = "steelbore";

  buildPhase = ''
    runHook preBuild

    mkdir frames
    # -an: the clip's audio never reaches the theme (Plymouth has no audio path).
    ffmpeg -loglevel error -i "$src" -an \
      -vf "fps=${toString fps},scale=${toString width}:-2" frames/frame-%d.png
    pngquant --force --ext .png --quality 60-85 frames/*.png
    frameCount=$(find frames -name 'frame-*.png' | wc -l)

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    dir=$out/share/plymouth/themes/${finalAttrs.passthru.themeName}
    mkdir -p "$dir"
    cp frames/*.png "$dir/"

    cat > "$dir/${finalAttrs.passthru.themeName}.plymouth" <<EOF
    [Plymouth Theme]
    Name=Steelbore
    Description=Steelbore OS boot animation
    ModuleName=script

    [script]
    ImageDir=$dir
    ScriptFile=$dir/${finalAttrs.passthru.themeName}.script
    EOF

    cat > "$dir/${finalAttrs.passthru.themeName}.script" <<EOF
    Window.SetBackgroundTopColor(${background.red}, ${background.green}, ${background.blue});
    Window.SetBackgroundBottomColor(${background.red}, ${background.green}, ${background.blue});

    frame_count = $frameCount;
    fps = ${toString fps};
    // The script plugin calls the refresh function at a fixed 50 Hz.
    refresh_hz = 50;

    first = Image("frame-1.png");
    scale = Math.Min(Window.GetWidth() / first.GetWidth(), Window.GetHeight() / first.GetHeight());
    w = Math.Int(first.GetWidth() * scale);
    h = Math.Int(first.GetHeight() * scale);

    sprite = Sprite(first.Scale(w, h));
    sprite.SetX(Window.GetX() + Math.Int((Window.GetWidth() - w) / 2));
    sprite.SetY(Window.GetY() + Math.Int((Window.GetHeight() - h) / 2));

    tick = 0;
    shown = 1;

    // Load and scale one frame at a time: holding all of them scaled to the
    // screen would cost ~8 MiB each. Plays once, then holds the last frame.
    fun refresh_callback() {
      global.tick = global.tick + 1;
      frame = Math.Int(global.tick * global.fps / global.refresh_hz) + 1;
      if (frame > global.frame_count)
        frame = global.frame_count;
      if (frame != global.shown) {
        global.sprite.SetImage(Image("frame-" + frame + ".png").Scale(global.w, global.h));
        global.shown = frame;
      }
    }

    Plymouth.SetRefreshFunction(refresh_callback);
    EOF

    runHook postInstall
  '';

  meta = {
    description = "Steelbore OS Plymouth theme playing the boot animation";
    license = lib.licenses.cc-by-sa-40;
    platforms = lib.platforms.linux;
  };
})
