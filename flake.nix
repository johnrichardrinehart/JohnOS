{
  inputs = {
    nixpkgs.url = "github:johnrichardrinehart/nixpkgs?ref=rock-5c";

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

  outputs = inputs: {
    nixosConfigurations = import ./hosts inputs;
    overlays = import ./overlays inputs;
  };
}
