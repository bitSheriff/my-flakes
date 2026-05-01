{
  description = "A simple Typst project environment and build system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      # Supporting Linux and macOS
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.stdenvNoCC.mkDerivation {
            name = "typst-document";
            # Brings in everything in the current directory
            src = ./.;

            # We only need the typst compiler
            nativeBuildInputs = [ pkgs.typst ];

            buildPhase = ''
              # Nix builds happen in a pure, isolated environment.
              # Typst tries to write to the font cache, which fails if HOME is read-only.
              # This creates a temporary writable directory to prevent errors.
              export XDG_CACHE_HOME=$(mktemp -d)

              # Compile the document
              typst compile main.typ
            '';

            installPhase = ''
              mkdir -p $out
              # Move the resulting PDF to the output directory
              cp main.pdf $out/
            '';
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              typst # The compiler
              tinymist # The officially recommended modern LSP for VSCode/Neovim
              typstfmt # Optional: A code formatter
            ];

            shellHook = ''
              echo "Typst environment loaded!"
            '';
          };
        }
      );
    };
}
