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
    services.displayManager.enable = true;

    services.xserver.windowManager = {
      xmonad = {
        enable = true;
        config = builtins.readFile ../home-configurations/home-manager/xmonad/config.hs;
        enableContribAndExtras = true;
        extraPackages = haskellPackages: [
          haskellPackages.dbus
          haskellPackages.List
          haskellPackages.monad-logger
        ];
      };
    };
  };
}
