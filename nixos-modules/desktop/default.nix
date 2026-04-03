{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.dev.johnrinehart.desktop;
in
{
  options.dev.johnrinehart.desktop = {
    enable = lib.mkEnableOption "the Wayland with Hyprland configuration." // {
      default = false;
    };
    variant = lib.mkOption {
      type = lib.types.enum [
        "xorg-xmonad"
        "wl-hyprland"
        "wl-kwin"
        "greetd+niri"
      ];
      default = "xorg-xmonad";
      description = lib.mkEnableOption "reasonable desktop configuration variants.";
    };

    obsidian = lib.mkEnableOption "packaging Obsidian into the system.";
  };

  imports = [
    ../../home-configurations/home-manager
    inputs.home-manager.nixosModules.default
    ./xorg-xmonad.nix
    ./hyprland.nix
    ./kwin.nix
    ./greetd+niri.nix
  ];

  config = lib.mkIf cfg.enable {
    dev.johnrinehart.home-manager.packages.shell.enable = lib.mkDefault true;
    dev.johnrinehart.home-manager.packages.games.enable = lib.mkDefault true;
    dev.johnrinehart.home-manager.packages.messaging.enable = lib.mkDefault true;

    home-manager.users.john.idle = {
      short_timeout_duration = 60*5;
      medium_timeout_duration = 60*6;
      long_timeout_duration = 60*10;
    };
    networking.networkmanager.enable = true;
    dev.johnrinehart.desktop.xorg-xmonad.enable = (cfg.variant == "xorg-xmonad");
    dev.johnrinehart.desktop.wl-hyprland.enable = (cfg.variant == "wl-hyprland");
    dev.johnrinehart.desktop.wl-kwin.enable = (cfg.variant == "wl-kwin");
    dev.johnrinehart.desktop.greetd_niri.enable = (cfg.variant == "greetd+niri");
  };
}
