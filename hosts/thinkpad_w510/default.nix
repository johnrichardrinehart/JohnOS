{ lib, ... }: {
  dev.johnrinehart.boot.loader.grub.enable = true;

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
}
