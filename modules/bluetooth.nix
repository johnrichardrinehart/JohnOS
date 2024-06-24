{ config, pkgs, lib, ... }:
let cfg = config.dev.johnrinehart.bluetooth; in {
  options.dev.johnrinehart.bluetooth = {
    enable = lib.mkEnableOption "John's Bluetooth settings.";
  };

  config = lib.mkIf cfg.enable {
    hardware.bluetooth = {
      enable = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
        };
      };
    };

    services.blueman.enable = true;
  };
}
