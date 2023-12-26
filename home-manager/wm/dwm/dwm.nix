{ pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    st
  ];

  nixpkgs.overlays = [
    (self: super: {
      dwm = super.dwm.override { conf = ./dwm.conf.h; };
    })
  ];

  services.xserver.windowManager.dwm.enable = true;
}
