# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Artcraft suite release pins (storytold, github:storytold/<app>)
#
# One entry per app: the upstream release `version` and the SRI `hash` of its
# `<app>-<version>-linux-x86_64.flatpak` release asset. Each key is both the
# GitHub repo name and the Flatpak id suffix (`ai.storyteller.<key>`).
# modules/packages/flatpak.nix fetches these and installs them as bundles.
#
# Vendored pins — never edit by hand; `nu pkgs/update-vendored.nu artcraft`
# rewrites them (or `preflight --update-vendored`). The suite versions each
# app on its own cadence, so the entries do not move together.
{
  wordcraft = {
    version = "0.17.0";
    hash = "sha256-SysJ4Fr8tnGVW/5KfXPe29QzuUasme/bfPzVCwLnCvY=";
  };
  photocraft = {
    version = "0.22.0";
    hash = "sha256-eMNtCP1hRlUxYrPeMhf8vVAkbD1cmjq5htPc0tfxHdo=";
  };
  vectorcraft = {
    version = "0.23.0";
    hash = "sha256-B28UeX18Sute5G0WyP9ikOGKs5NV/ehodtv7MsvlGC0=";
  };
  filmcraft = {
    version = "0.19.0";
    hash = "sha256-M40gjiQ/crFfmxNm9hIDYi/PcjaPmY5kLQxxhx+IUmk=";
  };
  lightcraft = {
    version = "0.20.0";
    hash = "sha256-mCjROA/NkoSFjSQKpBRdwDPgkZYUT7bS8YuorOgmcCE=";
  };
  pdfcraft = {
    version = "0.20.0";
    hash = "sha256-j8A5WGpyiFIAbhgQ1HUU8ZjJeMMg8X2E9c/jSv0SjVY=";
  };
  effectcraft = {
    version = "0.23.0";
    hash = "sha256-xlOqroJ3zJl318wo4uXi1Q499DiXYkuyMLblAjHwa+0=";
  };
  designcraft = {
    version = "0.19.0";
    hash = "sha256-JuD6GIndYkviEr/AnGObmqtYgucSY4sCpywNQbXFugc=";
  };
  figcraft = {
    version = "0.17.0";
    hash = "sha256-/hs5HsYr8IXGDAkRO4wPlFXNWg5Nu8ir2BvESoXTSxQ=";
  };
  soundcraft = {
    version = "0.19.0";
    hash = "sha256-A53ak+Hu2gpQRBtJzJ6dp3mDw7W5iNi/b99HolOJ9d0=";
  };
  deckcraft = {
    version = "0.17.0";
    hash = "sha256-3+y6m24bpEVDeib38eN0HW2lVtH1nn/eFc/BTFFvLMA=";
  };
  cadcraft = {
    version = "0.19.0";
    hash = "sha256-UMpDZescSAD0fIJWe8HzQAlK3e7FFEcfZbUsbHKF9f4=";
  };
  gridcraft = {
    version = "0.18.0";
    hash = "sha256-krP4XvdLZs/cfdt89Mbvt8wSqjvfmQgTWmg1FNJopBo=";
  };
}
