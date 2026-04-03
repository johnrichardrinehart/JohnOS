{
  config,
  lib,
  ...
}:
let
  cfg = config.dev.johnrinehart.desktop.wl-kwin;
in
{
  options.dev.johnrinehart.desktop.wl-kwin = {
    enable = lib.mkEnableOption "the Wayland with KWin/Plasma configuration.";
  }
  // {
    default = false;
  };

  config = lib.mkIf cfg.enable {
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };

    services.desktopManager.plasma6.enable = true;
    services.displayManager.sddm.enable = true;
    services.displayManager.sddm.wayland.enable = true;
    services.displayManager.autoLogin.enable = true;
    services.displayManager.autoLogin.user = "john";
    services.displayManager.defaultSession = lib.mkDefault "plasma";
  };
}
