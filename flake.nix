{
  description = "John Rinehart's development OS";

  inputs = {
	nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # github.com/i077/system/master/flake.nix#L6
  };

  outputs = { self, nixpkgs }: {

     nixosConfigurations = {
              iso = nixpkgs.lib.nixosSystem {
                system = "x86_64-linux";
		modules = import ./default.nix {};
		};
     };     

    packages.x86_64-linux.johnos = self.nixosConfigurations.iso.config.system.build.isoImage;

    defaultPackage.x86_64-linux = self.packages.x86_64-linux.johnos;

  };
}
