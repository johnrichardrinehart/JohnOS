{ inputs, lib, ... }:
{
  imports = [ inputs.rock5c-nixos.nixosModules.default ];

  nixpkgs.overlays = [ inputs.rock5c-nixos.overlays.default ];
  nixpkgs.hostPlatform = "aarch64-linux";
  nixpkgs.config.allowUnfreePredicate =
    pkg: builtins.elem (lib.getName pkg) [ "arm-trusted-firmware-rk3588" ];

  networking.hostName = "rock5c-desktop";
  dev.johnrinehart.desktop.enable = true;
  dev.johnrinehart.system.enable = true;
  dev.johnrinehart.nix.enable = true;
  rock5c.enable = true;
  rock5c.aic8800.enable = true;

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  nixpkgs.config.permittedInsecurePackages = [ "python-2.7.18.8" ];
}
