args @ { pkgs, lib, config, nixpkgs, options, specialArgs, nixosConfig }:
let
  extraPackages = [ pkgs.gnuchess pkgs.stockfish pkgs.scid-vs-pc ];
  john = (import ./common.nix) (args // { inherit extraPackages; });
in
john
