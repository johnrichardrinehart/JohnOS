args @ { config, pkgs, ... }:
{
  # uncomment `imports` if you want to bundle nixpkgs into the installation
  #  imports = [
  #    "${args.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
  #  ];

  # https://nixos.wiki/wiki/Linux_kernel#Booting_a_kernel_from_a_custom_source
  boot.kernelPackages = pkgs.lib.mkForce (let
      latest_stable_pkg = { fetchurl, buildLinux, ... } @ args:
        buildLinux (args // rec {
          version = "5.14.15";
          modDirVersion = version;

          kernelPatches = [];

          src = fetchurl {
            url = "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.14.15.tar.xz";
            sha256 = "dPOaDGnp18lNKQUVZFOWcl4842Z7hbr0s8P28wPHpAY=";
          };

        } // (args.argsOverride or { }));
      latest_stable = pkgs.callPackage latest_stable_pkg { };
    in
      pkgs.recurseIntoAttrs (pkgs.linuxPackagesFor latest_stable));

  hardware = {
    bluetooth.enable = true;
    pulseaudio = {
      enable = true;
      package = pkgs.pulseaudioFull;
    };
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
    '';

    libinput.enable = true;
  };

  # services.xserver.layout = pkgs.lib.mkForce "dvorak"; # set in /configuration.nix

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


  # Note: c.f. https://discourse.nixos.org/t/no-sound-on-hp-spectre-14t-20-09/12613/3
  # and https://discourse.nixos.org/t/sound-not-working/12585/11 
  boot.extraModprobeConfig = ''
    options snd-intel-dspcfg dsp_driver=1
  '';

  #boot.blacklistedKernelModules = [ "nvidia" "modesetting"];
  #    nixpkgs.overlays = [ ( self: super: { sof-firmware = unstable.sof-firmware; } ) ];
  #    hardware.pulseaudio.package = unstable.pulseaudioFull;
}
