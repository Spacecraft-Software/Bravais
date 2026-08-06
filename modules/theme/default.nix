# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Theme Module Entry Point
{
  lib,
  steelborePalette,
  ...
}:

{
  imports = [
    ./fonts.nix
    ./dark-mode.nix
    ./declaration.nix
  ];

  # The active slug has exactly ONE source: ./theme.nix, resolved through
  # lib/palette.nix into `steelborePalette`. Reading ./theme.nix again in
  # declaration.nix would give `theme try <slug>` two answers — that path builds
  # a system with a different palette without editing ./theme.nix, so the file
  # and the resolved palette deliberately disagree there.
  steelbore.theme.active = lib.mkDefault steelborePalette.meta.slug;

  # Per-role color environment variables, for shell scripts and third-party
  # programs that have no §11 theme of their own.
  #
  # NOT a Standard interface: §11.6.4 says so in terms. A conforming
  # application reads role values from steelbore.toml and learns the active
  # theme from SPACECRAFT_THEME (declaration.nix) or the §11.6.4 file — never
  # by reassembling a palette out of these. They are kept because they are
  # useful, not because anything in §11 depends on them.
  #
  # These stay in `environment.variables` (/etc/set-environment, login shells)
  # rather than moving to `sessionVariables`: their consumers are shell
  # scripts, and widening their reach is not this section's business.
  environment.variables = {
    SPACECRAFT_BACKGROUND = steelborePalette.background;
    SPACECRAFT_SURFACE = steelborePalette.surface;
    SPACECRAFT_TEXT = steelborePalette.foreground;
    SPACECRAFT_ACCENT = steelborePalette.accent;
    SPACECRAFT_STRUCTURE = steelborePalette.structure;
    SPACECRAFT_SUCCESS = steelborePalette.success;
    # WARNING used to carry the error color — a six-token palette had no
    # distinct warning, so the two shared one. They are separate roles now.
    SPACECRAFT_ERROR = steelborePalette.error;
    SPACECRAFT_WARNING = steelborePalette.warning;
    SPACECRAFT_INFO = steelborePalette.info;
  };

  # TTY / Virtual Console Colors — the 16-color ANSI mapping is single-sourced
  # in lib/palette.nix and shared with every terminal emulator via
  # lib/terminal-theme.nix. This file used to carry a second copy of the same
  # table, which had to be kept in step by hand.
  console.colors =
    let
      b = steelborePalette.convert.bareHex;
      a = steelborePalette.ansi;
    in
    map b (a.normal ++ a.bright);
}
