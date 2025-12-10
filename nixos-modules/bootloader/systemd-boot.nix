{
  config,
  lib,
  options,
  ...
}:
let
  cfg = config.dev.johnrinehart.boot.loader.systemd-boot;
in
{
  options.dev.johnrinehart.boot.loader.systemd-boot = {
    enable = lib.mkEnableOption "John's system-boot config";
    configurationLimit = lib.mkOption {
      description = "Number of generations to preserve in the boot list";
      default = 20;
      type = lib.types.int;
    };
  };

  config = lib.mkIf cfg.enable {
    boot.loader.systemd-boot = {
      enable = true;
      configurationLimit = cfg.configurationLimit;
    };

    # Mount point '/boot' which backs the random seed file is world accessible, which is a security hole!
    # and
    # Random seed file '/boot/loader/random-seed' is world accessible, which is a security hole!
    fileSystems."/boot".options = [
      "umask=0077"
      "defaults"
    ];
  };
}
