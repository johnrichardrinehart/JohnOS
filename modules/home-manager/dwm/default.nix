{ config, lib, pkgs, ... }:
let cfg = config.dev.johnrinehart.dwm; in {
  options.dev.johnrinehart.dwm = {
    enable = lib.mkEnableOption "John's DWM config";
  };

  config = lib.mkIf cfg.enable  {
    environment.systemPackages = [ pkgs.st ];

    nixpkgs.overlays = [
      (self: super: {
        dwm = super.dwm.override { conf = ./dwm.conf.h; };
      })
    ];

    services.xserver.windowManager.dwm.enable = true;
  };
}

