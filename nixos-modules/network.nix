{ lib, config, ... }:
let
  cfg = config.dev.johnrinehart.network;
in
{
  options = {
    dev.johnrinehart.network = {
      enable = lib.mkEnableOption "John's opinionated network config";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale.enable = true;

    networking.nameservers = [
      "1.1.1.1"
      "8.8.8.8"
      "6.6.6.6"
    ];
    networking.resolvconf.enable = true;
    networking.networkmanager.enable = true;
    networking.wireless.enable = false;

    networking.networkmanager.unmanaged = [ "tailscale0" ];
  };
}
