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
    # window managers, not desktop environments. GNOME's own module *does*
    # enable this transitively when that desktop is installed (oo7 decision
    # doc, Findings), so this pin is about being explicit and DE-independent,
    # not about being the only enabler.
    # Pairs with `security.pam.services.greetd.enableGnomeKeyring` (modules/login)
    # for auto-unlock on password login, and with `steelbore-keyring-unlock`
    # (modules/desktops/shared.nix) for the fingerprint-login path.
    services.gnome.gnome-keyring.enable = true;

    # The Secret Service Unlock dialog is drawn by `gcr-prompter`, D-Bus-
    # activated as org.gnome.keyring.SystemPrompter. It ships in gcr 3
    # (`pkgs.gcr`); `pkgs.gcr_4` dropped it entirely — verified on this
    # machine: gcr-3.41.2 has libexec/gcr-prompter, gcr-4.4.0.1 has no
    # prompter at all. gnome-keyring 50 still links gcr 3, so today this
    # reaches the bus transitively. Pin it explicitly, and assert the
    # version, so an upstream move to gcr_4 fails at eval instead of
    # silently removing every keyring dialog under Niri and LeftWM —
    # which would leave `steelbore-keyring-unlock` with nothing to prompt
    # with and no error to explain it.
    services.dbus.packages = [ pkgs.gcr ];

    assertions = [
      {
        assertion = lib.versionOlder pkgs.gcr.version "4";
        message = ''
          steelbore.keyring: pkgs.gcr is version ${pkgs.gcr.version}, but
          gcr-prompter exists only in gcr 3. steelbore-keyring-unlock cannot
          draw a password dialog without it. Pin an older gcr or port the
          unlock path to a prompter that ships with gcr 4.
        '';
      }
    ];

    environment.systemPackages = with pkgs; [
      libsecret # secret-tool — CLI to store/lookup/clear; the diagnostic for "is the bus up?"
      seahorse # GUI keyring manager (browse/repair/change the login keyring password)
    ];
  };
}
