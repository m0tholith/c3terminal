{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    c3c = {
      flake = true;
      url = "github:c3lang/c3c";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      c3c,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          (c3c.outputs.packages.${system}.default)
          glfw

          clang-tools
          clang

          # debugging
          gdb
          renderdoc
          valgrind
        ];
      };
    };
}
