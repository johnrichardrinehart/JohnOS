{ lib, pkgs, config, osConfig, ... }:
let
    cfg = config.dev.johnrinehart.xmonad;
in
{
  options.dev.johnrinehart.xmonad = {
    enable = lib.mkEnableOption "John's xmonad config";
  };

  config = lib.mkIf cfg.enable {
    dev.johnrinehart.xorg.enable = true;

    services.xserver.windowManager.xmonad = {
      enable = true;
      enableContribAndExtras = true;

      extraPackages = hp: [
        hp.dbus
        hp.monad-logger
      ];

      config = ./config.hs;
    };
  };
}
