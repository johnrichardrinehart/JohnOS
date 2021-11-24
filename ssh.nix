{ config, pkgs, ... }:
{
  # Enable the OpenSSH daemon
  services.openssh.enable = true;
  services.openssh.permitRootLogin = "yes";
  # Open the firewall
  networking.firewall.allowedTCPPorts = [ 22 ];
}
