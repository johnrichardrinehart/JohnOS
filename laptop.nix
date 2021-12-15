args @ { config, pkgs, ... }:
{
  # uncomment `imports` if you want to bundle nixpkgs into the installation
  #  imports = [
  #    "${args.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
  #  ];

  # https://nixos.wiki/wiki/Linux_kernel#Booting_a_kernel_from_a_custom_source

  # TODO: remove allowUnbroken once ZFS in linux kernel is fixed
  nixpkgs.config.allowBroken = true;
  boot.kernelPackages = pkgs.lib.mkForce (
    let
      latest_stable_pkg = { fetchurl, buildLinux, ... } @ args:
        buildLinux (args // rec {
          version = "5.15.8";
          modDirVersion = version;

          kernelPatches = [
            {
              name = "hp-spectre-x360-audio";
              patch = ./laptop_audio.patch;
            }
          ];

          src = fetchurl {
            url = "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${version}.tar.xz";
            sha256 = "Mv3NM8isVxuaeil/M4YPYXEyeWHyoupr1Uv4InW2FMg=";
          };

        } // (args.argsOverride or { }));
      latest_stable = pkgs.callPackage latest_stable_pkg { };
    in
    pkgs.recurseIntoAttrs (pkgs.linuxPackagesFor latest_stable)
  );

  hardware = {
    bluetooth.enable = true;
  };


  # add some filesystems for helping maintain state between reboots
  fileSystems = pkgs.lib.mkForce (config.lib.isoFileSystems //
    {
      "/mnt/root" =
        {
          device = "/dev/mmcblk0p1";
          fsType = "ext4";
          neededForBoot = false;
        };
      "/etc" =
        {
          fsType = "overlay";
          device = "overlay";
          options = [
            "lowerdir=/etc"
            "upperdir=/mnt/root/etc_upper"
            "workdir=/mnt/root/etc/.etc_work"
          ];
          depends = [
            "/mnt/root"
          ];
          neededForBoot = false;
        };
      "/home" =
        {
          fsType = "overlay";
          device = "overlay";
          options = [
            "lowerdir=/home"
            "upperdir=/mnt/root/home_upper"
            "workdir=/mnt/root/.home_work"
          ];
          depends = [
            "/mnt/root"
          ];
          neededForBoot = false;
        };
    });

  # disabled by installation-cd-minimal
  fonts.fontconfig.enable = pkgs.lib.mkForce true;

  # use xinput to discover the name of the laptop keyboard (not lsusb)
  services.xserver = {
    enable = true;

    videoDrivers = [ "modesetting" "nouveau" ];

    # manual implementation of https://github.com/NixOS/nixpkgs/blob/6c0c30146347188ce908838fd2b50c1b7db47c0c/nixos/modules/services/x11/xserver.nix#L737-L741
    # can not use xserver.config.enableCtrlAltBackspace because we want a mostly-empty xorg.conf
    config = pkgs.lib.mkForce ''
      Section "ServerFlags"
         Option "DontZap" "off"
      EndSection

      Section "Screen"
         Identifier "Placeholder-NotImportant"
         SubSection "Display"
           Depth 24
           Modes "1920x1080" "2560x1440"
         EndSubSection
      EndSection
    '';

    libinput.enable = true;
  };

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
  #  services.xserver.videoDrivers = [ "modesetting" "nvidia" ];
  #  hardware.nvidia.prime = {
  #    offload.enable = true;
  #    hardware.nvidia.nvidiaPersistenced = true;
  #
  #    # Bus ID of the Intel GPU. You can find it using lspci, either under 3D or VGA
  #    intelBusId = "PCI:0:2:0";
  #
  #    # Bus ID of the NVIDIA GPU. You can find it using lspci, either under 3D or VGA
  #    nvidiaBusId = "PCI:1:0:0";
  #  };

  #hardware.nvidia.package = pkgs.linuxKernel.packages.linux_zen.nvidia_x11_beta;
  #hardware.nvidia.package = config.boot.kernelPackages.nvidia_x11_beta;

  ################################################################################
  ########## NVIDIA sync
  ################################################################################
  #hardware.nvidia =
  #  {
  #    modesetting.enable = true;
  #    nvidiaPersistenced = true;

  #    prime = {
  #      sync.enable = true;

  #      # Bus ID of the Intel GPU. You can find it using lspci, either under 3D or VGA
  #      intelBusId = "PCI:0:2:0";

  #      # Bus ID of the NVIDIA GPU. You can find it using lspci, either under 3D or VGA
  #      nvidiaBusId = "PCI:1:0:0";
  #    };
  #  };

  ################################################################################
  ########## bumblebee
  ################################################################################
  #  hardware.bumblebee.enable = true;

  environment.systemPackages = [
    pkgs.blueberry
    pkgs.hicolor-icon-theme
  ];

  #boot.blacklistedKernelModules = [ "nvidia" "modesetting"];
  #    nixpkgs.overlays = [ ( self: super: { sof-firmware = unstable.sof-firmware; } ) ];
  #    hardware.pulseaudio.package = unstable.pulseaudioFull;

  ################################################################################
  ########## Brightness Settings
  ################################################################################
  # TODO: backed up from branch main before pulling branch flake into main. Uncomment if helpful
  #           services.acpid.handlers = {
  #                 dim = {
  #                         event = "video/brightnessdown";
  #                         action = ''
  # DISPLAY=:0 \
  # XAUTHORITY=/home/john/.Xauthority \
  # ${pkgs.bash}/bin/sh -c "${pkgs.xorg.xrandr}/bin/xrandr --output eDP-1 --brightness 0.2" john
  #                                 '';
  # 
  #                 };
  #                 brighten = {
  #                         event = "video/brightnessup";
  #                         action = ''
  # DISPLAY=:0 \
  # XAUTHORITY=/home/john/.Xauthority \
  # ${pkgs.bash}/bin/sh -c "${pkgs.xorg.xrandr}/bin/xrandr --output eDP-1 --brightness 0.8" john
  #                                 '';
  #                 };
  #         };
  #         services.acpid.enable = true;
  #         services.acpid.logEvents = true;


  ################################################################################
  ########## Sound Settings
  ################################################################################
  sound.enable = true;
  hardware.pulseaudio = {
    enable = true;
    support32Bit = true;
    extraModules = [ pkgs.pulseaudio-modules-bt ];
    package = pkgs.pulseaudioFull;
    extraConfig = "load-module module-switch-on-connect";
  };

  # Note: c.f. https://discourse.nixos.org/t/no-sound-on-hp-spectre-14t-20-09/12613/3
  # and https://discourse.nixos.org/t/sound-not-working/12585/11 
  boot.extraModprobeConfig = ''
    options snd-hda-intel model=alc295-hp-x360
    options snd-intel-dspcfg dsp_driver=1
  '';
}
