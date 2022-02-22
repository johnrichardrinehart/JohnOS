args @ { config, lib, pkgs, modulesPath, ... }:
{

  imports =
    [
      (modulesPath + "/profiles/qemu-guest.nix")
    ];

  boot = {
    initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" ];
    initrd.kernelModules = [ ];
    kernelModules = [ ];
    extraModulePackages = [ ];
    loader.grub = {
      enable = true;
      version = 2;
      # Define on which hard drive you want to install Grub.
      device = "/dev/vda"; # or "nodev" for efi only
    };
    kernelPackages = pkgs.recurseIntoAttrs (pkgs.linuxPackagesFor pkgs.linuxKernel.kernels.linux_5_16);
  };


  fileSystems."/" =
    {
      device = "/dev/vda1";
      fsType = "ext4";
    };

  fileSystems."/nix" =
    {
      device = "/dev/disk/by-label/nix_store";
      fsType = "ext4";
    };

  fileSystems."/tmp" =
    {
      device = "/dev/disk/by-label/tmp";
      fsType = "ext4";
    };

  swapDevices =
    [{ device = "/dev/vda2"; }];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Set your time zone.
  time.timeZone = "Europe/Kiev";

  console.useXkbConfig = true;

  programs.zsh.enable = true;

  environment.systemPackages = [
    pkgs.tmux
    pkgs.vim
    pkgs.git
    pkgs.nixpkgs-fmt
  ];

  virtualisation.docker.enable = true;

  services.sshd.enable = true;

  networking = {
    useDHCP = pkgs.lib.mkForce true;
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
    firewall.allowedTCPPorts = [ ];
  };

  nixpkgs.config = {
    allowUnsupportedSystem = true;
    config.allowUnfree = true;
  };

  system.stateVersion = "21.05"; # Did you read the comment?
}
