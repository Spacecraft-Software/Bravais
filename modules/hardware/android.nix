# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Android device access (adb) + SDK licence acceptance
#
# This module is the DEVICE half of Android support: it makes an attached
# handset reachable. The SDK itself is deliberately NOT installed system-wide —
# it lives in the `android` devShell (`nix develop .#android`), because an SDK
# is a per-project toolchain whose platform and build-tools versions belong to
# the project, not to the machine. Installing it globally would pin one set of
# versions for everything and add gigabytes to every system closure.
#
# Filed under hardware.* because it is a per-machine capability toggle in the
# same family as bluetooth and fingerprint — "can this box talk to that kind of
# device" — even though, on this nixpkgs, it no longer needs udev rules to do it.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.steelbore.hardware.android = {
    enable = lib.mkEnableOption "Android device access via adb, and Android SDK licence acceptance";
  };

  config = lib.mkIf config.steelbore.hardware.android.enable {
    # `pkgs.android-tools`, NOT `programs.adb.enable`.
    #
    # Every Android-on-NixOS guide still says to set `programs.adb.enable` and
    # add yourself to an `adbusers` group. That option was REMOVED and now fails
    # evaluation outright on this channel:
    #
    #   error: The option `programs.adb' can no longer be used since it's been
    #   removed. This option is no longer needed as systemd 258 handles uaccess
    #   rules automatically. Please add `pkgs.android-tools` to your system
    #   packages to get the adb command.
    #
    # systemd here is 260.1, so uaccess is automatic: the user logged in at the
    # seat gets access to an attached device with no group and no re-login.
    # `adbusers` is gone from nixpkgs entirely — nothing under nixos/modules/
    # references it any more — so adding a user to it would create a group that
    # nothing reads and quietly imply a permission fix that is not happening.
    environment.systemPackages = [ pkgs.android-tools ];

    # androidenv refuses to build unless the SDK licences are accepted. This
    # covers the SYSTEM pkgs instance only; the `android` devShell in flake.nix
    # instantiates its own nixpkgs and therefore sets this again for itself.
    # Both are needed — neither one covers the other.
    #
    # `allowUnfree` is already set unconditionally in modules/core/nix.nix, so
    # it is deliberately not repeated here.
    nixpkgs.config.android_sdk.accept_license = true;
  };
}
