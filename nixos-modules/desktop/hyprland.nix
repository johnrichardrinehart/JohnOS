{
  config,
  lib,
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
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };

    programs.hyprland.enable = true;

    users.users.john.extraGroups = [ "seat" ];

    services.greetd.enable = true;
    services.greetd.settings.default_session = {
      command = "${lib.getExe config.programs.hyprland.package}";
      user = "john";
    };
  };
}
