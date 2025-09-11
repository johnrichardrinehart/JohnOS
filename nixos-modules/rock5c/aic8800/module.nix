{ pkgs, config, ... }:
let
  aic8800Src = (import ./src.nix) { inherit (pkgs) fetchFromGitHub; };
in
{
  boot.extraModprobeConfig = ''
    options aic_load_fw aic_fw_path="${aic8800Src}/src/USB/driver_fw/fw/aic8800D80"
  '';

  nixpkgs.overlays = [
    (final: prev: {
      aic8800 = prev.callPackage ./aic8800.nix {
        inherit (config.boot.kernelPackages) kernel kernelModuleMakeFlags;
      };
    })
  ];

  # It appears that the below aren't necessary. Maybe because of USB enumeration.
  boot.kernelModules = [
    "aic_btusb"
    "aic_load_fw"
    "aic8800_fdrv"
  ];

  boot.extraModulePackages = [ pkgs.aic8800 ];
}
