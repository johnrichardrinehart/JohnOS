{config, pkgs, ...}:
{
#	networking.networkmanager.enable = true;
        config.networking.wireless.enable = true;
        config.networking.wireless.networks = { AstroNet = { psk = "N0Pa$$w0rd"; }; };
	config.networking.hostName = "mynixos";
        config.boot.kernelPackages = pkgs.linuxPackages_latest;
 	config.hardware.enableRedistributableFirmware = true;
        config.hardware.enableAllFirmware = true;
        config.hardware.firmware = [ pkgs.wireless-regdb ];
}
