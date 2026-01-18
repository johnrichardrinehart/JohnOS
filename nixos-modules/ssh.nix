{ config, pkgs, ... }:
{
  # Enable the OpenSSH daemon
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";
  # Open the firewall
  networking.firewall.allowedTCPPorts = [ 22 ];

  # Don't spam logs with refused connections
  networking.firewall.logRefusedConnections = false;
}
