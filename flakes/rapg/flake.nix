# SPDX-License-Identifier: GPL-3.0-or-later
{
  description = "rapg — single-binary, local-first secret manager for the AI-agent era";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      packages.${system}.default = pkgs.buildGoModule {
        pname = "rapg";
        version = "0-unstable";

        src = pkgs.fetchFromGitHub {
          owner = "kanywst";
          repo = "rapg";
          rev = "70979aaf12c070c19221b30847dbb363f9fe47cf";
          hash = "sha256-oWXjWRjaH5LrdFYycAH/8Dokin1/y1U8DILLKiuDkjc=";
        };

        vendorHash = "sha256-wKMvYSgce4VMCWnH2PihtXg5uGdIVOiosuXsT0RcBfg=";

        # SQLite driver (mattn/go-sqlite3) requires CGO
        nativeBuildInputs = [ pkgs.pkg-config ];
        buildInputs = [ pkgs.sqlite ];

        subPackages = [ "cmd/rapg" ];

        meta = {
          description = "Single-binary, local-first secret manager for the AI-agent era";
          homepage = "https://github.com/kanywst/rapg";
          license = pkgs.lib.licenses.mit;
          mainProgram = "rapg";
        };
      };

      apps.${system}.default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/rapg";
      };
    };
}
