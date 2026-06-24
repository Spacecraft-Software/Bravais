# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — AppImage Support (auto-run via binfmt)
{
  config,
  lib,
  ...
}:

{
  options.steelbore.compat.appimage = {
    enable = lib.mkEnableOption "AppImage support (auto-run via binfmt)";
  };

  config = lib.mkIf config.steelbore.compat.appimage.enable {
    programs.appimage = {
      enable = true;
      binfmt = true;
    };
  };
}
