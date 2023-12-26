args @ { config, pkgs, ... }:
{
  hardware.pulseaudio.enable = true;
  networking.interfaces.enp0s3.useDHCP = true;
  # Use the GRUB 2 boot loader.
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only
  boot.loader.grub.enable = true;


  boot.initrd.availableKernelModules = [ "ata_piix" "ohci_pci" "ehci_pci" "ahci" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/de882833-71bf-4f06-ba2c-87e0e5339443";
      fsType = "ext4";
    };

  swapDevices =
    [{ device = "/dev/disk/by-uuid/e80203f0-b163-42b5-9b9a-86c251d65948"; }];

  virtualisation.virtualbox.guest.enable = true;
}
