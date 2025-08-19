{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.xmonad;
in
{
  options.dev.johnrinehart.xmonad = {
    enable = lib.mkEnableOption "John's xmonad configuration" // {
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    # Xmonad configuration can be added here
  };
}