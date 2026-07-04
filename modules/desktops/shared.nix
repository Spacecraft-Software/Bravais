# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Shared bare-WM desktop services
#
# Config consumed by BOTH bare window managers (Niri and LeftWM) lives here,
# so disabling one WM cannot silently strip the other's config. First
# occupant: the dunst notification theme — dunst is spawned by Niri's
# spawn-at-startup AND LeftWM's session script, and the steelbore-* helper
# scripts dunstify from either session.
{
  config,
  lib,
  steelborePalette,
  ...
}:

{
  config =
    lib.mkIf (config.steelbore.desktops.leftwm.enable || config.steelbore.desktops.niri.enable)
      {
        # Dunst notification configuration
        environment.etc."dunst/dunstrc".text = ''
          # Steelbore Dunst Configuration
          [global]
          monitor = 0
          follow = mouse
          width = 350
          height = 150
          origin = top-right
          offset = 10x40

          transparency = 5
          padding = 16
          horizontal_padding = 16
          frame_width = 2
          frame_color = "${steelborePalette.steelBlue}"
          separator_color = frame

          font = "Hack Nerd Font 12"
          line_height = 0
          markup = full
          format = "<b>%s</b>\n%b"
          alignment = left

          icon_position = left
          max_icon_size = 48

          [urgency_low]
          background = "${steelborePalette.voidNavy}"
          foreground = "${steelborePalette.liquidCool}"
          timeout = 5

          [urgency_normal]
          background = "${steelborePalette.voidNavy}"
          foreground = "${steelborePalette.moltenAmber}"
          timeout = 10

          [urgency_critical]
          background = "${steelborePalette.voidNavy}"
          foreground = "${steelborePalette.redOxide}"
          frame_color = "${steelborePalette.redOxide}"
          timeout = 0
        '';

      };
}
