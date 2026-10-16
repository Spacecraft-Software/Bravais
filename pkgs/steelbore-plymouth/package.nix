# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Plymouth splash: assets/boot/splash.mp4 played as an
# animation at boot, assets/boot/shutdown.mp4 at shutdown and reboot, both by
# one Plymouth `script` theme (it branches on Plymouth.GetMode();
# plymouth-{poweroff,halt}.service run `--mode=shutdown`,
# plymouth-reboot.service `--mode=reboot`).
#
# Plymouth cannot decode video, so each clip is cut into PNG frames at build
# time. The theme is copied into EVERY initrd, and the 196 MiB ESP keeps three
# of them (constraint #42), so the frames are budgeted hard (#43). Only the
# progress bar, the caption and the dots under the logo move in either clip,
# so each ships ONE full frame as the backdrop plus a sequence of `strip`
# crops of the moving band, composited by the script -- 3.5 MiB for both
# clips at their full resolution, against 4.8 MiB for the 2026-10-05 boot
# clip's whole frames alone at 480 px. A new clip must be re-checked for
# where it moves: `bbox` over `tblend=all_mode=difference` per frame, then
# set `strip` (shared by both clips: they use one layout).
#
# Each clip plays once, then loops from its `loopFrom` to its end (the bar is
# full by then; only the dots cycle), so a long boot or shutdown never
# freezes or rewinds the bar. The shutdown clip is cut at `until`: after it
# the caption vanishes, the bar collapses and the whole scene fades to black,
# and a splash cannot know when the power will actually go -- a fade that
# finished early would look like the machine was already off. Check the size
# with `nix path-info -Sh .#steelbore-plymouth` after changing a clip, `fps`,
# `strip` or a loop point, then measure the built initrd (constraint #43).
#
# pkgs/steelbore-ksplash plays the boot frames as the Plasma splash, so the
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
  # Per clip: where the loop restarts once it has played through, and (for
  # shutdown) where the clip is cut, both in seconds. Not named plain `boot`
  # or `shutdown`: callPackage would fill a name nixpkgs also uses (there is a
  # `pkgs.boot`) with that package, silently -- the trap noted below.
  bootClip ? {
    loopFrom = 5;
  },
  shutdownClip ? {
    loopFrom = 5;
    until = 8.5;
  },
  # The moving band, in the clips' own pixels (both are 1280x720).
  strip ? {
    x = 440;
    y = 552;
    width = 400;
    height = 136;
  },
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
  # 1-based frame a loop restarts at, as Plymouth and QML both count.
  loopStartOf = clip: clip.loopFrom * fps + 1;

  crop = "crop=${toString strip.width}:${toString strip.height}:${toString strip.x}:${toString strip.y}";

  # Cut one clip into `<prefix>background.png` plus `<prefix>strip-N.png`,
  # quantize them, and leave its frame count in `$<countVar>`. The boot
  # names carry no prefix: steelbore-ksplash copies them by those names.
  cut =
    {
      src,
      prefix,
      clip,
      countVar,
    }:
    ''
      # The first frame is the backdrop; the strip frames cover its band.
      ffmpeg -loglevel error -i "${src}" -frames:v 1 ${prefix}background.png
      # -an: no audio reaches the theme (Plymouth has no audio path).
      ffmpeg -loglevel error -i "${src}" -an \
        ${lib.optionalString (clip ? until) "-t ${toString clip.until}"} \
        -vf "fps=${toString fps},${crop}" ${prefix}strip-%d.png
      for f in ${prefix}background.png ${prefix}strip-*.png; do
        steelbore-quantize --quality 60-85 "$f" "$f" > /dev/null
      done
      ${countVar}=$(find . -maxdepth 1 -name '${prefix}strip-*.png' | wc -l)
      if [ "''$${countVar}" -lt ${toString (loopStartOf clip)} ]; then
        echo "${src}: ''$${countVar} frames, fewer than loopFrom (${toString clip.loopFrom} s) needs" >&2
        exit 1
      fi
    '';
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "steelbore-plymouth";
  version = "4.0.0";

  dontUnpack = true;

  nativeBuildInputs = [
    ffmpeg-headless
    steelbore-quantize
  ];

  passthru = {
    themeName = "steelbore";
    # Everything a second player needs to composite the boot frames
    # identically.
    animation = {
      inherit fps strip;
      loopStart = loopStartOf bootClip;
      dir = "share/plymouth/themes/${finalAttrs.passthru.themeName}";
    };
  };

  buildPhase = ''
    runHook preBuild

    ${cut {
      src = ../../assets/boot/splash.mp4;
      prefix = "";
      clip = bootClip;
      countVar = "bootCount";
    }}
    ${cut {
      src = ../../assets/boot/shutdown.mp4;
      prefix = "shutdown-";
      clip = shutdownClip;
      countVar = "shutdownCount";
    }}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    dir=$out/${finalAttrs.passthru.animation.dir}
    mkdir -p "$dir"
    cp ./*.png "$dir/"

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

    // One frame set per mode: the boot clip, or the shutdown clip at
    // poweroff, halt and reboot.
    mode = Plymouth.GetMode();
    if (mode == "shutdown" || mode == "reboot") {
      prefix = "shutdown-";
      frame_count = $shutdownCount;
      loop_start = ${toString (loopStartOf shutdownClip)};
    } else {
      prefix = "";
      frame_count = $bootCount;
      loop_start = ${toString (loopStartOf bootClip)};
    }
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
        global.strip.SetImage(Image(global.prefix + "strip-" + frame + ".png").Scale(global.strip_w, global.strip_h));
        global.shown = frame;
      }
    }

    // Fit the whole image on screen, centred; the canvas colour fills any
    // letterbox left by a screen whose aspect differs from the image's.
    canvas = Image(prefix + "background.png");
    scale = Math.Min(Window.GetWidth() / canvas.GetWidth(), Window.GetHeight() / canvas.GetHeight());
    w = Math.Int(canvas.GetWidth() * scale);
    h = Math.Int(canvas.GetHeight() * scale);
    x0 = Window.GetX() + Math.Int((Window.GetWidth() - w) / 2);
    y0 = Window.GetY() + Math.Int((Window.GetHeight() - h) / 2);

    backdrop = Sprite(canvas.Scale(w, h));
    backdrop.SetX(x0);
    backdrop.SetY(y0);
    backdrop.SetZ(0);

    // The backdrop is the clip's own size, so the strip's clip-pixel
    // offsets take the same scale.
    strip_w = Math.Int(${toString strip.width} * scale);
    strip_h = Math.Int(${toString strip.height} * scale);
    strip = Sprite(Image(prefix + "strip-1.png").Scale(strip_w, strip_h));
    strip.SetX(x0 + Math.Int(${toString strip.x} * scale));
    strip.SetY(y0 + Math.Int(${toString strip.y} * scale));
    strip.SetZ(1);
    tick = 0;
    shown = 1;
    Plymouth.SetRefreshFunction(refresh_callback);
    EOF

    runHook postInstall
  '';

  meta = {
    description = "${steelboreIdentity.name} Plymouth theme: boot and shutdown animations";
    license = lib.licenses.cc-by-sa-40;
    platforms = lib.platforms.linux;
  };
})
