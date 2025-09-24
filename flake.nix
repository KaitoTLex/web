# flake.nix
{
  description = "This is a simple elm development ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          name = "elm-dev-shell";

          packages = with pkgs; [
            elmPackages.elm
            elmPackages.elm-format
            nodejs_20 # or nodejs-18_x if preferred
            # Optional: add live server for development
            nodePackages.live-server
          ];

          shellHook = ''
            echo "Welcome to your Elm development environment!"
            echo "Available commands: elm, elm-format, live-server"
          '';
        };
      }
    );
}
