# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Security and Encryption Tools
{
  config,
  lib,
  pkgs,
  rapg,
  ...
}:

let
  # ---------------------------------------------------------------------------
  # Bitwarden biometric unlock — the polkit action, declared here because the
  # app cannot declare it itself.
  #
  # THE MECHANISM: Bitwarden's Linux "unlock with biometrics" is a polkit
  # authorization check on the action `com.bitwarden.Bitwarden.unlock` with
  # `allow_active = auth_self`. The vault key is NOT protected by the finger: it
  # is offloaded to the Secret Service (gnome-keyring, modules/core/keyring.nix)
  # and polkit merely gates its release. That is precisely the doctrine
  # modules/hardware/fingerprint.nix states — fingerprint AUTHENTICATES, it
  # cannot DECRYPT, and password-at-greetd stays the root of trust because it is
  # what opened the login keyring.
  #
  # WHY IT IS HERE AND NOT INSTALLED BY THE APP: the desktop client normally
  # writes this file itself through pkexec, but its own `canAutoSetup()` returns
  # FALSE under Flatpak and Snap — "we cannot auto setup ... since the
  # filesystem is sandboxed" — and com.bitwarden.desktop is a Flatpak here
  # (modules/packages/flatpak.nix). Its hardcoded target
  # `/usr/share/polkit-1/actions/` does not exist on NixOS either. polkitd's
  # search path includes /run/current-system/sw/share/polkit-1/actions, so a
  # writeTextDir in systemPackages is the declarative equivalent. The Flatpak
  # already carries the two bus permissions this needs —
  # `org.freedesktop.PolicyKit1=talk` on the system bus and
  # `org.freedesktop.secrets=talk` on the session bus — so nothing else is
  # required of it.
  #
  # WHY IT IS SAFE UNDER THE FINGERPRINT POLICY: `polkit-1` is already in
  # fprintAllow, and /etc/pam.d/polkit-1 carries NO pam_gnome_keyring stanza —
  # so the 11400-before-12200 short-circuit that governs that list cannot bite
  # here. pam_fprintd is `sufficient`, so a failed or unsupported scan falls
  # through to the password prompt and the vault can never be locked out.
  # `auth_self` authenticates the INVOKING user, so no wheel membership and no
  # root-enrolled print are implied (contrast the `su` reasoning in that file).
  #
  # The XML is upstream's verbatim, lifted from the `polkitPolicy` template
  # literal in apps/desktop/src/key-management/biometrics/native-v2/
  # os-biometrics-linux.service.ts — do not reformat it. nixpkgs'
  # bitwarden-desktop extracts the same string with awk in its postInstall; if
  # this ever moves to the nixpkgs client instead of the Flatpak, drop this
  # binding rather than shipping the action twice.
  #
  # Verify after a rebuild:
  #   pkaction --action-id com.bitwarden.Bitwarden.unlock --verbose
  #   pkcheck -u --action-id com.bitwarden.Bitwarden.unlock --process $$
  # ---------------------------------------------------------------------------
  bitwardenPolkitPolicy = pkgs.writeTextDir "share/polkit-1/actions/com.bitwarden.Bitwarden.policy" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE policyconfig PUBLIC
     "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
     "http://www.freedesktop.org/standards/PolicyKit/1.0/policyconfig.dtd">
    <policyconfig>
        <action id="com.bitwarden.Bitwarden.unlock">
          <description>Unlock Bitwarden</description>
          <message>Authenticate to unlock Bitwarden</message>
          <defaults>
            <allow_any>no</allow_any>
            <allow_inactive>no</allow_inactive>
            <allow_active>auth_self</allow_active>
          </defaults>
        </action>
    </policyconfig>
  '';
in
{
  options.steelbore.packages.security = {
    enable = lib.mkEnableOption "Security and encryption tools";
  };

  config = lib.mkIf config.steelbore.packages.security.enable {
    environment.systemPackages =
      (with pkgs; [
        # Encryption (Rust preferred)
        age # Rust — Modern encryption
        rage # Rust — age implementation
        sops # Go — Secret management

        # PGP / Sequoia Stack (Rust)
        sequoia-sq # Rust — Sequoia CLI
        sequoia-chameleon-gnupg # Rust — GnuPG drop-in
        sequoia-wot # Rust — Web of Trust
        sequoia-sqv # Rust — Signature verifier
        sequoia-sqop # Rust — Stateless OpenPGP

        # Password Managers
        rbw # Rust — Bitwarden CLI (unofficial; kept for scripting)
        authenticator # Rust — 2FA/OTP

        # SSH
        openssh_hpn # Includes OpenSSH tooling; avoid colliding with openssh
        # gitway is installed system-wide by gitway.nixosModules.default
        # (enabled via services.gitway-agent.enable in modules/core/security.nix).

        # Backup
        pika-backup # Rust — Borg frontend

        # Sandboxing
        sydbox # Process sandbox / call-policy enforcement

        # Secure Boot
        sbctl # Rust — Secure Boot manager
        hydra-check # Nix/Hydra build status checker
      ])
      # Secret managers from upstream flakes
      ++ [
        rapg.packages.${pkgs.stdenv.hostPlatform.system}.default # Go — AI-agent secret manager

        # polkit action only — no binary, no closure. See the note above.
        bitwardenPolkitPolicy
      ];
  };
}
