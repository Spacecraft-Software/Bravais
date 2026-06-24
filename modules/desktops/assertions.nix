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
  ];
}
