# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Security Configuration
{
  config,
  lib,
  ...
}:

{
  # Disable standard sudo (C implementation)
  security.sudo.enable = false;

  # Enable sudo-rs (Rust implementation — memory-safe)
  security.sudo-rs = {
    enable = true;
    execWheelOnly = true;
  };

  # Polkit for privilege escalation
  security.polkit.enable = true;

  # PAM service for gtklock (screen locker used by Niri and LeftWM). The
  # gtklock package ships its own `etc/pam.d/gtklock` (auth include login)
  # but NixOS doesn't link package PAM files into /etc/pam.d/ — without
  # this declaration the service is unknown to PAM and gtklock rejects
  # every password.
  #
  # enableGnomeKeyring re-unlocks the login keyring on screen unlock. Without
  # it, anything that locks the keyring mid-session leaves it locked for the
  # rest of the session, and Chromium-family browsers started afterwards mint a
  # fresh Safe Storage key rather than reaching the existing one — silently
  # dropping every saved login. Same failure mode the greetd path guards against
  # (modules/hardware/fingerprint.nix).
  #
  # Ordering note — deliberate, not an oversight. gtklock is in `fprintAllow`
  # (modules/hardware/fingerprint.nix), so pam_fprintd sits `sufficient` at
  # order 11400, AHEAD of pam_gnome_keyring at 12200. A fingerprint unlock
  # therefore short-circuits `auth` and never reaches the keyring module —
  # the very inversion that makes `greetd` and `login` refuse fingerprint.
  #
  # It is tolerable HERE and only here, because locking the screen does not
  # lock the keyring: the keyring is already open from the greetd password and
  # stays open across a lock. enableGnomeKeyring remains for the password
  # unlock path, and as repair if something locks the keyring mid-session; it
  # costs nothing on the fingerprint path. Do NOT delete it because "the
  # fingerprint path doesn't use it", and do NOT cite this service as
  # precedent for allowing fingerprint on anything that starts a session.
  security.pam.services.gtklock = {
    enableGnomeKeyring = true;
  };

  # `passwd(1)` uses its OWN PAM service, and it is the only place the login
  # keyring can be re-keyed. Without `pam_gnome_keyring.so` in that service's
  # *password* stanza, `passwd` changes the Unix password and leaves the
  # keyring encrypted under the OLD one. Nothing warns: greetd's
  # pam_gnome_keyring then silently fails to auto-unlock at every login, and
  # every later prompt rejects the (correct) account password as wrong.
  #
  # The matching `passwd.fprintAuth = false` lives in the fingerprint policy
  # (modules/hardware/fingerprint.nix) — without it this module is present and
  # still does nothing, because authenticating by fingerprint never populates
  # PAM_OLDAUTHTOK and pam_gnome_keyring cannot re-encrypt the keyring without
  # the old password.
  security.pam.services.passwd.enableGnomeKeyring = true;

  # SSH agent — provided by gitway-agent (NixOS module from the gitway flake;
  # imported in flake.nix). Disable system OpenSSH ssh-agent.service so it
  # doesn't race gitway-agent for $SSH_AUTH_SOCK. The OpenSSH CLI tools remain
  # available as a fallback for non-Git SSH workflows.
  programs.ssh.startAgent = false;
  services.gnome.gcr-ssh-agent.enable = false; # guard against GCR clobbering the socket

  services.gitway-agent.enable = true;

  # seatd: required by cage (Wayland kiosk) wrapping the brush/ion/nushell
  # session entries. cage's libseat tries the seatd backend first; without
  # /run/seatd.sock it logs "Backend 'seatd' failed to open seat, skipping"
  # and may fall through to logind unreliably. Running seatd is cheap and
  # silences the noise.
  services.seatd.enable = true;

  # nixosModules.default doesn't expose defaultLifetime; restore the 24 h TTL
  # (parity with the previous home-manager configuration) by appending `-t 86400`.
  systemd.user.services.gitway-agent.serviceConfig.ExecStart =
    lib.mkForce "${config.services.gitway-agent.package}/bin/gitway agent start -D -s -a %t/gitway-agent.sock -t 86400";

  # Make the gitway-agent socket visible to greetd-launched shells. The
  # gitway NixOS module already drops /etc/environment.d/10-gitway-agent.conf,
  # but that file is only read by `systemd --user`. Shells exec'd directly by
  # greetd's PAM session need the variable in /etc/profile and pam_env's
  # /etc/pam/environment — `environment.sessionVariables` writes to both.
  # The `$` is escaped so Nix passes it through and /etc/profile expands it.
  environment.sessionVariables.SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/gitway-agent.sock";

  # Tmpfiles rules
  systemd.tmpfiles.rules = [
    "d /tmp 1777 root root -"
    "d /var/tmp 1777 root root -"
  ];
}
