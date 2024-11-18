{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.kernel.latest;
in
{
  options.dev.johnrinehart.kernel.latest = {
    enable = lib.mkEnableOption "latest kernel";
  };

  config = lib.mkIf cfg.enable {
    boot.kernelPackages = pkgs.linuxPackages_latest;
  };
}
