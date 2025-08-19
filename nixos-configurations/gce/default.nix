args@{ config, pkgs, ... }:
{
  nixpkgs.hostPlatform = "x86_64-linux";
  
  # Boot configuration
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };
  
  # Filesystem configuration
  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };

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
        dns = {
          base_domain = "headscale.johnrinehart.dev";
        };
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
