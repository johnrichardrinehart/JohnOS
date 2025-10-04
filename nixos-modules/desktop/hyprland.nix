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
  }
  // {
    default = false;
  };

  config = lib.mkIf cfg.enable {
    programs.hyprland.enable = true;
  };
}
