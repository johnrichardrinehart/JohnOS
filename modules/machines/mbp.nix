args @ { config, pkgs, lib, nixpkgs, ... }:
let
  # https://discourse.nixos.org/t/load-automatically-kernel-module-and-deal-with-parameters/9200
  v4l2loopback-dc = config.boot.kernelPackages.callPackage ./v4l2loopback-dc.nix { };
in
{
  # TODO: remove allowUnbroken once ZFS in linux kernel is fixed
  nixpkgs.config.allowBroken = true;

  # https://nixos.wiki/wiki/Linux_kernel#Booting_a_kernel_from_a_custom_source
  boot.kernelPackages = pkgs.lib.mkForce (
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

  # disabled by installation-cd-minimal
  fonts.fontconfig.enable = pkgs.lib.mkForce true;

  # use xinput to discover the name of the laptop keyboard (not lsusb)
  services.xserver = {
    enable = true;
  };


  programs.nm-applet.enable = true;

  networking = {
    hostName = "cergeyos"; # Put your hostname here.
    networkmanager = {
      enable = true;
    };

    wireless = {
      enable = false;
      userControlled.enable = true;
    };
  };

  environment.systemPackages = [
    pkgs.hicolor-icon-theme
  ];

  # rtkit is optional but recommended
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;

    alsa.enable = false; # https://github.com/NixOS/nixpkgs/issues/157442
    alsa.support32Bit = false; # https://github.com/NixOS/nixpkgs/issues/157442

    pulse.enable = true;

    # If you want to use JACK applications, uncomment this
    jack.enable = true;

    media-session.enable = false;

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
    config.boot.kernelPackages.broadcom_sta
    v4l2loopback-dc
  ];

  # Register a v4l2loopback device at boot
  boot.kernelModules = [
    "v4l2loopback-dc"
  ];

  # below from https://github.com/NixOS/nixos-hardware/blob/master/apple/default.nix
  boot.kernelParams = [
    "hid_apple.iso_layout=0"
  ];

  hardware.facetimehd.enable = lib.mkDefault
    (config.nixpkgs.config.allowUnfree or false);

  services.mbpfan.enable = lib.mkDefault true;

  # below from https://github.com/NixOS/nixos-hardware/tree/master/common/cpu/intel
  boot.initrd.kernelModules = [ "i915" "wl" ];

  hardware.cpu.intel.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;

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

  services.xserver.libinput.enable = lib.mkDefault true;


  # below from https://github.com/NixOS/nixos-hardware/blob/master/apple/macbook-pro/11-5/default.nix
  # Apparently this is currently only supported by ati_unfree drivers, not ati
  # hardware.opengl.driSupport32Bit = false;

  services.xserver.videoDrivers = [ "modesetting" "nouveau" "ati" ];

  services.udev.extraRules =
    # Disable XHC1 wakeup signal to avoid resume getting triggered some time
    # after suspend. Reboot required for this to take effect.
    lib.optionalString
      (lib.versionAtLeast config.boot.kernelPackages.kernel.version "3.13")
      ''SUBSYSTEM=="pci", KERNEL=="0000:00:14.0", ATTR{power/wakeup}="disabled"'';


  imports = [
    "${nixpkgs}/nixos/modules/hardware/network/broadcom-43xx.nix"
  ];

  # below from https://github.com/NixOS/nixos-hardware/blob/master/common/pc/ssd/default.nix
  boot.kernel.sysctl = {
    "vm.swappiness" = lib.mkDefault 1;
  };

  services.fstrim.enable = lib.mkDefault true;

  # from https://github.com/rasendubi/nixpkgs/commit/d135ae91b56872dc53fe34528b46a29b0da486a9
  # boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ]; # added above
  # boot.kernelModules = [ "wl" ]; # added above

}
