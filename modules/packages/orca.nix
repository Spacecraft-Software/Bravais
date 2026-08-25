# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Orca Computer-Use Dependencies
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.steelbore.packages.orca;

  # The typelib directories the AT-SPI bindings actually need, taken from the
  # two packages that provide them rather than from a system path that only
  # happens to contain them today.
  typelibPath = lib.makeSearchPath "lib/girepository-1.0" [
    pkgs.at-spi2-core
    pkgs.gobject-introspection
  ];

  # A Python that can genuinely `import pyatspi`. See the long note in `config`
  # for why the bare python3Packages entries below cannot do this on their own.
  # Wrapped rather than bare so the typelib path travels with the interpreter
  # and does not depend on the session variable being inherited.
  orcaPython = pkgs.writeShellScriptBin "orca-python" ''
    export GI_TYPELIB_PATH="${typelibPath}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
    exec ${
      pkgs.python3.withPackages (ps: [
        ps.pygobject3
        ps.pyatspi
      ])
    }/bin/python3 "$@"
  '';
in
{
  options.steelbore.packages.orca = {
    enable = lib.mkEnableOption "Orca computer-use dependencies (AT-SPI accessibility stack)";
  };

  # These packages exist ONLY to serve Orca's computer-use feature, which reads
  # and drives desktop UI through the AT-SPI accessibility tree. They are
  # gathered behind a single toggle rather than scattered into the general
  # bundles so that when Orca goes, this option goes and all of them leave with
  # it. Do not migrate individual entries into ai.nix or system.nix — that is
  # precisely the coupling this module exists to prevent.
  #
  # Orca itself is NOT packaged here. It ships as an AppImage at
  # ~/Applications/orca.appimage, registers a CLI shim under ~/.config/orca/,
  # keeps state in ~/.orca, and self-updates — the same class as claude-code and
  # grok-cli in constraint #4. There is therefore no Nix dependency edge to hang
  # these off, and an explicit toggle is the only honest way to say "these
  # belong to Orca".
  #
  # NAME COLLISION, and it is a sharp one: `pkgs.orca` in nixpkgs is the GNOME
  # *screen reader*, an unrelated product that depends on this exact same
  # four-package set. A reader who assumes that is what these serve will either
  # add `pkgs.orca` or delete these as redundant. They serve the Orca agent app;
  # nothing here installs the screen reader.
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      python3Packages.pygobject3 # Python — GObject/gi bindings
      python3Packages.pyatspi # Python — AT-SPI bindings
      at-spi2-core # C — AT-SPI accessibility bus/runtime
      gobject-introspection # C — runtime typelibs needed by gi
      orcaPython # wrapper — the interpreter that can actually import the two above
    ];

    # Read this before "simplifying" the two Python entries above.
    #
    # Listing `python3Packages.*` in environment.systemPackages does NOT make
    # them importable. Measured on the built toplevel: the files do land at
    # /run/current-system/sw/lib/python3.13/site-packages/{gi,pyatspi}, but
    # /run/current-system/sw/bin/python3 resolves through its symlink to the
    # plain interpreter's own store prefix, so sys.path contains only
    #   /nix/store/…-python3-3.13.13/lib/python3.13/site-packages
    # and `import gi` raises ModuleNotFoundError. Forcing PYTHONPATH at that
    # site-packages directory makes it work, which is what proves the files are
    # present and merely unreachable.
    #
    # The fix is `orca-python` above, not a global PYTHONPATH: a session-wide
    # PYTHONPATH leaks these modules into every Python on the machine, including
    # virtualenvs on a different minor version, where they would be silently
    # wrong. Swapping the system `python3` for a withPackages env is also not an
    # option — python3 is already declared in systemPackages, and NixOS builds
    # system.path with ignoreCollisions = true, so a second bin/python3 would
    # not error, it would just let an arbitrary one win.
    #
    # They are still declared because they are the stated dependency and because
    # a consumer that composes its own environment resolves them from the system
    # path; `orca-python` is what makes them usable without one.
    #
    # The AT-SPI *bus* is already running here — services.gnome.at-spi2-core is
    # enabled (GNOME pulls it in) and org.a11y.Bus is live — so no service needs
    # declaring. If GNOME is ever disabled, that dependency becomes this
    # module's to state.
    environment.sessionVariables.GI_TYPELIB_PATH = typelibPath;
  };
}
