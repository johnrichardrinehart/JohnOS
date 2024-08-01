{ lib, pkgs, config, ... }: {
  dev.johnrinehart = {
    boot.loader.grub.enable = true;
    s3_mount = {
      enable = true;
      mounts = [{
        bucketName = "rinehartstorage";
        url = "https://s3.us-west-000.backblazeb2.com";
        passwordFile = config.sops.secrets.backblaze-passwd-s3fs-rinehartstorage.path;
      }];
    };
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
      options = [ "fmask=0022" "dmask=0022" ];
    };
  };

  boot.initrd.luks.devices."dm-0".device = lib.mkForce "/dev/disk/by-uuid/002adea0-5c10-45a8-bc8a-701a0d71577b";

  networking.interfaces.wlp3s0.useDHCP = true;

  services.upower.enable = true;

  environment.systemPackages = [
    pkgs.opensc
    pkgs.pcsc-tools
    pkgs.global-platform-pro
    config.boot.kernelPackages.v4l2loopback.bin
  ];

  services.pcscd.enable = true;

  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback.out ];
  boot.kernelModules = [ "v4l2loopback" ];

  sops.defaultSopsFile = ../../secrets/sops.yaml;
  #sops.age.keyFile = "/home/john/.config/sops/age/keys.txt";
  sops.age.sshKeyPaths = [ "/home/john/.ssh/sops" ];
  sops.secrets.backblaze-passwd-s3fs-rinehartstorage = {};
}
