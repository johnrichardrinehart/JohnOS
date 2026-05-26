# httpn://discourse.nixos.org/t/load-automatically-kernel-module-and-deal-with-parameters/9200
{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.dev.johnrinehart.droidcam;
  droidcamDrv = pkgs.dev.johnrinehart.droidcam-v4l2loopback.override {
    inherit (config.boot.kernelPackages) kernel;
  };
in
{
  options.dev.johnrinehart.droidcam = {
    enable = lib.mkEnableOption "DroidCam V4L2 plug-in";
  };

  config = lib.mkIf cfg.enable {
    # below stolen from https://gist.github.com/TheSirC/93130f70cc280cdcdff89faf8d4e98ab
    environment.systemPackages = [ pkgs.droidcam ];
    boot.extraModulePackages = [ droidcamDrv ];
    boot.kernelModules = [ "v4l2loopback-dc" ];
  };
}
