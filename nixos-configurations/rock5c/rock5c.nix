{
  config,
  lib,
  ...
}:
{
  rock5c.enable = true;
  rock5c.videoBackend = "mpp";
  rock5c.aic8800 = {
    enable = true;
    stableMac = {
      enable = true;
      address = "88:00:03:00:10:55";
    };
  };
  rock5c.gstreamerHwdec.enable = true;
  rock5c.media = {
    enable = true;
    kodi = {
      variant = "wayland";
      autostart.enable = true;
      disableCecStandbyOnExit = true;
    };
  };
  rock5c.rkvdec.enable =
    lib.mkDefault (config.rock5c.videoBackend == "mainline");
  rock5c.sessions.hyprland = {
    enable = true;
    user = "john";
  };
}
