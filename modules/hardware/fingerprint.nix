# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Fingerprint Reader Support
{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.steelbore.hardware.fingerprint = {
    enable = lib.mkEnableOption "Fingerprint reader support";
  };

  config = lib.mkIf config.steelbore.hardware.fingerprint.enable {
    services.fprintd = {
      enable = true;

      # Use the TOD (Touch OEM Driver) framework with the VFS0090 driver
      # for the Synaptics 06cb:00bd sensor. The stock libfprint driver
      # enrolls but can't read back prints (enroll-duplicate /
      # NoEnrolledPrints). The upstream VFS0090 package is marked broken
      # due to an API change in libfprint 1.94.9+; we carry a local patch.
      tod = {
        enable = true;
        driver = (
          pkgs.libfprint-2-tod1-vfs0090.overrideAttrs (old: {
            # Fix API mismatch: fpi_ssm_next_state_delayed() dropped its
            # third parameter (callback) in libfprint 1.94.9+.
            postPatch = (old.postPatch or "") + ''
              substituteInPlace vfs0090.c \
                --replace-fail 'fpi_ssm_next_state_delayed (ssm, 200, NULL)' \
                               'fpi_ssm_next_state_delayed (ssm, 200)' \
                --replace-fail 'fpi_ssm_next_state_delayed (ssm, 100, NULL)' \
                               'fpi_ssm_next_state_delayed (ssm, 100)'
            '';
            meta = (old.meta or { }) // {
              broken = false;
            };
          })
        );
      };
    };

    # Gate sudo / sudo -i (sudo-rs) with a fingerprint prompt. pam_fprintd is
    # `sufficient`, so a failed/unsupported scan falls through to password —
    # you can never be locked out.
    security.pam.services.sudo.fprintAuth = true;
    security.pam.services.sudo-i.fprintAuth = true;

    # Fingerprint is deliberately NOT enabled for the greetd TUI login
    # (tuigreet). pam_fprintd is `sufficient` at PAM order 11400, ahead of
    # pam_gnome_keyring at 12200, so a fingerprint login short-circuits `auth`
    # before the keyring module ever receives a password. The login keyring then
    # stays locked, and Chromium-family browsers — finding no reachable Safe
    # Storage key — silently mint a fresh random one and lose every saved
    # session (this is what logged Opera out on 2026-07-21 and Chrome on
    # 2026-07-25). A typed password at greetd is what makes
    # `security.pam.services.greetd.enableGnomeKeyring` (modules/login/default.nix)
    # actually do anything. sudo / sudo -i above keep fingerprint.
    #
    # greetd defines its own PAM service and does NOT inherit the `login`
    # service's fprintAuth default, so this is stated explicitly rather than
    # left to the default.
    security.pam.services.greetd.fprintAuth = false;
  };
}
