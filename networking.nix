{config, pkgs, ...}:
{
#	networking.networkmanager.enable = true;
        networking.wireless.enable = true;
        networking.wireless.networks = { AstroNet = { psk = "N0Pa$$w0rd"; }; };
	networking.hostName = "mynixos";
        boot.kernelPackages = pkgs.linuxPackages_latest;
 	hardware.enableRedistributableFirmware = true;
        hardware.enableAllFirmware = true;
        hardware.firmware = [ pkgs.wireless-regdb ];
	nixpkgs.config.allowUnfree = true;
}
