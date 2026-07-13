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
        driver = (pkgs.libfprint-2-tod1-vfs0090.overrideAttrs (old: {
          # Fix API mismatch: fpi_ssm_next_state_delayed() dropped its
          # third parameter (callback) in libfprint 1.94.9+.
          postPatch = (old.postPatch or "") + ''
            substituteInPlace vfs0090.c \
              --replace-fail 'fpi_ssm_next_state_delayed (ssm, 200, NULL)' \
                             'fpi_ssm_next_state_delayed (ssm, 200)' \
              --replace-fail 'fpi_ssm_next_state_delayed (ssm, 100, NULL)' \
                             'fpi_ssm_next_state_delayed (ssm, 100)'
          '';
          meta = (old.meta or {}) // { broken = false; };
        }));
      };
    };

    # Gate sudo / sudo -i (sudo-rs) with a fingerprint prompt. pam_fprintd is
    # `sufficient`, so a failed/unsupported scan falls through to password —
    # you can never be locked out.
    security.pam.services.sudo.fprintAuth = true;
    security.pam.services.sudo-i.fprintAuth = true;

    # Gate the greetd TUI login (tuigreet) with a fingerprint prompt. greetd
    # defines its own PAM service and does NOT inherit the `login` service's
    # fprintAuth default, so this must be set explicitly.
    security.pam.services.greetd.fprintAuth = true;
  };
}
