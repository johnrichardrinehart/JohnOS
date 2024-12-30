{
  imports = [
    ../desktop.nix
  ];

  networking.hostName = "rock5c-desktop";
  dev.johnrinehart.rock5c.enable = true;
  dev.johnrinehart.system.enable = true;
}
