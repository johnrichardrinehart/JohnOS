{config, pkgs, ...}:
{
	require = [
		./encrypted-iso-image.nix
	];

	isoImage.isoBaseName = "johnos";
	isoImage.makeEfiBootable = true;
}
