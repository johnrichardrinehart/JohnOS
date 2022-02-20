args @ { config, pkgs, ... }:
{
  boot.loader.grub = {
    enable = true;
    version = 2;
    # Define on which hard drive you want to install Grub.
    device = "/dev/vda"; # or "nodev" for efi only
  };

  # Set your time zone.
  time.timeZone = "Europe/Kiev";

  console.useXkbConfig = true;

  programs.zsh.enable = true;

  environment.systemPackages = [
    pkgs.git
  ];

  virtualisation.docker.enable = true;

  networking = {
    useDHCP = pkgs.lib.mkForce true;
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
    firewall.allowedTCPPorts = [ ];
  };

  nixpkgs.config = {
    allowUnsupportedSystem = true;
    config.allowUnfree = true;
  };

  nixpkgs.config = {
    allowUnsupportedSystem = true;
    config.allowUnfree = true;
  };

  system.stateVersion = "21.05"; # Did you read the comment?
}
