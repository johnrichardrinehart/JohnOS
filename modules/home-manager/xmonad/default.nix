{
  lib,
  pkgs,
  config,
  osConfig,
  ...
}:
let
  cfg = config.dev.johnrinehart.xmonad;
in
{
  options.dev.johnrinehart.xmonad = {
    enable = lib.mkEnableOption "John's xmonad config";
  };

  config = lib.mkIf cfg.enable {
    dev.johnrinehart.xorg.enable = true;
  };
}
