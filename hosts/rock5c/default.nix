{ lib, pkgs, config, ... }: {
  networking.hostName = "rocky";
  dev.johnrinehart.rock5c.enable = true;
}
