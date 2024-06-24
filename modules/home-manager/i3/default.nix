{ pkgs, lib, config, ... }:
let
  cfg = config.dev.johnrinehart.i3;
in {
  options.dev.johnrinehart.i3 = {
    enable = lib.mkEnableOption "John's i3 config";
  };

  config = lib.mkIf cfg.enable {
    dev.johnrinehart.xorg.enable = true;

    #home-manager.users = lib.mapAttrs (k: v: v.extendModules {
    #  modules = [{
    #    home.file."config/i3status/net-speed.sh" = {
    #      source = ./net-speed.sh;
    #      executable = true;
    #    };
    #  }];
    #});

    services.xserver.windowManager.i3 = {
      configFile = ./i3.conf;
      enable = true;
    };
  };
}
