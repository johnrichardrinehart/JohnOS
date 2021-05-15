{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # agenix implementation borrowed from https://github.com/pimeys/system-flake
    agenix.url = "github:ryantm/agenix";
  };

  outputs = inputs:
    let
      home-manager-config = {
        config = {
          home-manager = {
            useUserPackages = true;
            users.john = ./users/john.nix;
            users.ardan = ./users/ardan.nix;
          };
        };
      };
    in
    {
      nixosConfigurations.nixos = with inputs.nixpkgs; lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          inputs.agenix.nixosModules.age
          inputs.home-manager.nixosModules.home-manager
          home-manager-config
        ];

        specialArgs = { inherit (inputs) nixpkgs agenix; };
      };
    };
}
