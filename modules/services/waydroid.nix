# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Waydroid (Android in an LXC container, on Wayland)
#
# Runs a full Android userspace in a container against the host kernel, for
# running Android apps and for testing your own without a physical handset.
# Complements steelbore.hardware.android (modules/hardware/android.nix), which
# is the *device* half — adb to a real phone. Neither needs the other.
#
# Filed under services.* rather than hardware.*: what this enables is a
# long-running containerised system service (waydroid-container.service), in
# the same family as podman and ollama. No device is involved.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.steelbore.services.waydroid = {
    enable = lib.mkEnableOption "Waydroid — Android apps in an LXC container";
  };

  config = lib.mkIf config.steelbore.services.waydroid.enable {
    # Brings up waydroid-container.service, the LXC plumbing and the binderfs
    # mount. It does NOT download an Android image — see the note below.
    virtualisation.waydroid.enable = true;

    # `waydroid` needs an Android system image before it will start, and that
    # image is a multi-hundred-MB download from SourceForge that no NixOS option
    # fetches for you. It is therefore a deliberate ONE-TIME imperative step,
    # not a gap in this module:
    #
    #   sudo waydroid init            # GAPPS variant: sudo waydroid init -s GAPPS
    #   systemctl start waydroid-container
    #   waydroid session start        # then, in another shell:
    #   waydroid show-full-ui
    #
    # Testing your own build:
    #   waydroid app install ./app-debug.apk
    #   waydroid app list
    #
    # adb also reaches the container once a session is running, which is what
    # makes `gradle installDebug` and Android Studio work against it:
    #   adb connect "$(waydroid status | grep IP | awk '{print $3}'):5555"
    # `adb` itself comes from steelbore.hardware.android.
    #
    # WAYLAND ONLY. Waydroid renders through a Wayland compositor, so it works
    # under Niri, GNOME, COSMIC and Plasma's Wayland session, and NOT under
    # LeftWM — that session is startx/X11 (modules/login/default.nix), and
    # Waydroid has no X11 backend. Nothing here can fix that; use another
    # session for Android work.
    environment.systemPackages = [ pkgs.waydroid ];
  };
}
