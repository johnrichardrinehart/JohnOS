args @ { pkgs, lib, config, nixpkgs, options, specialArgs, nixosConfig }:
let
  extraPackages = let p = pkgs; in
    [
      p.teams
    ];
in
(import ./common.nix) (args // { inherit extraPackages; })
