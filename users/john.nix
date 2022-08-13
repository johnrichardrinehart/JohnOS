args @ { pkgs, lib, config, nixpkgs, options, specialArgs, nixosConfig, ... }:
let
  pp =
    let p = pkgs;
    in
    [
      # games
      p.gnuchess
      p.stockfish
      p.scid-vs-pc
      # CLI
      p.fzf
      # instant messengers
      p.tdesktop
      p.signal-desktop
      p.discord
      p.element-desktop
      p.skypeforlinux
      # development tools
      p.google-cloud-sdk
      p.cloud-sql-proxy
    ];
in
import ./common.nix (args // { inherit pp; })
