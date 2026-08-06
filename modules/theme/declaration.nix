# SPDX-FileCopyrightText: 2026 Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Steelbore Bravais — System Theme Declaration (Standard §11.6.4, §11.6.5)
#
# ./theme.nix has re-themed this machine from one word for a long time, but
# only at BUILD time: every terminal, both bars, the TTY and greetd get their
# colors baked into generated config. A program started afterwards cannot ask
# what theme is active — it can only read the per-role hex in
# ./default.nix's `environment.variables`, which tells it individual colors and
# not which of the family they came from, nor whether a high-contrast or mono
# sibling is in force.
#
# §11.6.5 makes closing that the OS's obligation, and this module is how:
#
#   - /etc/steelbore/theme.toml  — the §11.6.4 declaration, rendered FROM
#     ./theme.nix rather than maintained beside it, so the two can never drift.
#   - SPACECRAFT_THEME           — the slug in the session environment, for a
#     process that never reads a file (§11.6.3 source 2).
#   - /etc/steelbore/themes.json — the §11.6.4 advisory registry, the same
#     derivation `theme list` reads. Advisory: an application MUST NOT require
#     it, and its own steelbore.toml governs on disagreement.
#
# A file rather than a bus, deliberately: §11.6.4 has to work for a CLI in a
# text console, where there is no session bus and no desktop portal.
#
# The declaration carries SLUGS, never colors — an OS declares *which* theme;
# values come from steelbore.toml by way of the application's own copy (§11.4).
{
  lib,
  config,
  steelborePalette,
  themeRegistry,
  ...
}:

let
  cfg = config.steelbore.theme;
  res = steelborePalette.resolution;

  # Rendered by hand rather than via a TOML generator: this file is a published
  # interface (§11.6.4 fixes its schema), so what it looks like on disk is part
  # of the contract and worth reading literally in this source.
  boolStr = b: if b then "true" else "false";

  # Pad to the width of the longest key ("follow-color-scheme", 19) so the
  # rendered file matches the sample §11.6.4 publishes, column for column.
  pad = key: key + lib.strings.replicate (19 - builtins.stringLength key) " ";
  optLine =
    key: value:
    lib.optionalString (value != null) ''
      ${pad key} = "${value}"
    '';
in
{
  options.steelbore.theme = {
    active = lib.mkOption {
      type = lib.types.str;
      description = ''
        The active theme slug (§11.6.4 `active`). Defaults to whatever
        ./theme.nix selected — set in modules/theme/default.nix from
        `steelborePalette.meta.slug` so the slug has exactly one source and
        `theme try <slug>` keeps working without a second place to edit.
      '';
    };

    dark = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        The dark member of this system's §11.6.2 pair. Null means "derive from
        the active theme's polarity and its registered counterpart".
      '';
    };

    light = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        The light member of this system's §11.6.2 pair. Null means "derive".
      '';
    };

    followColorScheme = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        §11.6.4 `follow-color-scheme`. False pins the declared theme regardless
        of the desktop's appearance setting, disabling §11.6.3 stage-1 source 4
        for every application on this system.
      '';
    };

    highContrast = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        §11.6.4 `high-contrast`. Selects the `<slug>-high-contrast` sibling at
        §11.6.3 stage-2 signal 4. This is a THEME setting and explicitly not an
        accessible-mode switch — §18.1 is the only switch for that, and §18's
        behavioral requirements are not a color setting.
      '';
    };

    declare = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to render the §11.6.4 declaration and export the slug. On by
        default: §11.6.5 makes it an obligation, not a feature.
      '';
    };

    installRegistry = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to install the advisory §11.6.4 registry at
        /etc/steelbore/themes.json.
      '';
    };
  };

  config = lib.mkIf cfg.declare {
    # §11.6.5 — validate at evaluation time so an unknown theme fails the build
    # rather than the boot. lib/palette.nix already throws for an unknown
    # `active`; these catch a bad pair, which nothing else would.
    assertions =
      let
        known = s: builtins.elem s steelborePalette.meta.family;
      in
      [
        {
          assertion = cfg.dark == null || known cfg.dark;
          message = "steelbore.theme.dark = \"${toString cfg.dark}\" is not a selectable theme. Selectable: ${builtins.concatStringsSep ", " steelborePalette.meta.family}";
        }
        {
          assertion = cfg.light == null || known cfg.light;
          message = "steelbore.theme.light = \"${toString cfg.light}\" is not a selectable theme. Selectable: ${builtins.concatStringsSep ", " steelborePalette.meta.family}";
        }
      ];

    environment.etc."steelbore/theme.toml".text =
      let
        polarity = steelborePalette.meta.polarity;
        counterpart = steelborePalette.meta.pair;
        # Derive the pair from the active theme where it is not declared: the
        # active slug fills its own polarity's slot and its §11.6.2 counterpart
        # fills the other.
        darkSlug =
          if cfg.dark != null then
            cfg.dark
          else if polarity == "dark" then
            cfg.active
          else
            counterpart;
        lightSlug =
          if cfg.light != null then
            cfg.light
          else if polarity == "light" then
            cfg.active
          else
            counterpart;
      in
      ''
        # Generated by Steelbore OS Bravais — do not edit.
        # Rendered from ./theme.nix via modules/theme/declaration.nix; edit the
        # theme with `theme set <slug>` and rebuild, or write the per-user
        # override at ${res.userFile} for an
        # immediate switch that needs no rebuild.
        #
        # The Steelbore Standard, section 11.6.4 — the system theme declaration.
        # Slugs only; an OS declares WHICH theme and never supplies the hex.
        [theme]
        ${optLine "active" cfg.active}${optLine "dark" darkSlug}${optLine "light" lightSlug}${pad "follow-color-scheme"} = ${boolStr cfg.followColorScheme}
        ${pad "high-contrast"} = ${boolStr cfg.highContrast}

        [meta]
        standard = "11.6"
        source   = "bravais"
      '';

    environment.etc."steelbore/themes.json" = lib.mkIf cfg.installRegistry {
      source = themeRegistry;
    };

    # `environment.sessionVariables`, NOT `environment.variables`: the latter
    # lands in /etc/set-environment, which login shells source and systemd user
    # services and graphical .desktop launches do not. A GUI application started
    # from an application menu has to see this, so it goes in
    # /etc/pam/environment — which is what §11.6.5 means by "must reach
    # graphical sessions and system services, not login shells alone".
    environment.sessionVariables.${res.envVar} = cfg.active;
  };
}
