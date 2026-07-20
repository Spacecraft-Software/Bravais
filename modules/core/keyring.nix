# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Secret Service keyring (gnome-keyring) + Chromium backend pinning
{
  lib,
  pkgs,
  ...
}:

{
  options.steelbore.keyring = {
    # Read-only knob, not a toggle: the single place the Chromium/Electron
    # credential-backend flag is spelled. Consumers (modules/packages/editors.nix,
    # any future Electron wrapper) read it instead of restating the string.
    chromiumFlag = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "--password-store=gnome-libsecret";
      description = ''
        Flag forcing Chromium-family and Electron apps onto the Secret Service
        (libsecret) credential backend instead of their plaintext fallback.
      '';
    };
  };

  config = {
    # The Secret Service provider. Bravais' primary sessions (Niri, LeftWM) are
    # window managers, not desktop environments, so nothing else pulls this in —
    # pin it here rather than inheriting it from whichever DE happens to be on.
    # Pairs with `security.pam.services.greetd.enableGnomeKeyring` (modules/login)
    # for auto-unlock on password login, and with `steelbore-keyring-unlock`
    # (modules/desktops/shared.nix) for the fingerprint-login path.
    services.gnome.gnome-keyring.enable = true;

    environment.systemPackages = with pkgs; [
      libsecret # secret-tool — CLI to store/lookup/clear; the diagnostic for "is the bus up?"
      seahorse # GUI keyring manager (browse/repair/change the login keyring password)
    ];
  };
}
