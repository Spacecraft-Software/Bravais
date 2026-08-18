# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Fingerprint Reader Support
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # ---------------------------------------------------------------------------
  # Fingerprint policy — the single authoritative statement of where a
  # fingerprint is accepted on this machine.
  #
  # THE RULE: fingerprint AUTHENTICATES; it cannot DECRYPT. Everywhere a
  # fingerprint usefully touches a secret, it works by gating *release* of
  # something the LOGIN KEYRING holds — and the login keyring is opened by the
  # password typed at greetd. Password-at-greetd is therefore the root of
  # trust, and fingerprint is the convenience layer above it. `gitway biometric
  # status` says the same thing about its own feature: "the passphrase is
  # protected by your login keyring, not by the fingerprint".
  #
  # THE MECHANISM: pam_fprintd.so is `sufficient` at PAM order 11400, and
  # pam_gnome_keyring.so sits at 12200. So ANY successful fingerprint
  # short-circuits `auth` before the keyring module ever receives a password.
  # Any service that (a) starts a session, or (b) needs PAM_OLDAUTHTOK, must
  # therefore refuse fingerprint or it will silently do nothing useful.
  #
  # WHY THESE LISTS EXIST AT ALL: `security.pam.services.<name>.fprintAuth`
  # DEFAULTS to `services.fprintd.enable`. Enabling fprintd therefore put
  # pam_fprintd into 28 of this system's 32 PAM services — including chsh,
  # chfn, chpasswd, useradd, userdel, groupdel and su, none of which anyone
  # chose. The lists below replace that inheritance with an explicit statement.
  #
  # Verify after a rebuild:
  #   grep -l pam_fprintd /etc/pam.d/* | sort   # must equal fprintAllow exactly
  #   ls /etc/pam.d | wc -l                     # must NOT grow — declaring a
  #                                             # PAM service CREATES it
  #                                             # (AGENTS.md constraint #9, read
  #                                             # in reverse)
  # ---------------------------------------------------------------------------

  # Pure authorization decisions. Nothing here has to decrypt anything, so a
  # fingerprint is a complete substitute for the password. pam_fprintd is
  # `sufficient` in every one, so a failed or unsupported scan falls through to
  # the password prompt — you can never be locked out.
  fprintAllow = [
    "sudo" # sudo-rs
    "sudo-i"
    "polkit-1" # GUI privilege escalation (Flatpak installs, fprintd enrolment)
    "gtklock" # screen unlock — see the ordering note in modules/core/security.nix
    "swaylock" # not installed today; harmless and correct if it ever is
    "xlock"
    "vlock"
    "kde-fingerprint" # KDE's own dedicated fprint service; inert outside Plasma
  ];

  # Everything else, in three groups.
  fprintDeny = [
    # --- Session entry -------------------------------------------------------
    # A fingerprint here mints a session whose login keyring is still locked.
    # Chromium-family browsers then find no reachable Safe Storage key, mint a
    # fresh random one, and silently drop every saved login — this is what
    # logged Opera out on 2026-07-21 and Chrome on 2026-07-25.
    #
    # `login` is the TTY path and carries enableGnomeKeyring at 12200, exactly
    # like greetd — and at a TTY there is no Mod+Shift+U to repair it
    # afterwards. Note greetd and cosmic-greeter define their own PAM services
    # and do NOT inherit the `login` service's default, so each is named.
    "greetd"
    "login"
    "cosmic-greeter"

    # --- Needs PAM_OLDAUTHTOK ------------------------------------------------
    # Authenticating by fingerprint never populates the OLD authentication
    # token, so pam_gnome_keyring's password stanza runs and cannot re-encrypt
    # the keyring it exists to re-key. The module would be present and still do
    # nothing. `passwd` is the ONLY place the login keyring can be re-keyed.
    "passwd"
    "chpasswd"

    # --- Account/identity mutation, and non-conversational contexts ----------
    # For the account tools: prove you know the password before changing who
    # someone is. For su/runuser/systemd-*: these run in TTY or wholly
    # non-interactive contexts where fprintd's "Place your finger on the
    # reader" arrives as PAM_TEXT_INFO and then blocks — a hang, not a
    # convenience. Disabling costs nothing in either case.
    "chsh"
    "chfn"
    "useradd"
    "userdel"
    "usermod"
    "groupadd"
    "groupdel"
    "groupmod"
    "groupmems"
    "su"
    "su-l"
    "runuser"
    "runuser-l"
    "systemd-run0"
    "systemd-user"
    "cups"
  ];
in
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

    # Apply the policy declared above. Every name in both lists was taken from
    # a live `ls /etc/pam.d`, so this must not create any new PAM service —
    # diff the directory listing across the rebuild to prove it.
    #
    # `passwd` appears in fprintDeny; its companion `enableGnomeKeyring = true`
    # lives in modules/core/security.nix, because that is a keyring concern
    # rather than a fingerprint one. The two merge cleanly.
    security.pam.services =
      lib.genAttrs fprintAllow (_: { fprintAuth = true; })
      // lib.genAttrs fprintDeny (_: { fprintAuth = false; });
  };
}
