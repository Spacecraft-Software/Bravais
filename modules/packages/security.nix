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

        # ── Password Managers ──────────────────────────────────────────────
        #
        # The desktop client is the NIXPKGS package, not the Flatpak (which is
        # commented out in modules/packages/flatpak.nix). Both are 2026.8.0, so
        # this is not a version move — it is about the credential path.
        #
        # A Flatpak cannot reach the Secret Service for its OWN credential
        # store. It asks the **Secret portal** for a per-app master key and
        # encrypts `~/.var/app/<id>/data/keyrings/default.keyring` with it. That
        # key lives in the login keyring as an "Application key for <app_id>"
        # item, so anything that re-keys or replaces the login keyring destroys
        # it — and the app then fails every credential read with `File backend
        # error Incorrect secret`, locks the vault, reloads the renderer and
        # loops, which reads as an unusable UI rather than a keyring fault.
        # Measured 2026-09-15: that is exactly what happened here, the app key
        # having been lost in the same event that re-keyed the browsers. The
        # unsandboxed client talks to `org.freedesktop.secrets` directly
        # (modules/core/keyring.nix pins gnome-keyring as THE provider), so this
        # entire failure mode does not exist for it.
        #
        # **Do NOT also declare the `com.bitwarden.Bitwarden.unlock` polkit
        # action here.** This package installs it itself — its postInstall awks
        # the `polkitPolicy` template literal straight out of
        # os-biometrics-linux.service.ts into
        # `$out/share/polkit-1/actions/`. Shipping a second copy (the
        # `writeTextDir` this module carried while the client was a Flatpak) is
        # a `buildEnv` collision on an identical path, exit 25, same shape as
        # constraint #12. The action is still required for biometric unlock; it
        # simply arrives with the package now.
        #
        # Browser integration is unaffected by the move: the client copies
        # `desktop_proxy` and opens its IPC socket inside each browser's own
        # NativeMessagingHosts directory regardless of whether the client itself
        # is sandboxed, so Flatpak Chrome still works (PRD §11.4).
        bitwarden-desktop # TypeScript/Electron — official desktop client
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
      ];
  };
}
