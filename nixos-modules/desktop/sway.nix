{
  config,
  lib,
  ...
}:
let
  cfg = config.dev.johnrinehart.desktop.wl-sway;
in
{
  options.dev.johnrinehart.desktop.wl-sway = {
    enable = lib.mkEnableOption "the Wayland with Sway configuration.";
  }
  // {
    default = false;
  };

  config = lib.mkIf cfg.enable {
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };

    programs.sway.enable = true;

    users.users.john.extraGroups = [ "seat" ];

    services.greetd.enable = true;
    services.greetd.settings.default_session = {
      command = "${lib.getExe config.programs.sway.package}";
      user = "john";
    };
  };
}
