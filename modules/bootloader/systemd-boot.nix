{ config, lib, options, ... }: 
let cfg = config.dev.johnrinehart.boot.loader.systemd-boot; in {
  options.dev.johnrinehart.boot.loader.systemd-boot = {
    enable = lib.mkEnableOption "John's system-boot config";
  };

  config = lib.mkIf cfg.enable {
    boot.loader.systemd-boot = {
      enable = true;
      configurationLimit = 20;
    };
  };
}

