{
  inputs = {
    nixpkgs.url = "github:johnrichardrinehart/nixpkgs?ref=rock-5c-nixos-25.11";

    flake-templates.url = "github:NixOS/templates/master";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
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
      overlays = import ./overlays inputs;
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [ overlays.default ];
      };
    in
    {
      nixosConfigurations = import ./nixos-configurations inputs;

      packages.${system} = import ./packages { inherit pkgs; };

      devShells.${system} = import ./dev-shells.nix { inherit pkgs; };

      inherit overlays;
    };
}
