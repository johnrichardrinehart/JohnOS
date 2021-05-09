{
  description = "John Rinehart's development OS";

  inputs = {
	nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small"; # github.com/i077/system/master/flake.nix#L6
  };

  outputs = { self, nixpkgs }: {

    packages.x86_64-linux.johnos = (import ./default.nix {lib = (import nixpkgs {system="x86_64-linux";}); } ).iso;

    defaultPackage.x86_64-linux = self.packages.x86_64-linux.johnos;

  };
}
