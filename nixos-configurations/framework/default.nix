{ lib, ... }:
{
  imports = [ ./framework.nix ];

  nixpkgs.hostPlatform = "x86_64-linux";

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = true;
  fonts.fontconfig.enable = lib.mkForce true;
  services.sshd.enable = true;
  virtualisation.containers.enable = true;

  dev.johnrinehart.system.enable = true;
  dev.johnrinehart.desktop = {
    enable = true;
    variant = "xorg-xmonad";
  };
}
