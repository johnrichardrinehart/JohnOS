args @ { pkgs, lib, config, nixpkgs, options, specialArgs, nixosConfig }:
let
  extraPackages = let p = pkgs; in
    [
      # games
      p.gnuchess
      p.stockfish
      p.scid-vs-pc
      # tools
      p.unzip
      p.polybar
      # CLI
      p.fzf
      p.jump
      # development
      p.ghc
      # instant messengers
      p.tdesktop
      p.signal-desktop
    ];
in
(import ./common.nix) (args // { inherit extraPackages; })

