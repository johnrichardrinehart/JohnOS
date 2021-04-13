{config, pkgs, ...}:
{
	require = [
		./iso-image.nix
	];

	isoImage.isoBaseName = "johnos";
	isoImage.makeEfiBootable = true;
}
