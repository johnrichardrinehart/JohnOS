# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, options, modulesPath, ... }:
let
  # https://discourse.nixos.org/t/load-automatically-kernel-module-and-deal-with-parameters/9200
  v4l2loopback-dc = config.boot.kernelPackages.callPackage ../../pkgs/v4l2loopback-dc.nix { };
in
{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.supportedFilesystems = [ "ntfs" "exfat" "vfat" "btrfs" "ext" ];
  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "uas" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];

  boot.resumeDevice = "/dev/disk/by-uuid/960b1823-195e-4044-8c86-8407b1f25d92";

  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/9dbd56c9-2344-450a-845b-6490d0879256";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/32F9-A71A";
      fsType = "vfat";
    };

  fileSystems."/mnt/framework250_1" =
    {
      device = "/dev/disk/by-uuid/caca60c2-483b-4a58-a443-5c8df3b3c82d";
      fsType = "btrfs";
      options = ["user" "rw" "async" "auto" "nofail"];
    };

  swapDevices =
    [{ device = "/dev/disk/by-uuid/960b1823-195e-4044-8c86-8407b1f25d92"; }];

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.hostName = "framie";
  networking.useDHCP = lib.mkDefault false;
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" "6.6.6.6" ];
  networking.resolvconf.enable = true;
  networking.interfaces.wlp170s0.useDHCP = lib.mkDefault true;

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  # high-resolution display

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;

    alsa.enable = false; # https://github.com/NixOS/nixpkgs/issues/157442
    alsa.support32Bit = false; # https://github.com/NixOS/nixpkgs/issues/157442

    pulse.enable = true;

    # If you want to use JACK applications, uncomment this
    jack.enable = true;

    wireplumber.enable = true;
  };

  # bluetooth stuff
  services.blueman.enable = true;
  hardware = {
    bluetooth.enable = true;
  };

  ## Below v4l2loopback stuff stolen from https://gist.github.com/TheSirC/93130f70cc280cdcdff89faf8d4e98ab
  # Extra kernel modules
  boot.extraModulePackages = [
    config.boot.kernelPackages.v4l2loopback
  ];

  environment.etc."modprobe.d/v4l2loopback.conf".text = ''
    options v4l2loopback video_nr=0,1,2 card_label="Virtual Video 0,Virtual Video 1,Virtual Video 2" exclusive_caps=1
  '';
  environment.etc."modules-load.d/v4l2loopback.conf".text = ''
    v4l2loopback
  '';

  # Register a v4l2loopback device at boot
  boot.kernelModules = [
    "v4l2loopback"
    "kvm-intel" # detected automatically
  ];

  sound.enable = true;


  services.chrony.enable = true;

  services.tailscale.enable = true;
  networking.firewall.checkReversePath = "loose";

  networking.timeServers = options.networking.timeServers.default ++ [ "time.facebook.com" ];

  programs.noisetorch.enable = true;

  systemd.services.NetworkManager-wait-online.enable = false;

  services.upower = {
    enable = true;
  };
}
