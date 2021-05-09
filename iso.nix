args @ {config, pkgs, ...}:
{
	require = [
		({config, lib, pkgs, ...}: import ./iso-image.nix args)
	];

	isoImage.isoBaseName = "johnos";
	isoImage.makeEfiBootable = true;
}
