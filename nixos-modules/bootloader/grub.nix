{
  config,
  lib,
  options,
  ...
}:
let
  cfg = config.dev.johnrinehart.boot.loader.grub;
in
{
  options.dev.johnrinehart.boot.loader.grub = {
    enable = lib.mkEnableOption "John's GRUB2 config";

    device = lib.mkOption {
      type = options.boot.loader.grub.device.type;
      default = "/dev/sda";
      description = options.boot.loader.grub.device.description;
    };

    splashImage = lib.mkOption {
      type = lib.types.path;
      default = ../../static/ocean.jpg;
      description = options.boot.loader.grub.splashImage.description;
    };
  };

  config = lib.mkIf cfg.enable {
    boot.loader.grub = {
      enable = true;
      device = cfg.device;
      splashImage = cfg.splashImage;
      configurationLimit = 10;
    };
  };
}
