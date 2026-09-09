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

  # cosmic-greeter wears two hats, so its classification follows a config
  # option rather than a comment nobody will re-read.
  #
  # On this host greetd is the display manager and
  # `services.displayManager.cosmic-greeter.enable` is false, so cosmic-greeter
  # is ONLY the COSMIC lock screen. That is confirmed live rather than assumed:
  #   pam_fprintd(cosmic-greeter:auth): ReleaseDevice failed ...
  # was logged mid-session, while a session was already running. As a lock
  # screen it sits in exactly gtklock's position -- locking the screen does not
  # lock the keyring, so the 11400/12200 inversion is harmless there and
  # fingerprint is a pure win. It is the user's primary fingerprint use.
  #
  # The moment it becomes the display manager it is a SESSION-ENTRY path and
  # inherits greetd's problem wholesale: a fingerprint login would mint a
  # session with a locked keyring. Hence the toggle below rather than a fixed
  # list membership.
  cosmicGreeterIsLockScreen = !config.services.displayManager.cosmic-greeter.enable;

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
  ]
  ++ lib.optional cosmicGreeterIsLockScreen "cosmic-greeter";

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
    # afterwards. Note greetd defines its own PAM service and does NOT inherit
    # the `login` service's default, so it is named explicitly.
    # cosmic-greeter is classified below, because it depends on a config option.
    "greetd"
    "login"

    # --- Needs PAM_OLDAUTHTOK ------------------------------------------------
    # Authenticating by fingerprint never populates the OLD authentication
    # token, so pam_gnome_keyring's password stanza runs and cannot re-encrypt
    # the keyring it exists to re-key. The module would be present and still do
    # nothing. `passwd` is the ONLY place the login keyring can be re-keyed.
    "passwd"
    "chpasswd"

    # --- Account/identity mutation --------------------------------------
    # Prove you know the password before changing who someone is.
    "chsh"
    "chfn"
    "useradd"
    "userdel"
    "usermod"
    "groupadd"
    "groupdel"
    "groupmod"
    "groupmems"

    # --- su: authenticates the TARGET, and has no wheel gate --------------
    # The obvious question is "sudo takes my fingerprint, why not su?", and the
    # answer is that they authenticate different people. `sudo` authenticates
    # the INVOKING user — you — which is why it asks for your password. `su`
    # authenticates the TARGET user, which is why it asks for root's. So
    # allowing fingerprint here would not let you use YOUR finger: it would
    # require a fingerprint enrolled for ROOT. There is none —
    # /var/lib/fprint/ holds only the primary user — so listing su in
    # fprintAllow today would change nothing except adding a failed scan
    # before the password prompt.
    #
    # Enrolling one for root is where it turns bad. `/etc/pam.d/su` contains
    # ZERO pam_wheel entries, so nothing restricts who may attempt it: any
    # local account could then become root by presenting that finger. `sudo`
    # is gated by `security.sudo-rs.execWheelOnly = true`
    # (modules/core/security.nix), so the same finger only escalates for wheel
    # members. That asymmetry is the reason su stays denied, not any property
    # of fingerprints.
    #
    # `sudo -i` is the wheel-gated equivalent of `su -`, and it is already in
    # fprintAllow. Use that.
    "su"
    "su-l"

    # --- Non-conversational contexts --------------------------------------
    # These run with no interactive prompt to answer: fprintd's "Place your
    # finger on the reader" arrives as PAM_TEXT_INFO and then blocks, which is
    # a hang rather than a convenience. (Note this reasoning does NOT apply to
    # `su` above — a terminal is perfectly interactive; su is denied for the
    # target-user and wheel reasons instead.)
    "runuser"
    "runuser-l"
    "systemd-run0"
    "systemd-user"
    "cups"
  ]
  ++ lib.optional (!cosmicGreeterIsLockScreen) "cosmic-greeter";
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

    # Keep the reader out of USB runtime suspend.
    #
    # The Synaptics 06cb:00bd sits at `power/control = auto` with a 2 s
    # autosuspend delay, and the vfs0090 firmware does not survive being woken
    # mid-scan: instead of resuming it drops off the bus and re-enumerates.
    # Measured on 2026-09-08 at 17:58:35, all within the same second --
    #
    #   kernel:  usb 1-9: USB disconnect, device number 5
    #   fprintd: Device reported an error during identify: device was disconnected
    #   cosmic-greeter: pam_fprintd(cosmic-greeter:auth): ReleaseDevice failed:
    #                   This device has been removed from the system.
    #   kernel:  usb 1-9: new full-speed USB device number 8
    #
    # From the user's side that reads as the lock screen showing "place your
    # finger on the reader" and then withdrawing the prompt a moment later,
    # before a finger can reach the sensor -- pam_fprintd gives up and falls
    # through to the password field. Pinning power/control to "on" costs a few
    # tens of milliwatts and removes the wake path entirely.
    #
    # TEST== guards the case where the attribute is absent, so the rule cannot
    # fail the udev ruleset on a machine without this device.
    services.udev.extraRules = ''
      # Synaptics 06cb:00bd fingerprint reader — no USB runtime suspend.
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="06cb", ATTR{idProduct}=="00bd", TEST=="power/control", ATTR{power/control}="on"
    '';

    # Apply the policy declared above. Every name in both lists was taken from
    # a live `ls /etc/pam.d`, so this must not create any new PAM service —
    # diff the directory listing across the rebuild to prove it.
    #
    # `passwd` appears in fprintDeny; its companion `enableGnomeKeyring = true`
    # lives in modules/core/security.nix, because that is a keyring concern
    # rather than a fingerprint one. The two merge cleanly.
    security.pam.services =
      lib.genAttrs fprintAllow (_: {
        fprintAuth = true;
      })
      // lib.genAttrs fprintDeny (_: {
        fprintAuth = false;
      });
  };
}
