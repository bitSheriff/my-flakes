{
  description = "My personal Nix packages monorepo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      # Define the systems you want to build for
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      #### PACKAGES ####
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          jdownloader2 = pkgs.callPackage ./pkgs/jdownloader2 { };
          siggy = pkgs.callPackage ./pkgs/siggy { };
        }
      );

      #### FLAKE TEMPLATES ####
      templates = {
        f1tenth-dev = {
          path = ./templates/f1tenth;
          description = "Development and simulation environment for Ros2 F1Tenth";
        };
        simple-typst = {
          path = ./templates/typst/simple-typst;
          description = "Simple Typst template with everything you need";
        };

      };
    };
}
