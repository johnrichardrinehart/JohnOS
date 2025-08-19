{
  lib,
  pkgs,
  config,
  ...
}:
{
  nixpkgs.hostPlatform = "x86_64-linux";

  # Boot configuration
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };
  
  # Root filesystem already defined below, removing duplicate

  dev.johnrinehart = {
    # Temporarily disable complex s3/gocryptfs setup for building
    # s3_mount.enable = false;
    # gocryptfs.enable = false;
    desktop.enable = true;
  };

  networking.hostName = "thinkie";

  # really noisy webcam
  programs.noisetorch.enable = true;

  fileSystems = {
    "/" = lib.mkForce {
      device = "UUID=4f338d98-cf03-4853-a2b8-2452e5494bb3";
      fsType = "bcachefs";
    };

    "/boot" = lib.mkForce {
      device = "/dev/disk/by-uuid/84EE-E35C";
      fsType = "vfat";
      options = [
        "fmask=0022"
        "dmask=0022"
      ];
    };
  };

  boot.initrd.luks.devices."dm-0".device =
    lib.mkForce "/dev/disk/by-uuid/002adea0-5c10-45a8-bc8a-701a0d71577b";

  networking.interfaces.wlp3s0.useDHCP = true;

  services.upower.enable = true;

  environment.systemPackages = [
    pkgs.opensc
    pkgs.pcsc-tools
    pkgs.global-platform-pro
    config.boot.kernelPackages.v4l2loopback.bin
  ]
  ++ [ pkgs.nload ];

  services.pcscd.enable = true;

  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback.out ];
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModprobeConfig = "options usb-storage quirks=152d:0562:u";

  # SOPS configuration temporarily disabled for building
  # sops.defaultSopsFile = ../../secrets/sops.yaml;
  # sops.age.sshKeyPaths = [ "/home/john/.ssh/sops" ];
  # sops.secrets.backblaze-passwd-s3fs-rinehartstorage = { };
  # sops.secrets.backblaze-passwd-gocryptfs-rinehartstorage = { };
}
