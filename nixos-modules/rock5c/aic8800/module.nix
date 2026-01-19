{
  config,
  pkgs,
  lib,
  ...
}:
let
  aic8800Src = (import ./src.nix) { inherit (pkgs) fetchFromGitHub; };
  cfg = config.dev.johnrinehart.rock5c.aic8800;
in
{
  options.dev.johnrinehart.rock5c.aic8800 = {
    enable = lib.mkEnableOption "aic8800 driver";
  };

  config = lib.mkIf cfg.enable {
    boot.extraModprobeConfig = ''
      options aic_load_fw aic_fw_path="${aic8800Src}/src/USB/driver_fw/fw/aic8800D80"
      options aic8800_fdrv wifi_mac_addr="88:00:03:00:10:55"
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
  };
}
