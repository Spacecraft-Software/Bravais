# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Plymouth boot splash: assets/boot/splash.png shown as a
# still image by a Plymouth `script` theme.
#
# The script plugin loads PNG only, so any other source format would need
# converting; the image is re-encoded here in any case. The theme is copied
# into EVERY initrd, and the 196 MiB ESP keeps three of them (constraint
# #42), so the image is budgeted: scaled down to at most `width` (never up —
# that would only add bytes) and palette-quantized by steelbore-quantize
# (pkgs/steelbore-quantize: the Rust imagequant crate, no C). The script scales it to fit the screen. Check the size
# with `nix path-info -Sh .#steelbore-plymouth` after changing the image or
# the width, then measure the built initrd (constraint #43).
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

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "steelbore-plymouth";
  version = "2.2.0";

  src = ../../assets/boot/splash.png;
  dontUnpack = true;

  nativeBuildInputs = [
    ffmpeg-headless
    steelbore-quantize
  ];

  passthru.themeName = "steelbore";

  buildPhase = ''
    runHook preBuild

    ffmpeg -loglevel error -i "$src" -vf "scale='min(${toString width},iw)':-2" splash.png
    steelbore-quantize --quality 70-90 splash.png splash.png

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    dir=$out/share/plymouth/themes/${finalAttrs.passthru.themeName}
    mkdir -p "$dir"
    cp splash.png "$dir/"

    # Name= is the theme's own name (it matches themeName, the directory
    # Plymouth selects it by), not the OS name, so it stays "Steelbore";
    # Description= is where the OS is named, and that comes from the identity.
    cat > "$dir/${finalAttrs.passthru.themeName}.plymouth" <<EOF
    [Plymouth Theme]
    Name=Steelbore
    Description=${steelboreIdentity.name} boot splash
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
    description = "${steelboreIdentity.name} Plymouth theme showing the boot splash image";
    license = lib.licenses.cc-by-sa-40;
    platforms = lib.platforms.linux;
  };
})
