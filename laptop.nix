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

  fileSystems = pkgs.lib.mkForce (config.lib.isoFileSystems //
    {
      "/mnt/root" =
        {
          device = "/dev/mmcblk0p1";
          fsType = "ext4";
        };
      "/etc" =
        {
          fsType = "overlay";
          device = "overlay";
          options = [
            "lowerdir=/etc"
            "upperdir=/mnt/root/etc/upper"
            "workdir=/mnt/root/etc/.work"
          ];
          depends = [
            "/mnt/root"
          ];
        };
      "/home" =
        {
          fsType = "overlay";
          device = "overlay";
          options = [
            "lowerdir=/home"
            "upperdir=/mnt/root/home/upper"
            "workdir=/mnt/root/home/.work"
          ];
          depends = [
            "/mnt/root"
          ];
        };
    });

  # disabled by installation-cd-minimal
  fonts.fontconfig.enable = pkgs.lib.mkForce true;

  # use xinput to discover the name of the laptop keyboard (not lsusb)
  services.xserver = {
    enable = true;

    videoDrivers = [ "modesetting" "nvidia" ];

    config = pkgs.lib.mkForce ''
      Section "ServerLayout"
          Identifier "The View"
          Screen 0 "Laptop Screen"
          #Screen 1 "Dell Screen" Above "Dell Screen"
          Option "DefaultServerLayout" "on"
      EndSection

      #Section "Screen"
      #    Identifier "Dell Screen"
      #    Device "GTX1050TI"
      #    Monitor "Dell U2520D"
      #    SubSection "Display"
      #      Depth 8
      #      Modes "1920x1080"
      #    EndSubSection
      #    SubSection "Display"
      #      Depth 16
      #      Modes "1920x1080"
      #    EndSubSection
      #    SubSection "Display"
      #      depth 24
      #      modes "1920x1080"
      #    EndSubSection
      #EndSection

      Section "Screen"
          Identifier "Laptop Screen"
          Device "Intel Graphics"
          Monitor "Laptop Monitor"
          SubSection "Display"
            Depth 8
            Modes "1920x1080"
          EndSubSection
          SubSection "Display"
            Depth 16
            Modes "1920x1080"
          EndSubSection
          SubSection "Display"
            depth 24
            modes "1920x1080"
          EndSubSection
      EndSection

      #Section "Device"
      #    # Addresses graphics cards
      #    Identifier "GTX1050TI"
      #    Option "Monitor-DP-2" "Dell U2520D"
      #    Driver "nvidia"
      #    BusID "PCI:1:0:0"
      #    Option "ModeDebug" "on"
      #EndSection

      Section "Device"
        Identifier "Intel Graphics"
        Option "Monitor-eDP-1" "Laptop Monitor"
        Driver "modesetting"
        BusID "PCI:0:2:0"
        #Option "AccelMethod" "SNA" # options are UXA|SNA|BLT|NONE
        Option "ModeDebug" "on"
      EndSection


      #Section "Monitor"
      #    # Addresses physical display device
      #    Identifier "Dell U2520D"
      #EndSection

      Section "Monitor"
          Identifier "Laptop Monitor"
       #   Option "Below" "DP-2"
      EndSection


      Section "InputClass"
        Identifier "Laptop Keyboard"
        #MatchProduct "AT Translated Set 2 keyboard"
        Option "XkbVariant" "dvorak"
        MatchIsKeyboard "on"
      EndSection

      Section "InputClass"
        Identifier "John's Moonlander"
        MatchUSBID "3297:1969"
        Option "XkbLayout" "us"
      EndSection

      # Automatically enable the synaptics driver for all touchpads.
      Section "InputClass"
        Identifier "synaptics touchpad catchall"
        MatchIsTouchpad "on"
        Driver "synaptics"
        Option "MinSpeed" "0.6"
        Option "MaxSpeed" "1.0"
        Option "AccelFactor" "0.001"
        Option "MaxTapTime" "180"
        Option "MaxTapMove" "220"
        Option "TapButton1" "1"
        Option "TapButton2" "2"
        Option "TapButton3" "3"
        Option "ClickFinger1" "1"
        Option "ClickFinger2" "2"
        Option "ClickFinger3" "3"
        Option "VertTwoFingerScroll" "1"
        Option "HorizTwoFingerScroll" "1"
        Option "VertEdgeScroll" "0"
        Option "HorizEdgeScroll" "0"
      EndSection
    '';
    #    exportConfiguration = true;
    #
    #    inputClassSections = [
    #      ''
    #        Section "InputClass"
    #        Identifier "Laptop Keyboard"
    #        MatchProduct "AT Translated Set 2"
    #        Option "XkbLayout" "dvorak"
    #        EndSection
    #      ''
    #      ''
    #        Section "InputClass"
    #        Identifier "John's Moonlander"
    #        MatchUSBID "3297:1969"
    #        Option "XkbLayout" "us"
    #        EndSection
    #      ''
    #      #      ''
    #      #          Identifier "synaptics touchpad catchall"
    #      #          MatchIsTouchpad "on"
    #      #          Driver "synaptics"
    #      #          Option "MinSpeed" "0.6"
    #      #          Option "MaxSpeed" "1.0"
    #      #          Option "AccelFactor" "0.001"
    #      #          Option "MaxTapTime" "180"
    #      #          Option "MaxTapMove" "220"
    #      #          Option "TapButton1" "1"
    #      #          Option "TapButton2" "2"
    #      #          Option "TapButton3" "3"
    #      #          Option "ClickFinger1" "1"
    #      #          Option "ClickFinger2" "2"
    #      #          Option "ClickFinger3" "3"
    #      #          Option "VertTwoFingerScroll" "1"
    #      #          Option "HorizTwoFingerScroll" "1"
    #      #          Option "VertEdgeScroll" "0"
    #      #          Option "HorizEdgeScroll" "0"
    #      #      ''
    #    ];
    #
    #    verbose = 7; # 0-7 (7 most verbose)
    #
    #    deviceSection = ''
    #      Identifier "GTX1050TI"
    #      Option "Monitor-DP-2" "Dell U2520D"
    #      Driver "nvidia"
    #      BusID "PCI:1:0:0"
    #      Option "ModeDebug" "on"
    #    '';
    #
    #    screenSection = ''
    #      Identifier "Dell Screen"
    #      Device "GTX1050TI"
    #      Monitor "Dell U2520D"
    #    '';
    #
    #    monitorSection = ''
    #      Option "Identifier" "Dell U2520D"
    #    '';
    #
    #    extraConfig = ''
    #      Section "Device"
    #           Identifier "Intel Graphics"
    #           Option "Monitor-eDP-1" "Laptop Monitor"
    #           Driver "modesetting"
    #           BusID "PCI:0:2:0"
    #           Option "AccelMethod" "SNA" # options are UXA|SNA|BLT|NONE
    #           Option "ModeDebug" "on"
    #      EndSection
    #
    #      Section "Screen"
    #          Identifier "Laptop Screen"
    #          Device "Intel Graphics"
    #          Monitor "Laptop Monitor"
    #      EndSection
    #
    #      Section "Monitor"
    #          Option "Identifier" "Laptop Monitor"
    #      #   Option "Below" "DP-2"
    #      EndSection
    #    '';
    #
    #    serverLayoutSection = ''
    #      Identifier "The View"
    #      Screen 0 "Dell Screen"
    #      Screen 1 "Laptop Screen" Below "Dell Screen"
    #      #     Option "DefaultServerLayout" "on"
    #    '';
    #
    #      videoDrivers = [ "nvidia" ];
    #
    #    synaptics = {
    #      enable = true;
    #      twoFingerScroll = true;
    #    };
    #
    #    #resolutions = [
    #    #  {
    #    #    "x" = 1920;
    #    #    "y" = 1080;
    #    #  }
    #    #];

    enableCtrlAltBackspace = true;

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
        Kyivstar4G_30 = {
          pskRaw = "42be31bf6a525112a3474c42777c141837669cbb24fc6ff8151f6a88a3944298";
        };
      };
    };
  };

  ################################################################################
  ########## NVIDIA offload
  ################################################################################
  #  services.xserver.videoDrivers = [ "modesetting" "nouveau" "nvidia" ];
  #  services.xserver.videoDrivers = [ "modesetting" "nvidia" ];
  #  hardware.nvidia.prime = {
  #    offload.enable = true;
  #
  #    # Bus ID of the Intel GPU. You can find it using lspci, either under 3D or VGA
  #    intelBusId = "PCI:0:2:0";
  #
  #    # Bus ID of the NVIDIA GPU. You can find it using lspci, either under 3D or VGA
  #    nvidiaBusId = "PCI:1:0:0";
  #  };
  hardware.opengl.enable = true;
  hardware.opengl.driSupport = true;
  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.vulkan_beta;
  hardware.nvidia.nvidiaPersistenced = true;

  ################################################################################
  ########## NVIDIA sync
  ################################################################################
  hardware.nvidia =
    {
      modesetting.enable = true;

      prime = {
        sync.enable = true;

        # Bus ID of the Intel GPU. You can find it using lspci, either under 3D or VGA
        intelBusId = "PCI:0:2:0";

        # Bus ID of the NVIDIA GPU. You can find it using lspci, either under 3D or VGA
        nvidiaBusId = "PCI:1:0:0";
      };
    };

  ################################################################################
  ########## bumblebee
  ################################################################################
  #  hardware.bumblebee.enable = true;


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
