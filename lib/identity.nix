# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — the operating system's identity, stated once.
#
# THE single source for every place the machine names itself: os-release and
# lsb-release (modules/core/identity.nix), the boot menu, the TTY greeting,
# the greeter, both bars, the `steelbore` shell banner, the Plymouth theme
# description, KDE's About page and the Rust tools that print the OS name.
# Threaded as `steelboreIdentity` through specialArgs AND extraSpecialArgs,
# exactly like `primaryUser` and `steelborePalette`. Never retype the OS name
# in a consumer — read it from here.
#
# Authority: Standard §2.1 — the v1.7 umbrella rename (Steelbore → Spacecraft
# Software) left the OS line its name: `Steelbore OS`, `Steelbore OS Bravais`.
# §11.6.5 names Bravais as Steelbore OS's NixOS flavor, hence variant =
# Bravais and vendor = Spacecraft Software. PLAN.md carries the rollout.
#
# Pure data plus one lookup; no pkgs, no lib, so flake.nix can import it with
# a bare `import`.
let
  self = {
    # ── Names ────────────────────────────────────────────────────────────
    name = "Steelbore OS"; # os-release NAME, nixpkgs distroName (§2.1)
    # os-release ID. Shares its spelling with the default *palette* slug in
    # theme.nix; the two namespaces never meet (os-release ids vs §11.6 theme
    # slugs), so the coincidence is harmless. Must match ^[a-z0-9._-]+$.
    id = "steelbore";
    variant = "Bravais"; # os-release VARIANT — the NixOS flavor (§11.6.5)
    variantId = "bravais"; # os-release VARIANT_ID
    vendor = "Spacecraft Software"; # os-release VENDOR_NAME (§1)
    # CPE vendor component → cpe:/o:spacecraft-software:steelbore:<release>.
    vendorId = "spacecraft-software";

    # ── Display strings ─────────────────────────────────────────────────
    fullName = "${self.name} ${self.variant}"; # prose: "Steelbore OS Bravais"
    # Greeter / bar-title register: "STEELBORE OS :: BRAVAIS". Uppercased by
    # hand rather than lib.toUpper so this file stays lib-free; the assertion
    # below keeps it honest.
    banner = "STEELBORE OS :: BRAVAIS";

    # ── URLs (Standard §15.1, §5) ────────────────────────────────────────
    urls = {
      home = "https://Bravais.SpacecraftSoftware.org/";
      vendor = "https://SpacecraftSoftware.org/";
      documentation = "https://Bravais.SpacecraftSoftware.org/";
      support = "https://github.com/Spacecraft-Software/Bravais";
      bugReport = "https://github.com/Spacecraft-Software/Bravais/issues";
    };

    # ── Attribution (Standard §15.2) ─────────────────────────────────────
    maintainer = "Mohamed Hammad";
    contact = "Mohamed.Hammad@SpacecraftSoftware.org";
    license = "GPL-3.0-or-later";

    # ── Logo ─────────────────────────────────────────────────────────────
    # Freedesktop icon names, installed by pkgs/steelbore-branding into
    # hicolor/scalable/apps from assets/brand/. `logo` is the emblem (os-release
    # LOGO, GNOME/COSMIC About, fastfetch); `logoText` is the emblem plus the
    # STEELBORE wordmark (KDE Info Center).
    #
    # The wordmark must NOT be named "<logo>-text": GNOME Settings' About page
    # looks up "<LOGO>-text-dark", "<LOGO>-text", "<LOGO>-dark", "<LOGO>" in
    # that order (gnome-control-center cc-about-page.c), so a "-text" sibling
    # would replace the emblem there with the wordmark.
    logo = "steelbore-os";
    logoText = "steelbore-os-wordmark";

    # ── Release codenames ────────────────────────────────────────────────
    # One star name per NixOS release this flake can build, drawn from the
    # Arabic-origin entries of Wikipedia's "List of proper names of stars"
    # (maintainer decision D3; §2 stellar register). Replaces NixOS's own
    # codename in os-release and lsb-release only — nixpkgs' `codeName` is
    # read-only, so `nixos-version` and the bootspec label still show it.
    #
    # Every release either channel can produce MUST have an entry: a missing
    # one fails evaluation (codenameFor below) rather than silently shipping
    # NixOS's name. Add the next release before bumping a channel to it.
    # Achernar is skipped on purpose — it is already a Spacecraft project name.
    codenames = {
      "26.05" = "Altair"; # α Aquilae — al-nasr al-ṭāʾir, "the flying (eagle)"
      "26.11" = "Aldebaran"; # α Tauri — al-dabarān, "the follower"
    };

    codenameFor =
      release:
      if builtins.hasAttr release self.codenames then
        self.codenames.${release}
      else
        throw ''
          lib/identity.nix: no Steelbore OS codename for NixOS release ${release}.
          Add an Arabic-origin star name to `codenames` before building this release.
        '';
  };
in
self
