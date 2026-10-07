# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Plymouth boot splash: assets/boot/splash.jpeg shown as a
# still image by a Plymouth `script` theme.
#
# The script plugin loads PNG only, so the JPEG is converted at build time.
# The theme is copied into EVERY initrd, and the 196 MiB ESP keeps three of
# them (constraint #42), so the image is budgeted: scaled to `width` and
# palette-quantized. The script scales it to fit the screen. Check the size
# with `nix path-info -Sh .#steelbore-plymouth` after changing the image or
# the width, then measure the built initrd (constraint #43).
{
  lib,
  stdenvNoCC,
  ffmpeg-headless,
  pngquant,
  # sRGB float channels ("0.15294118") of the canvas around the image;
  # modules/theme/boot-splash.nix passes the active palette's `background`.
  background ? {
    red = "0.0";
    green = "0.0";
    blue = "0.0";
  },
  width ? 1920,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "steelbore-plymouth";
  version = "2.0.0";

  src = ../../assets/boot/splash.jpeg;
  dontUnpack = true;

  nativeBuildInputs = [
    ffmpeg-headless
    pngquant
  ];

  passthru.themeName = "steelbore";

  buildPhase = ''
    runHook preBuild

    ffmpeg -loglevel error -i "$src" -vf "scale=${toString width}:-2" splash.png
    pngquant --force --ext .png --quality 70-90 splash.png

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    dir=$out/share/plymouth/themes/${finalAttrs.passthru.themeName}
    mkdir -p "$dir"
    cp splash.png "$dir/"

    cat > "$dir/${finalAttrs.passthru.themeName}.plymouth" <<EOF
    [Plymouth Theme]
    Name=Steelbore
    Description=Steelbore OS boot splash
    ModuleName=script

    [script]
    ImageDir=$dir
    ScriptFile=$dir/${finalAttrs.passthru.themeName}.script
    EOF

    cat > "$dir/${finalAttrs.passthru.themeName}.script" <<EOF
    Window.SetBackgroundTopColor(${background.red}, ${background.green}, ${background.blue});
    Window.SetBackgroundBottomColor(${background.red}, ${background.green}, ${background.blue});

    // Fit the whole image on screen, centred; the canvas colour fills any
    // letterbox left by a screen whose aspect differs from the image's.
    image = Image("splash.png");
    scale = Math.Min(Window.GetWidth() / image.GetWidth(), Window.GetHeight() / image.GetHeight());
    w = Math.Int(image.GetWidth() * scale);
    h = Math.Int(image.GetHeight() * scale);

    sprite = Sprite(image.Scale(w, h));
    sprite.SetX(Window.GetX() + Math.Int((Window.GetWidth() - w) / 2));
    sprite.SetY(Window.GetY() + Math.Int((Window.GetHeight() - h) / 2));
    EOF

    runHook postInstall
  '';

  meta = {
    description = "Steelbore OS Plymouth theme showing the boot splash image";
    license = lib.licenses.cc-by-sa-40;
    platforms = lib.platforms.linux;
  };
})
