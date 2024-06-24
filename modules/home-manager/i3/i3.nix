{ pkgs, lib, ... }:
let cfg = config.dev.johnrinehart.i3; in {
  options.dev.johnrinehart.i3 = {
    enable = lib.mkEnableOption "John's i3 config";
  };
  config = lib.mkIf cfg.enable {
    home.file."config/i3status/net-speed.sh" = {
      source = ./net-speed.sh;
      executable = true;
    };

    services.xserver.windowManager.i3 = {
      configFile = ./i3.conf;
      enable = true;
    };
  };
}
