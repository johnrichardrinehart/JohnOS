{
  config,
  lib,
  pkgs,
  ...
}:
{
  nixpkgs.hostPlatform = "aarch64-linux";
  networking.hostName = "rock5c-minimal";
  dev.johnrinehart.rock5c.enable = true;
  dev.johnrinehart.rock5c.useMinimalKernel = true;
  dev.johnrinehart.system.enable = true;
  dev.johnrinehart.nix.enable = true;

  boot.consoleLogLevel = 7;

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
  };

  services.deluge = {
    web = {
      enable = true;
      openFirewall = true;
    };
    enable = true;
    openFilesLimit = 1048576; # 1<<20 = 2^20 = 1048576
  };

  services.jellyfin = {
    openFirewall = true;
    enable = true;
  };

  hardware.firmware = [ (pkgs.callPackage ./mali_csffw.nix { }) ];
  users.groups.video.members = [ config.services.jellyfin.user ];

  services.udev.extraRules = ''
    KERNEL=="mpp_service", MODE="0660", GROUP="video"
    KERNEL=="rga", MODE="0660", GROUP="video"
    KERNEL=="system", MODE="0666", GROUP="video"
    KERNEL=="system-dma32", MODE="0666", GROUP="video"
    KERNEL=="system-uncached", MODE="0666", GROUP="video"
    KERNEL=="system-uncached-dma32", MODE="0666", GROUP="video" RUN+="${pkgs.toybox}/bin/chmod a+rw /dev/dma_heap"
  '';

  environment.systemPackages = [
    pkgs.vim
    pkgs.git
    pkgs.tmux
  ];

  boot.kernelModules = [ "dm_cache" ];

  fileSystems."nas" = {
    mountPoint = "/mnt/nas";
    neededForBoot = false;
    fsType = "btrfs";
    device = "/dev/mapper/nas-storage";
    options = [
      "nofail"
      "x-systemd.device-timeout=10s"
    ]; # takes about 5s, usually
  };

  boot.kernelPatches = [
    {
      name = "btrfs";
      patch = null;
      structuredExtraConfig = {
        BTRFS_FS = lib.kernel.yes;
        BTRFS_DEBUG = lib.kernel.yes;
      };
    }
  ];

  boot.supportedFilesystems = {
    "btrfs" = true;
  };

  networking.networkmanager.enable = true;
}
