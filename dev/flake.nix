{
  description = "Internal development inputs for JohnOS partitions";

  inputs = {
    nixpkgs.url = "github:johnrichardrinehart/nixpkgs?ref=rock-5c-nixos-26.05";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: { inherit inputs; };
}
