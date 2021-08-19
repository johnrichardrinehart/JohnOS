args @ { config, pkgs, ... }:
{
################################################################################
########## Include the below if you want to bundle nixpkgs into the installation
################################################################################
#  imports = [
#    "${args.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
#  ];

hardware.bluetooth.enable = true;

  # disabled by installation-cd-minimal
  fonts.fontconfig.enable = pkgs.lib.mkForce true;

  services.xserver = {
    config = pkgs.lib.mkAfter ''
      Section "InputClass"
      Identifier "Laptop Keyboard"
      MatchUSBID "0451:82ff" # maybe QUANTA 0408:5440, actually looks like this is a camera
      Option "XkbLayout" "dvorak"
      EndSection

      Section "InputClass"
      Identifier "John's Moonlander"
      MatchUSBID "3297:1969"
      Option "XkbLayout" "us"
      EndSection
    '';
    synaptics = {
      enable = true;
      twoFingerScroll = true;
    };
    resolutions = [
      {
        "x" = 1920;
        "y" = 1080;
      }
    ];
  };

#  services.xserver.layout = pkgs.lib.mkForce "dvorak"; # set in /configuration.nix

networking = {
  hostName = "johnos"; # Put your hostname here.
  interfaces.wlo1.useDHCP = true;
  wireless = {
    interfaces = [
      "wlo1"
    ];
    enable = true; # disabled by default
    networks = {
      EpsteinDidntKillHimself5G = {
        pskRaw = "1ccdb453d26a04c707084d33728e26a34c78f8712f878366b4ad129800dff828";
      };
    };
  };
};

  #  root = pkgs.lib.mkForce {
  #    initialHashedPassword = "$6$u1EpA1iJ$5ib2.fR/wT6MJdDrgmZsk4yd.7MINoiE3vzYE0wR1kEvL3GH6cJ9sL/muVyArKx9LhCNrJpauWKLdk4RmKz0V0";
  #  };
}
