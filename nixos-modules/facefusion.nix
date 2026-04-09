{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.facefusion;
in
{
  options.dev.johnrinehart.facefusion = {
    enable = lib.mkEnableOption "FaceFusion webcam lab support";

    virtualCamera = {
      enable = lib.mkEnableOption "v4l2loopback virtual camera output";

      deviceNumber = lib.mkOption {
        type = lib.types.int;
        default = 9;
        description = "Virtual camera device number for v4l2loopback.";
      };

      cardLabel = lib.mkOption {
        type = lib.types.str;
        default = "FaceFusion Camera";
        description = "Card label exposed by the v4l2loopback virtual camera.";
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      environment.systemPackages = [
        pkgs.facefusion
        pkgs.ffmpeg_7-full
        pkgs.obs-studio
      ];
    }

    (lib.mkIf cfg.virtualCamera.enable {
      boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
      boot.kernelModules = [ "v4l2loopback" ];
      boot.extraModprobeConfig = ''
        options v4l2loopback video_nr=${toString cfg.virtualCamera.deviceNumber} card_label="${cfg.virtualCamera.cardLabel}" exclusive_caps=1
      '';
    })
  ]);
}
