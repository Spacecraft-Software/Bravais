# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Security Configuration
{
  config,
  lib,
  pkgs,
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
  # every password. Empty attrset = NixOS defaults (pam_unix), which is
  # what `auth include login` resolves to here.
  security.pam.services.gtklock = { };

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
