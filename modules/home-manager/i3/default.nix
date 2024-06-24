{ pkgs, lib, config, ... }:
let
  cfg = config.dev.johnrinehart.i3;
in {
  options.dev.johnrinehart.i3 = {
    enable = lib.mkEnableOption "John's i3 config";
  };

  config = lib.mkIf cfg.enable {
    dev.johnrinehart.xorg.enable = true;

    services.xserver.windowManager.i3 = {
      configFile = ./i3.conf;
      enable = true;
    };
  };
}
