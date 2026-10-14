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
    version = "0.7.0";
    hash = "sha256-OpV6fF8lYjyjtkRHX4B44uBelcBmdtrRhhPmx9XAwPc=";
  };
  photocraft = {
    version = "0.9.0";
    hash = "sha256-PTps3ehL850ZBUUig0Th3DNAgJSc2jLVPee66184cXU=";
  };
  vectorcraft = {
    version = "0.11.0";
    hash = "sha256-iWqX1Dcjv50+I2YrmII8tawO/Ha5B5ZFeXSl0yAVeLY=";
  };
  filmcraft = {
    version = "0.8.0";
    hash = "sha256-XyhBLwCgSbq/SUEaY+BlvbV9eofso+UO5u6OYGHWIDk=";
  };
  lightcraft = {
    version = "0.8.0";
    hash = "sha256-VjW/PROGBXKZ+vbyXOl8u0AjMv2xGNSH6sUesAi7uR4=";
  };
  pdfcraft = {
    version = "0.8.0";
    hash = "sha256-lTVF4ze3vpXd1iUztPoGXh88YKX9Cz4sZfAjF/eLGtA=";
  };
  effectcraft = {
    version = "0.10.0";
    hash = "sha256-4cGt2ysUMhXyBkhShGRfmngQ6VKmWYkS+dyU267goVI=";
  };
  designcraft = {
    version = "0.8.0";
    hash = "sha256-ikORGqIJnokdkJhyHkdQSqZFnlGW1zBOFSRfOen3MvU=";
  };
  figcraft = {
    version = "0.6.0";
    hash = "sha256-c83U+C+9VZfoa7l1e/Nbaup0utg5rF/0DCLEic+ObyA=";
  };
  soundcraft = {
    version = "0.7.0";
    hash = "sha256-/Vrj3cZevSehbfeppIP5aAkjgvka1nJ8Y3bxvL3uPBQ=";
  };
  deckcraft = {
    version = "0.7.0";
    hash = "sha256-0rKD43Tg8WVRho/riIqYAY2hBn1S2q3GPH2dUArWs7U=";
  };
  cadcraft = {
    version = "0.7.0";
    hash = "sha256-XRAAAPEb7UV/PubJF5D8kSgE09Gxwz4kfenRf0McnJI=";
  };
  gridcraft = {
    version = "0.7.0";
    hash = "sha256-I7I6ZiCtc0+0ScESVk8+wAKK28S8No2HKOSrYb61OxQ=";
  };
}
