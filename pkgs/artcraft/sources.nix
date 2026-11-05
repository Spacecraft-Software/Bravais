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
    version = "0.15.2";
    hash = "sha256-QnbwEy1+uYOtKdgTKhlmUP8MAC8b4Jc8JwAx9i+p1Pw=";
  };
  photocraft = {
    version = "0.20.2";
    hash = "sha256-e70gs+OUUXSmIUrOuWmFzvvS7j3WQ54BN4q1UKS6jxY=";
  };
  vectorcraft = {
    version = "0.21.1";
    hash = "sha256-FihvIL0Wh+mvOhfxBkRr2sgPOUcInl0QK7Ggj0HSKfI=";
  };
  filmcraft = {
    version = "0.17.1";
    hash = "sha256-ljl39yREXeLFd7eTZJQ3gMAUfIiDP05+d91Kz11x2Gs=";
  };
  lightcraft = {
    version = "0.18.1";
    hash = "sha256-MRzFGrysq5CL1wptL8BHQtFcq2ylY8zIdJVpZOocUZU=";
  };
  pdfcraft = {
    version = "0.18.2";
    hash = "sha256-ywbIJTPvZ2Qd9o/8XZuGDbbHarn+aa6tG0omrWo4vcg=";
  };
  effectcraft = {
    version = "0.21.1";
    hash = "sha256-4PwnbS5Zo8DeqMHPYssRtIC0/A6ZKoO6LSsEHd0PnG0=";
  };
  designcraft = {
    version = "0.17.2";
    hash = "sha256-ZmggfkXtKzOCTQgeuV0gRR84gM3AvoibRGjalDVp5bo=";
  };
  figcraft = {
    version = "0.15.1";
    hash = "sha256-C8j7P/Zj4O6l5MFxGmjXonvlGXxAH88L7iIPMPEAC7g=";
  };
  soundcraft = {
    version = "0.17.1";
    hash = "sha256-7EgtCTlFZ8VjaeqJ7wLo7dAadzsu6csqtJYw7okOsPY=";
  };
  deckcraft = {
    version = "0.15.1";
    hash = "sha256-4i9rGw6BdvjkdrAK9oH+IRO57BwrI0ZD1BAcqM/hLvQ=";
  };
  cadcraft = {
    version = "0.17.1";
    hash = "sha256-M9WMsdXC4Qz8sgns/KhvL7OCX99IpiJEjemnfhR4mrs=";
  };
  gridcraft = {
    version = "0.16.1";
    hash = "sha256-zZqjrla+aEINji1xo/9ubTCW6/UeeEFD5rx0zpLsLyY=";
  };
}
