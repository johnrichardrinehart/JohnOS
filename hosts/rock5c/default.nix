{
  lib,
  pkgs,
  config,
  ...
}:
let {
  imports = [
    ../desktop.nix
  ];

  networking.hostName = "rock5c-desktop";
  dev.johnrinehart.rock5c.enable = true;
}
