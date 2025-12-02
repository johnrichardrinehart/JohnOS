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
    ./greetd+niri.nix
  ];

  config = lib.mkIf cfg.enable {
    networking.networkmanager.enable = true;
    dev.johnrinehart.desktop.xorg-xmonad.enable = (cfg.variant == "xorg-xmonad");
    dev.johnrinehart.desktop.wl-hyprland.enable = (cfg.variant == "wl-hyprland");
    dev.johnrinehart.desktop.greetd_niri.enable = (cfg.variant == "greetd+niri");
  };
}
