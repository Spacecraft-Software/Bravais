# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Home Manager: Git identity, signing, GPG agent
# Split from home.nix in Phase D (elegance plan 3.1); zero behavior change.
{
  pkgs,
  gitway,
  ...
}:

{
  programs = {
    # Git-LFS
    git.lfs.enable = true;

    # Git configuration
    git = {
      enable = true;
      settings = {
        user.name = "UnbreakableMJ";
        user.email = "Mohamed.Hammad@SpacecraftSoftware.org";
        user.signingkey = "~/.ssh/id_ed25519.pub";
        gpg.program = "${pkgs.sequoia-chameleon-gnupg}/bin/gpg-sq";
        gpg.format = "ssh";
        gpg.ssh.program = "${gitway.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/gitway-keygen";
        commit.gpgsign = true;
        init.defaultBranch = "main";
        "credential.https://github.com".helper = [
          ""
          "!${pkgs.gh}/bin/gh auth git-credential"
        ];
        "credential.https://gist.github.com".helper = [
          ""
          "!${pkgs.gh}/bin/gh auth git-credential"
        ];
      };
    };

    # Bash/Brush — kept enabled because NixOS internals (PAM, userdel, etc.)
    # require it. The bashrcExtra below ONLY overrides SSH_AUTH_SOCK back to
    # gitway-agent's socket (PAM's pam_gnome_keyring otherwise pins it to
    # /run/user/$UID/keyring/ssh, which often points at a non-existent
    # socket). No SSH-key auto-load — that runs from each WM's session
    # spawn, see modules/desktops/{niri,leftwm}.nix.
  };

  # GPG agent — uses pinentry-qt for KDE wallet and commit signing prompts
  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-qt;
  };

  # gitway-agent itself is enabled system-wide via services.gitway-agent.enable
  # in modules/core/security.nix (NixOS module from the gitway flake). That
  # module also writes /etc/environment.d/10-gitway-agent.conf and registers
  # the hardened systemd.user.services.gitway-agent unit, so neither needs to
  # be duplicated here.

  # SSH key loading happens lazily via the bash/brush rc snippet above on the
  # first interactive shell. A boot-time systemd user unit was tried but
  # failed silently against passphrase-protected keys without a TTY/SSH_ASKPASS.
}
