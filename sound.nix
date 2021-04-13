{config, pkgs, ...}:
{
#	boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linux_latest;
	sound.enable = true;
	hardware.pulseaudio = {
		enable = true;
		support32Bit = true;
		extraModules = [ pkgs.pulseaudio-modules-bt ];
		package = pkgs.pulseaudioFull;
		extraConfig = "load-module module-switch-on-connect";
};
	boot.extraModprobeConfig = ''
options snd-hda-intel model=alc295-hp-x360
'';
}
