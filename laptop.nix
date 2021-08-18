args @ { config, pkgs, ... }:
{

  services.xserver.dpi = 4;
  networking.wireless.userControlled.enable = true;
  networking.wireless.networks.EpsteinDidntKillHimself5G.pskRaw = "1ccdb453d26a04c707084d33728e26a34c78f8712f878366b4ad129800dff828";
  networking.networkmanager.enable = true;
  hardware.pulseaudio.enable = true;

  # disabled by installation-cd-minimal
  fonts.fontconfig.enable = pkgs.lib.mkForce true;
}
