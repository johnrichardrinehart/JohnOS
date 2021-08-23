args @ { config, pkgs, ... }:
{
  ################################################################################
  ########## Include the below if you want to bundle nixpkgs into the installation
  ################################################################################
  #  imports = [
  #    "${args.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
  #  ];

  hardware = {
    bluetooth.enable = true;
    pulseaudio = {
      enable = true;
      package = pkgs.pulseaudioFull;
    };
  };

  fileSystems."/mnt/home" =
    {
      device = "/dev/mmcblk0p1";
      fsType = "exfat";
    };

  # disabled by installation-cd-minimal
  fonts.fontconfig.enable = pkgs.lib.mkForce true;

  # use xinput to discover the name of the laptop keyboard (not lsusb)
  services.xserver = {
    config = pkgs.lib.mkAfter ''
      Section "InputClass"
      Identifier "Laptop Keyboard"
      MatchProduct "AT Translated Set 2"
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

  environment.systemPackages = let p = pkgs; in
    [
      p.pavucontrol
    ];

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


  # Note: c.f. https://discourse.nixos.org/t/no-sound-on-hp-spectre-14t-20-09/12613/3
  # and https://discourse.nixos.org/t/sound-not-working/12585/11 
  boot.extraModprobeConfig = ''
    options snd-intel-dspcfg dsp_driver=1
  '';
  #    nixpkgs.overlays = [ ( self: super: { sof-firmware = unstable.sof-firmware; } ) ];
  #    hardware.pulseaudio.package = unstable.pulseaudioFull;

  #  root = pkgs.lib.mkForce {
  #    initialHashedPassword = "$6$u1EpA1iJ$5ib2.fR/wT6MJdDrgmZsk4yd.7MINoiE3vzYE0wR1kEvL3GH6cJ9sL/muVyArKx9LhCNrJpauWKLdk4RmKz0V0";
  #  };
}
