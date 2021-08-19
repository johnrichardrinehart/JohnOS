args @ { config, pkgs, ... }:
{
  hardware.pulseaudio.enable = true;

  # disabled by installation-cd-minimal
  fonts.fontconfig.enable = pkgs.lib.mkForce true;

  services.xserver.resolutions = [
    {
      "x" = 1920;
      "y" = 1080;
    }
  ];

  networking = {
    hostName = "johnos"; # Put your hostname here.
    useDHCP = false;
    interfaces.wlo1.useDHCP = true;
    wireless = {
      interfaces = [
        "wlo1"
      ];
      enable = true;
      networks = {
        EpsteinDidntKillHimself5G = {
          pskRaw = "1ccdb453d26a04c707084d33728e26a34c78f8712f878366b4ad129800dff828";
        };
      };
    };
  };
}
