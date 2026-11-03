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
    version = "0.15.0";
    hash = "sha256-0j1piqHbC2lNRPqtkYX6mjJ4ihiy3exleiYK566R7mU=";
  };
  photocraft = {
    version = "0.20.1";
    hash = "sha256-oXh0i595z2GbA1jWX1vDeKZ917eC6czZCwMtfF+FiRI=";
  };
  vectorcraft = {
    version = "0.21.0";
    hash = "sha256-q0jUDrWYgTGPRC8Fc77sgvn5SZVoPhVvKlaSfDu9Pk8=";
  };
  filmcraft = {
    version = "0.17.0";
    hash = "sha256-eI129lzA5Eprrx4utQl6jhy5MB+N1ITifU+v7r/NNS8=";
  };
  lightcraft = {
    version = "0.18.0";
    hash = "sha256-ntb0tHqA/x9isQui/0LuFHegS3E9qH/4xM4j/ZouLKo=";
  };
  pdfcraft = {
    version = "0.18.0";
    hash = "sha256-oIhFZFn95QzFmHjb/aPnLjDEK3V77ERdB/g/8CWv7Ec=";
  };
  effectcraft = {
    version = "0.21.0";
    hash = "sha256-MBvci2aBq6ydqiKWxU2OnRaNdgL+NfCDrHPKJmcWUfQ=";
  };
  designcraft = {
    version = "0.17.0";
    hash = "sha256-Q9Zvh5fiQjFOBc94+83Jy7NlqMZhkANCGsbvqBKUINo=";
  };
  figcraft = {
    version = "0.15.0";
    hash = "sha256-FGO3WHAoQtqKCqbc8VyE97PmhhWIGTmMj7wkoO0hSqA=";
  };
  soundcraft = {
    version = "0.17.0";
    hash = "sha256-zrQtU56a7AzEgYh06S5kBXFjNbBX2eJAqKWVmP7zS64=";
  };
  deckcraft = {
    version = "0.15.0";
    hash = "sha256-SXtk3BSsbNICYKLPspssg7ed8zNucChoH9nxEu0i/as=";
  };
  cadcraft = {
    version = "0.17.0";
    hash = "sha256-ljfKCMuRFB/GeXENYS9VHhck0p9uqmG2O0s8qSlVO38=";
  };
  gridcraft = {
    version = "0.16.0";
    hash = "sha256-D+LI42uAgJJVnpX7clASC5sCLll6f7FUDjZq7ppNH7E=";
  };
}
