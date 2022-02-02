args @ { config, pkgs, ... }:
let
  # https://discourse.nixos.org/t/load-automatically-kernel-module-and-deal-with-parameters/9200
  v4l2loopback-dc = config.boot.kernelPackages.callPackage ./v4l2loopback-dc.nix { };
in
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
          version = "5.16.5";
          modDirVersion = "5.16.5";

          kernelPatches = [
            {
              name = "hp-spectre-x360-audio";
              patch = ./hp_spectre_x360_audio.patch;
            }
            # an issues with display sleeping cropped up in 5.16.4
            # https://gitlab.freedesktop.org/drm/nouveau/-/issues/149
            {
              name = "fix-nouveau-driver-on-display-sleep-revert-9b98913f3d035f639eda2e213e308fd5567c00d2";
              patch = ./0001-Revert-drm-nouveau-pmu-gm200-avoid-touching-PMU-outs.patch;
            }
          ];

          # buildFlags = [ "KBUILD_BUILD_VERSION=JohnOS" ];
          #++ (args.nixpkgs.lib.drop 2 args.buildFlags);

          src = fetchurl {
            url = "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${version}.tar.xz";
            sha256 = "7K7t2dKJk0+XxXKqlltpWdTUf5eJIg5Pw/u1Jdjxx6s=";
          };

        } // (args.argsOverride or { }));
      latest_stable = pkgs.callPackage latest_stable_pkg { };
    in
    pkgs.recurseIntoAttrs
      (pkgs.linuxPackagesFor latest_stable)
  );

  # add some filesystems for helping maintain state between reboots
  fileSystems = pkgs.lib.mkForce
    (config.lib.isoFileSystems //
      {
        "/mnt/root" =
          {
            device = "/dev/mmcblk0p1";
            fsType = "ext4";
            neededForBoot = false;
          };
        "/var/lib/docker" =
          {
            fsType = "ext4";
            device = "/mnt/root/var-lib-docker";
            options = [
              "defaults,bind"
              "x-systemd.requires=/mnt/root"
            ];
          };
        "/var/lib/bluetooth" =
          {
            fsType = "overlay";
            device = "overlay";
            options = [
              "lowerdir=/var/lib/bluetooth"
              "upperdir=/mnt/root/var-lib-bluetooth"
              "workdir=/mnt/root/.var-lib-bluetooth"
              "x-systemd.requires=/mnt/root"
              "x-systemd.requires=/var/lib/bluetooth"
              "nofail"
            ];
            neededForBoot = false;
          };
        "/home" =
          {
            fsType = "overlay";
            device = "overlay";
            options = [
              "lowerdir=/home"
              "upperdir=/mnt/root/home"
              "workdir=/mnt/root/.home"
              "x-systemd.requires=/mnt/root"
              "x-systemd.requires=/home"
              "nofail"
            ];
            neededForBoot = false;
          };
      });

  # disabled by installation-cd-minimal
  fonts.fontconfig.enable = pkgs.lib.mkForce
    true;

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

    wireless.enable = pkgs.lib.mkForce false; # use networking.networkmanager
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

  # sound.enable = true;
  # hardware.pulseaudio = {
  #   enable = true;
  #   support32Bit = true;
  #   extraModules = [ pkgs.pulseaudio-modules-bt ];
  #   package = pkgs.pulseaudioFull;
  # };

  # rtkit is optional but recommended
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # bluetooth stuff
  services.blueman.enable = true;
  hardware = {
    bluetooth.enable = true;
  };

  ## Below v4l2loopback stuff stolen from https://gist.github.com/TheSirC/93130f70cc280cdcdff89faf8d4e98ab
  # Extra kernel modules
  boot.extraModulePackages = [
    #config.boot.kernelPackages.v4l2loopback
    v4l2loopback-dc
  ];

  # Register a v4l2loopback device at boot
  boot.kernelModules = [
    #"v4l2loopback"
    "v4l2loopback-dc"
  ];
}
