{
  description = "John Rinehart's development OS";

  outputs = { self, nixpkgs }: {

    packages.x86_64-linux.johnos = ((import ./default.nix) {system="x86_64-linux";}).iso;

    defaultPackage.x86_64-linux = self.packages.x86_64-linux.johnos;

  };
}
