{ lib, pkgs, ... }:
{
  nixpkgs.hostPlatform = "aarch64-linux";
  nixpkgs.config.allowUnfreePredicate =
    pkg: builtins.elem (lib.getName pkg) [ "arm-trusted-firmware-rk3588" ];
  nixpkgs.config.permittedInsecurePackages = [ "python-2.7.18.8" ];

  networking.hostName = "rock5c";
  rock5c.enable = true;

  dev.johnrinehart.system.enable = true;
  dev.johnrinehart.nix.enable = true;
  dev.johnrinehart.desktop = {
    enable = true;
    variant = "greetd+niri";
  };

  services.hypridle.enable = lib.mkForce false;

  boot.consoleLogLevel = 7;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "libata.force=noncq" ];
  boot.kernelModules = [ "dm_cache" ];
}
