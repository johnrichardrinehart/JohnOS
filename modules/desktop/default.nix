{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.dev.johnrinehart.desktop;

  xorg-xmonad =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.dev.johnrinehart.desktop.xorg-xmonad;
    in
    {
      options.dev.johnrinehart.desktop.xorg-xmonad = {
        enable = lib.mkEnableOption "the Xorg with Xmonad configuration.";
      } // {
        default = false;
      };

      config = lib.mkIf cfg.enable {
        nixpkgs.config.allowUnfreePredicate =
          pkg:
          builtins.elem (lib.getName pkg) (
            lib.optional config.dev.johnrinehart.desktop.obsidian [ "obsidian" ]
          );

        nixpkgs.config.permittedInsecurePackages = lib.optional config.dev.johnrinehart.desktop.obsidian [
          "electron-25.9.0"
        ];

        environment.systemPackages = lib.optional config.dev.johnrinehart.desktop.obsidian [
          pkgs.obsidian
        ];

        dev.johnrinehart = {
          sound.enable = true;
          systemPackages.enable = true;
          xmonad.enable = true;
          bluetooth.enable = true;
        };
      };
    };

  wl-hyprland =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.dev.johnrinehart.desktop.wl-hyprland;
    in
    {
      options.dev.johnrinehart.desktop.wl-hyprland = {
        enable = lib.mkEnableOption "the Wayland with Hyprland configuration.";
      } // {
        default = false;
      };

      config = lib.mkIf cfg.enable { };
    };

  variants = { inherit xorg-xmonad wl-hyprland; };
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
      ];
      default = "xorg-xmonad";
      description = lib.mkEnableOption "reasonable desktop configuration variants.";
    };

    obsidian = lib.mkEnableOption "packaging Obsidian into the system.";
  };

  imports = [
    inputs.home-manager.nixosModules.default
    ./xorg.nix
    xorg-xmonad
    wl-hyprland
  ];

  config = lib.mkIf cfg.enable {
    dev.johnrinehart.desktop.xorg-xmonad.enable = (cfg.variant == "xorg-xmonad");
    dev.johnrinehart.desktop.wl-hyprland.enable = (cfg.variant == "wl-hyprland");
  };
}
