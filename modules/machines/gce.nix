args @ { config, pkgs, ... }:
{
  console.useXkbConfig = true;

  programs.zsh.enable = true;

  environment.systemPackages = [
    pkgs.tmux
    pkgs.vim
    pkgs.git
    pkgs.nixpkgs-fmt
  ];

  virtualisation.docker.enable = true;

  services = {
    sshd = {
      enable = true;
    };

    headscale = {
      settings.log = {
        level = "debug";
        format = "json";
      };
      port = 443;
      address = "0.0.0.0";
      enable = true;
    };
  };

  networking = {
    useDHCP = pkgs.lib.mkForce true;
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
    firewall.allowedTCPPorts = [ ];
  };

  nixpkgs.config = {
    allowUnsupportedSystem = true;
    config.allowUnfree = true;
  };
}
