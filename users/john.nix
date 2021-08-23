args @ { pkgs, lib, config, nixpkgs, options, specialArgs, nixosConfig, ... }:
let
  extraPackages = let p = pkgs; in
    [
      # games
      p.gnuchess
      p.stockfish
      p.scid-vs-pc
      # CLI
      p.fzf
      # development
      p.ghc
      # instant messengers
      p.tdesktop
      p.signal-desktop
    ];

  programs = { };
in
(import ./common.nix) (args // { inherit extraPackages programs; })

