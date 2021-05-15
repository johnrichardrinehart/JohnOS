{ pkgs, lib, ... }:
{

  environment.systemPackages = with pkgs; [
    alacritty
  ];
  services.xserver.windowManager.i3.enable = true;
}
