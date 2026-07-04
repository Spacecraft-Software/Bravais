# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Desktop composition guard assertions.
#
# Enabling several desktops at once (the "kitchen sink") is intentional, so
# these do NOT enforce mutual exclusivity. They assert only the genuine
# invariants, so a future edit cannot silently produce a broken session.
{ config, ... }:

{
  config.assertions = [
    {
      assertion = config.steelbore.desktops.leftwm.enable -> config.services.xserver.enable;
      message = ''
        steelbore.desktops.leftwm requires services.xserver.enable = true —
        LeftWM is X11-only and is launched via startx (see modules/login).
      '';
    }
    # Session-launch prerequisites (elegance plan 2.4). greetd (modules/login)
    # is the project's display manager; each desktop below ships its session
    # only through it (gnome/plasma keep their native DM as an alternative,
    # since gdm/sddm are only mkDefault-disabled and a host may re-enable one).
    {
      assertion = config.steelbore.desktops.niri.enable -> config.services.greetd.enable;
      message = ''
        steelbore.desktops.niri requires services.greetd.enable = true —
        the Niri Wayland session is only reachable via greetd (modules/login).
      '';
    }
    {
      assertion = config.steelbore.desktops.cosmic.enable -> config.services.greetd.enable;
      message = ''
        steelbore.desktops.cosmic requires services.greetd.enable = true —
        cosmic-greeter is not configured; COSMIC launches via greetd (modules/login).
      '';
    }
    {
      assertion =
        config.steelbore.desktops.gnome.enable
        -> (config.services.greetd.enable || config.services.displayManager.gdm.enable);
      message = ''
        steelbore.desktops.gnome requires a display manager: greetd
        (modules/login, the default) or services.displayManager.gdm.
      '';
    }
    {
      assertion =
        config.steelbore.desktops.plasma.enable
        -> (config.services.greetd.enable || config.services.displayManager.sddm.enable);
      message = ''
        steelbore.desktops.plasma requires a display manager: greetd
        (modules/login, the default) or services.displayManager.sddm.
      '';
    }
  ];
}
