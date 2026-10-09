# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — the Steelbore OS logo, installed system-wide, and
# KDE Info Center's "About this System" page (PLAN.md D4, P-016).
#
# Always on, with no toggle: the identity is not optional. os-release names
# LOGO=<identity.logo> on every build, so the icon it points at must exist on
# every build too, or GNOME's About page and fetch tools fall back to a
# generic glyph. (COSMIC Settings' About shows PRETTY_NAME only, no logo.) Installing it costs a few kilobytes.
#
# The marks are recoloured from the active palette's `foreground` role at
# build time (Standard §11.4 — no colour literal here); `theme set` / `theme
# try` therefore recolour the logo along with everything else.
#
# KNOWN LIMIT: `foreground` is the text colour for the palette's own
# (dark) canvas. A desktop running a LIGHT toolkit theme — Breeze Light,
# Adwaita light — draws the About page on a pale background, where a
# light-foreground mark has little contrast. Every Bravais desktop is
# dark-mode by default (dark-mode.nix), so this is accepted rather than
# shipping a second, inverted icon set.
{
  pkgs,
  steelborePalette,
  steelboreIdentity,
  ...
}:

let
  branding = (import ../../pkgs { inherit pkgs; }).steelbore-branding.override {
    fill = steelborePalette.foreground;
  };
in
{
  # Puts share/icons/hicolor/** and share/pixmaps/** into
  # /run/current-system/sw, where the icon theme lookup finds LOGO=.
  environment.systemPackages = [ branding ];

  # KDE Info Center reads ONLY the [General] group of this file (KConfig,
  # NoGlobals), each key overriding the matching os-release field — keys and
  # fallbacks checked against kinfocenter 6.6.6,
  # kcms/about-distro/src/main.cpp `loadOSData()`. LogoPath takes an icon
  # name or an absolute path; the wordmark (not the bare emblem os-release
  # names) is the intended mark for this page, so it gets the store path.
  # UseOSReleaseVersion=true shows os-release VERSION ("26.05 (Altair)",
  # carrying the Steelbore OS codename) instead of the bare VERSION_ID.
  # Written unconditionally: a dozen bytes in /etc is cheaper than coupling
  # this module to whichever desktop toggles happen to pull in Plasma.
  environment.etc."xdg/kcm-about-distrorc".text = ''
    [General]
    Name=${steelboreIdentity.name}
    Variant=${steelboreIdentity.variant}
    Website=${steelboreIdentity.urls.home}
    UseOSReleaseVersion=true
    LogoPath=${branding}/share/icons/hicolor/scalable/apps/${steelboreIdentity.logoText}.svg
  '';
}
