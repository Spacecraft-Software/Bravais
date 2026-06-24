# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Security and Encryption Tools
{
  config,
  lib,
  pkgs,
  rapg,
  ...
}:

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
        # bitwarden-cli            # installed via Flatpak (com.bitwarden.desktop)
        # bitwarden-desktop        # installed via Flatpak (com.bitwarden.desktop)
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
      ];
  };
}
