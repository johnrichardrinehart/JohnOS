{ pkgs, lib, ... }:
{

  home.file."config/i3status/net-speed.sh" = {
    source = ./net-speed.sh;
    executable = true;
  };

  environment.systemPackages = with pkgs; [
    alacritty
  ];
  services.xserver.windowManager.i3.enable = true;
}
