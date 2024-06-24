{ lib, ... }: 
let cfg = config.dev.johnrinehart.network; in {
  options = {
    dev.johnrinehart.network = {
      enable = lib.mkEnableOption "John's opinionated network config";
    };
  };

  config = {
    networking.networkmanager.enable = true;
    networking.wireless.enable = false;
    networking.extraHosts = ''
      45.63.61.99 mongoloid
    '';
  };
}
