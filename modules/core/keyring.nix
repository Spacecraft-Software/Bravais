# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Secret Service keyring (gnome-keyring) + Chromium backend pinning
{
  lib,
  pkgs,
  ...
}:

let
  # The gcr 3 package, under whichever attribute the channel spells it.
  #
  # This is the constraint #5 stable/unstable split, and NEITHER name works on
  # both: stable 26.05 has `gcr` (3.41.2) and no `gcr_3`, while nixos-unstable
  # has `gcr_3` (3.41.2) and has REMOVED `gcr` -- "error: 'gcr' attribute has
  # been removed from nixpkgs. Use a 'gcr_*' attribute with an explicit ABI
  # version instead." That removal is a throwing attribute rather than a
  # missing one, so the fallback has to be ordered with the surviving name
  # FIRST: `gcr_3` resolves on unstable and Nix never evaluates the `or`
  # branch, while on stable `gcr_3` is genuinely absent and the fallback picks
  # up `gcr`. Reversing the order throws on unstable.
  #
  # Drop the fallback once stable also carries `gcr_3`, per constraint #5.
  gcr3 = pkgs.gcr_3 or pkgs.gcr;
in
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
    # activated as org.gnome.keyring.SystemPrompter. It ships in gcr 3 (see
    # `gcr3` above for why the attribute name differs per channel); gcr 4
    # dropped it entirely — verified on this machine: gcr-3.41.2 has
    # libexec/gcr-prompter, gcr-4.4.0.1 has no prompter at all. gnome-keyring
    # 50 still links gcr 3, so today this reaches the bus transitively. Pin it
    # explicitly, and assert the version, so an upstream move to gcr 4 fails
    # at eval instead of silently removing every keyring dialog under Niri and
    # LeftWM — which would leave `steelbore-keyring-unlock` with nothing to
    # prompt with and no error to explain it.
    services.dbus.packages = [ gcr3 ];

    assertions = [
      {
        assertion = lib.versionOlder gcr3.version "4";
        message = ''
          steelbore.keyring: the resolved gcr package is version
          ${gcr3.version}, but gcr-prompter exists only in gcr 3.
          steelbore-keyring-unlock cannot draw a password dialog without it.
          Pin a gcr 3 attribute or port the unlock path to a prompter that
          ships with gcr 4.
        '';
      }
    ];

    environment.systemPackages = with pkgs; [
      libsecret # secret-tool — CLI to store/lookup/clear; the diagnostic for "is the bus up?"
      seahorse # GUI keyring manager (browse/repair/change the login keyring password)
    ];
  };
}
