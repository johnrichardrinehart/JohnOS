args @ { pkgs, lib, config, nixpkgs, options, specialArgs, nixosConfig }:
let
  extraPackages = with pkgs; [ gnuchess stockfish scid-vs-pc unzip ];
  john = (import ./common.nix) (args // { inherit extraPackages; });
in
john
