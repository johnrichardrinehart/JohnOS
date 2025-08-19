args@{
  config,
  pkgs,
  lib,
  ...
}:
{
  nixpkgs.hostPlatform = "x86_64-linux";
  
  # Boot configuration
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };
  
  # Root filesystem
  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };
  
  # TODO: remove allowUnbroken once ZFS in linux kernel is fixed
  nixpkgs.config.allowBroken = true;
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "broadcom-sta-6.30.223.271-57-5.16.10"
  ];

  # https://nixos.wiki/wiki/Linux_kernel#Booting_a_kernel_from_a_custom_source
  boot.kernelPackages = pkgs.lib.mkForce (
    let
      latest_stable_pkg =
        { fetchurl, buildLinux, ... }@args:
        buildLinux (
          args
          // rec {
            version = "5.16.10";
            modDirVersion = "5.16.10";

            kernelPatches = [ ];

            src = fetchurl {
              url = "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${version}.tar.xz";
              sha256 = "sha256-DE1vAIGABZOFLrFVsB4Jt4tbxp16VT/Fj1rSBw+QI54=";
            };

          }
          // (args.argsOverride or { })
        );
      latest_stable = pkgs.callPackage latest_stable_pkg { };
    in
    pkgs.recurseIntoAttrs (pkgs.linuxPackagesFor latest_stable)
  );

  # disabled by installation-cd-minimal
  fonts.fontconfig.enable = pkgs.lib.mkOverride 49 true; # higher priority than installation-cd-minimal.nix

  # use xinput to discover the name of the laptop keyboard (not lsusb)
  services.xserver = {
    enable = true;
  };

  programs.nm-applet.enable = true;

  networking = {
    hostName = "sergeyos"; # Put your hostname here.
    networkmanager = {
      enable = true;
    };

    wireless = {
      enable = false;
      userControlled.enable = true;
    };
  };

  environment.systemPackages = [ pkgs.hicolor-icon-theme ];

  # rtkit is optional but recommended
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

  dev.johnrinehart.droidcam.enable = true;

  boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];

  # below from https://github.com/NixOS/nixos-hardware/blob/master/apple/default.nix
  boot.kernelParams = [ "hid_apple.iso_layout=0" ];

  hardware.facetimehd.enable = lib.mkDefault (config.nixpkgs.config.allowUnfree or false);

  services.mbpfan.enable = lib.mkDefault true;

  # below from https://github.com/NixOS/nixos-hardware/tree/master/common/cpu/intel
  boot.initrd.kernelModules = [
    "i915"
    "wl"
  ];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  hardware.opengl.extraPackages = with pkgs; [
    vaapiIntel
    vaapiVdpau
    libvdpau-va-gl
    intel-media-driver
  ];

  #   # below from https://github.com/NixOS/nixos-hardware/blob/master/common/pc/default.nix
  #   boot.blacklistedKernelModules = lib.optionals (!config.hardware.enableRedistributableFirmware) [
  #     "ath3k"
  #   ];

  dev.johnrinehart.laptop.enable = true;

  # below from https://github.com/NixOS/nixos-hardware/blob/master/apple/macbook-pro/11-5/default.nix
  # Apparently this is currently only supported by ati_unfree drivers, not ati
  # hardware.opengl.driSupport32Bit = false;

  services.xserver.videoDrivers = [
    "modesetting"
    "nouveau"
    "ati"
  ];

  services.udev.extraRules =
    # Disable XHC1 wakeup signal to avoid resume getting triggered some time
    # after suspend. Reboot required for this to take effect.
    lib.optionalString (lib.versionAtLeast config.boot.kernelPackages.kernel.version "3.13")
      ''SUBSYSTEM=="pci", KERNEL=="0000:00:14.0", ATTR{power/wakeup}="disabled"'';

  # imports = [ "${nixpkgs}/nixos/modules/hardware/network/broadcom-43xx.nix" ]; # TODO: Fix nixpkgs reference

  # below from https://github.com/NixOS/nixos-hardware/blob/master/common/pc/ssd/default.nix
  boot.kernel.sysctl = {
    "vm.swappiness" = lib.mkDefault 1;
  };

  services.fstrim.enable = lib.mkDefault true;

  # from https://github.com/rasendubi/nixpkgs/commit/d135ae91b56872dc53fe34528b46a29b0da486a9
  # boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ]; # added above
  # boot.kernelModules = [ "wl" ]; # added above

}
