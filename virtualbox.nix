args @ { config, pkgs, ... }:
{
  virtualisation.virtualbox.guest.enable = true;
  # Use the GRUB 2 boot loader.
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only
  boot.loader.grub.enable = true;
}
