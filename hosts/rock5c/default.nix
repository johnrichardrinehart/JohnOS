{ lib, ... }:
{
  nixpkgs.config.allowUnfreePredicate =
    pkg: builtins.elem (lib.getName pkg) [ "arm-trusted-firmware-rk3588" ];

  networking.hostName = "rock5c-desktop";
  dev.johnrinehart.desktop.enable = true;
  dev.johnrinehart.rock5c.enable = true;
  dev.johnrinehart.system.enable = true;
  dev.johnrinehart.nix.enable = true;

  nixpkgs.config.permittedInsecurePackages = [ "python-2.7.18.8" ];
}
