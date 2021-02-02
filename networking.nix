{config, pkgs, ...}:
{
	networking.hostName = "mynixos";
	
    # Open ports in the firewall
    networking.firewall.allowedTCPPorts = [ 22 ];
}