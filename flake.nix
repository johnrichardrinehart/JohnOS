{
  inputs = {
    nixpkgs.url = "github:johnrichardrinehart/nixpkgs?rev=f9cfdf3526a67b6e12c2b68c15d45125597c1f2d";

    flake-templates.url = "github:NixOS/templates/master";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    let
      system = "x86_64-linux";
      pkgs = inputs.nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations = import ./nixos-configurations inputs;

      homeConfigurations = import ./home-configurations inputs;

      packages.${system} = import ./packages { inherit pkgs; };

      devShells.${system} = import ./dev-shells.nix { inherit pkgs; };

      overlays = import ./overlays inputs;
    };
}
