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
    kernelPackages = pkgs.lib.mkForce (
      let
        latest_stable_pkg = { fetchurl, buildLinux, ... } @ args:
          buildLinux (args // rec {
            version = "5.16.10";
            modDirVersion = "5.16.10";

            kernelPatches = [ ];

            src = fetchurl {
              url = "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${version}.tar.xz";
              sha256 = "sha256-DE1vAIGABZOFLrFVsB4Jt4tbxp16VT/Fj1rSBw+QI54=";
            };

          } // (args.argsOverride or { }));
        latest_stable = pkgs.callPackage latest_stable_pkg { };
      in
      pkgs.recurseIntoAttrs
        (pkgs.linuxPackagesFor latest_stable)
    );
  };


  fileSystems."/" =
    {
      device = "/dev/vda1";
      fsType = "ext4";
    };

  fileSystems."/nix" =
    {
      device = "/dev/vdb1";
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
  ];

  virtualisation.docker.enable = true;

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
