args@{ config, pkgs, ... }:
{
  console.useXkbConfig = true;

  programs.zsh.enable = true;

  environment.systemPackages = [
    pkgs.tmux
    pkgs.vim
    pkgs.git
    pkgs.nixpkgs-fmt
    pkgs.headscale # put it on the path
  ];

  virtualisation.docker.enable = true;

  services = {
    sshd = {
      enable = true;
    };

    headscale = {
      settings = {
        log = {
          level = "debug";
          format = "json";
        };
        server_url = "https://headscale.johnrinehart.dev.";
      };
      port = 80;
      address = "0.0.0.0";
      enable = true;
    };
  };

  networking = {
    hostName = "headscale";
    useDHCP = pkgs.lib.mkForce true;
    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];
  };

  nixpkgs.config = {
    allowUnsupportedSystem = true;
    config.allowUnfree = true;
  };
}
