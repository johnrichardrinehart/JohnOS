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

  environment.etc."xdg/hypr/hyprland.conf".text = lib.mkBefore ''
    # Kodi/mpv HDR playback can enable Hyprland's wide color gamut path. Hyprland
    # requires a 10-bit output mode for that path; otherwise it warns that wide
    # color gamut is enabled while the display is still in 8-bit mode.
    monitor = , preferred, auto, 1, bitdepth, 10, cm, auto

  '';
}
