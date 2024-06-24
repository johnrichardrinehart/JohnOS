{ config, pkgs, lib, ... }:
let cfg = config.dev.johnrinehart.sound; in
{
  options.dev.johnrinehart.sound = {
    enable = lib.mkEnableOption "John's sound config";
  };

  config = lib.mkIf cfg.enable {
    sound.enable = true;
    hardware.pulseaudio = {
      enable = true;
      support32Bit = true;
      package = pkgs.pulseaudioFull;
      extraConfig = "load-module module-switch-on-connect";
    };
  };
}

