args @ { pkgs, lib, config, nixpkgs, options, specialArgs, nixosConfig }:
let
  ardan = (import ./common.nix) args;
in
ardan
