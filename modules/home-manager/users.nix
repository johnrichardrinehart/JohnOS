args @ { pkgs, lib, config, nixpkgs, options, specialArgs, nixosConfig, ... }:
let
  pkgs = [
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
      (p.google-cloud-sdk.withExtraComponents [ p.google-cloud-sdk.components.gke-gcloud-auth-plugin p.google-cloud-sdk.components.config-connector ])
      p.google-cloud-sql-proxy
    ];
in
import ./common.nix (args // { inherit pp; })

