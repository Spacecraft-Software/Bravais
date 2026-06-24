# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Library Functions
{ lib, ... }:

{
  # Steelbore color palette for use across modules
  steelborePalette = {
    voidNavy = "#000027";
    moltenAmber = "#D98E32";
    steelBlue = "#4B7EB0";
    radiumGreen = "#50FA7B";
    redOxide = "#FF5C5C";
    liquidCool = "#8BE9FD";
  };

  # Helper to create a Steelbore module with standard options
  mkSteelboreModule =
    {
      name,
      description,
      config,
    }:
    {
      options.steelbore.${name} = {
        enable = lib.mkEnableOption description;
      };

      config = lib.mkIf config.steelbore.${name}.enable config;
    };
}
