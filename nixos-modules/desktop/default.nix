{
  config,
  lib,
  ...
}:
let
  cfg = config.dev.johnrinehart.desktop;
  primaryUser = config.dev.johnrinehart.users.primary;
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
        "greetd+niri"
      ];
      default = "xorg-xmonad";
      description = "The desktop configuration variant to enable.";
    };

    obsidian = lib.mkEnableOption "packaging Obsidian into the system.";
  };

  imports = [
    ../../home-configurations/home-manager
    ./xorg-xmonad.nix
    ./hyprland.nix
    ./greetd+niri.nix
  ];

  config = lib.mkIf cfg.enable {
    dev.johnrinehart.home-manager.packages.shell.enable = lib.mkDefault true;
    dev.johnrinehart.home-manager.packages.games.enable = lib.mkDefault true;
    dev.johnrinehart.home-manager.packages.messaging.enable = lib.mkDefault true;

    home-manager.users.${primaryUser}.idle = {
      short_timeout_duration = 60 * 5;
      medium_timeout_duration = 60 * 6;
      long_timeout_duration = 60 * 10;
    };
    dev.johnrinehart.network.manager = lib.mkDefault "networkmanager";
    dev.johnrinehart.desktop.xorg-xmonad.enable = cfg.variant == "xorg-xmonad";
    dev.johnrinehart.desktop.wl-hyprland.enable = cfg.variant == "wl-hyprland";
    dev.johnrinehart.desktop.greetd_niri.enable = cfg.variant == "greetd+niri";
  };
}
