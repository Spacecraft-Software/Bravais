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
    version = "0.11.0";
    hash = "sha256-Xsog5wzr5QJWYOrjUMOz50rp/DbvspPSY1d+I2lvsZM=";
  };
  photocraft = {
    version = "0.16.0";
    hash = "sha256-uLhEpJUfaHci/Mrn5E82C72v3xEpER2NEB6JNJTqMgI=";
  };
  vectorcraft = {
    version = "0.17.0";
    hash = "sha256-NCPJjbzpovfmf6F7aFLF9vo3Opml8Kh3H8MY9C2FOYw=";
  };
  filmcraft = {
    version = "0.13.0";
    hash = "sha256-yabHY7v2v06maiBPVkU5LOo5/punTwiLDAgUnEltoaA=";
  };
  lightcraft = {
    version = "0.14.0";
    hash = "sha256-lRRe71IzbTaIE1wvRc4NSkltA+IsE8Jr5A98LUcTWUQ=";
  };
  pdfcraft = {
    version = "0.14.0";
    hash = "sha256-fuS/VUufGFTa3wcRdPe2FuoFBdHbi5roUFLgtmPxj+U=";
  };
  effectcraft = {
    version = "0.17.0";
    hash = "sha256-URuqEJ9sBshbQvYJC2QNvv6+B6eFzQCBwlnG4a4g3LA=";
  };
  designcraft = {
    version = "0.13.0";
    hash = "sha256-qyzf586+oBwOvqxQeJzQ1LBE6QuyP/uOSWE0Vr35xD8=";
  };
  figcraft = {
    version = "0.11.2";
    hash = "sha256-+FseY+1e9rVJmE1XX3jjbI2GsSbUldwoYLJob1we+uk=";
  };
  soundcraft = {
    version = "0.13.1";
    hash = "sha256-J/IgfRl25PfbtZ5EL+DMCdUIOFcV34e1ZJStKQlYxDk=";
  };
  deckcraft = {
    version = "0.11.1";
    hash = "sha256-C/JmyIWsgPK8ad4Wo89BXbmneGmS3Y4IgzlLJnWBdtY=";
  };
  cadcraft = {
    version = "0.13.0";
    hash = "sha256-otchecKAd5MDx9Lt6/jVwsh7/fTFpWkk8O3wInZsWk0=";
  };
  gridcraft = {
    version = "0.12.1";
    hash = "sha256-CGHCWpDKtIrZsgaJ3dJBe3+nFabGJfr1gAGolAnJ4ZA=";
  };
}
