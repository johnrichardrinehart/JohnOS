{ lib, pkgs, ... }:
{
  imports = [ ./framework.nix ];

  nixpkgs.hostPlatform = "x86_64-linux";

  dev.johnrinehart.boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 5;
  };

  boot.loader = {
    efi.canTouchEfiVariables = true;
    timeout = 1;
  };

  fonts.fontconfig.enable = lib.mkForce true;
  services.sshd.enable = true;
  virtualisation.containers.enable = true;

  users.users.john.extraGroups = [ "input" ];

  dev.johnrinehart.system.enable = true;
  dev.johnrinehart.desktop = {
    enable = true;
    variant = "greetd+niri";
  };

  dev.johnrinehart.systemPackages.enable = true;

  services.fprintd.enable = true;

  dev.johnrinehart.terminal.filepicker.enable = true;
}
