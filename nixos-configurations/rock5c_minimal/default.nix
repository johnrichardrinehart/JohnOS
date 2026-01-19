{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    inputs.sops-nix.nixosModules.default
    ./swap.nix
    ./tmpfs.nix
  ];

  # just for passing literal values to imported modules
  system.build.literals = {
    secondsToWaitForNAS = 10;
  };

  nixpkgs.overlays = [
    (final: prev: {
      hm = prev.hm.overrideAttrs {
        src = prev.fetchFromGitHub {
          owner = "johnrichardrinehart";
          repo = "HM";
          rev = "f3947be0720bfd9ce3312478d64cd35a619c5eae";
          hash = "sha256-kY7YE+S1NJs9yjUnVKjZ8jbIJm/nv/s0DNmNZej66b8=";
        };
        patches = [ ];
      };
    })
  ];

  nixpkgs.hostPlatform = "aarch64-linux";
  networking.hostName = "rock5c-minimal";
  dev.johnrinehart.rock5c.enable = true;
  dev.johnrinehart.rock5c.useMinimalKernel = true;
  dev.johnrinehart.rock5c.ssdStore = {
    enable = true;
    users = [ "john" ];
  };
  dev.johnrinehart.system.enable = true;
  dev.johnrinehart.nix.enable = true;
  dev.johnrinehart.desktop.wl-hyprland.enable = true;
  dev.johnrinehart.packages.shell.enable = true;
  dev.johnrinehart.packages.editors.enable = true;

  boot.consoleLogLevel = 7;

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
  };

  services.deluge = {
    web = {
      enable = true;
      openFirewall = true;
    };
    enable = true;
    openFilesLimit = 1048576; # 1<<20 = 2^20 = 1048576
  };

  services.jellyfin = {
    openFirewall = true;
    enable = true;
  };

  hardware.firmware = [ (pkgs.callPackage ./mali_csffw.nix { }) ];
  users.groups.video.members = [ config.services.jellyfin.user ];

  services.udev.extraRules = ''
    KERNEL=="mpp_service", MODE="0660", GROUP="video"
    KERNEL=="rga", MODE="0660", GROUP="video"
    KERNEL=="system", MODE="0666", GROUP="video"
    KERNEL=="system-dma32", MODE="0666", GROUP="video"
    KERNEL=="system-uncached", MODE="0666", GROUP="video"
    KERNEL=="system-uncached-dma32", MODE="0666", GROUP="video" RUN+="${pkgs.toybox}/bin/chmod a+rw /dev/dma_heap"
  '';

  environment.systemPackages = [
    pkgs.thin-provisioning-tools # for cache_check
  ];

  boot.kernelModules = [ "dm_cache" ];

  fileSystems."nas" = {
    mountPoint = "/mnt/nas";
    neededForBoot = false;
    fsType = "btrfs";
    device = "/dev/mapper/nas-storage";
    options = [
      "nofail"
      "x-systemd.device-timeout=${builtins.toString config.system.build.literals.secondsToWaitForNAS}s"
    ]; # takes about 5s, usually
  };

  boot.kernelPatches = [
    {
      name = "btrfs";
      patch = null;
      structuredExtraConfig = {
        BTRFS_FS = lib.kernel.yes;
        BTRFS_DEBUG = lib.kernel.yes;
      };
    }
  ];

  boot.supportedFilesystems = {
    "btrfs" = true;
  };

  # matches config from services.lvm.boot.thin.enable (I needed cache_check
  # for the NAS configuration)
  environment.etc."lvm/lvm.conf".text =
    lib.concatMapStringsSep "\n"
      (bin: "global/${bin}_executable = ${pkgs.thin-provisioning-tools}/bin/${bin}")
      [
        "thin_check"
        "thin_dump"
        "thin_repair"
        "cache_check"
        "cache_dump"
        "cache_repair"
      ];

  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.wait-online.enable = false;
  systemd.network.networks."end0" = {
    # [Match] logically ANDs all match rules
    #matchConfig.MACAddress = "7a:16:b7:43:6a:92";
    matchConfig.Name = "end*";
    # acquire a DHCP lease on link up
    networkConfig.DHCP = "yes";
    # this port is not always connected and not required to be online
    linkConfig.RequiredForOnline = "no";
  };

  systemd.network.links."10-wlan0" = {
    matchConfig.OriginalName = "wlan*";
    # eFUSE not programmed on this device, so set MAC explicitly
    linkConfig.MACAddress = "88:00:03:00:10:55";
  };

  systemd.network.networks."wlan0" = {
    matchConfig.Name = "wlan*";
    networkConfig.DHCP = "yes";
    linkConfig.RequiredForOnline = "no";
  };

  # Use iwd for WiFi (lighter than NetworkManager, integrates with systemd-networkd)
  networking.networkmanager.enable = false;
  networking.wireless.iwd = {
    enable = true;
    settings = {
      General = {
        # AIC8800 eFUSE not programmed, driver randomizes MAC - override it
        AddressOverride = "88:00:03:00:10:55";
        AddressRandomization = "disabled";
      };
      Network = {
        # Let systemd-networkd handle DHCP
        EnableIPv6 = true;
      };
    };
  };

  nix.package = pkgs.nixVersions.nix_2_32;

  # SOPS configuration - key is manually provisioned to /boot/age.secret before first boot
  sops.age.keyFile = "/boot/age.secret";
  sops.defaultSopsFile = ./secrets.yaml;
  sops.secrets.wifi-ssid = { };
  sops.secrets.wifi-psk = { };

  # Copy WiFi secret to iwd config directory with SSID-based filename
  systemd.services.iwd-wifi-secret = {
    description = "Set up iwd WiFi credentials from sops secrets";
    wantedBy = [ "multi-user.target" ];
    before = [ "iwd.service" ];
    script = ''
      # Wait for secrets to be available (sops-nix decrypts them at activation)
      for i in $(seq 1 30); do
        [ -f /run/secrets/wifi-ssid ] && [ -f /run/secrets/wifi-psk ] && break
        sleep 1
      done

      if [ ! -f /run/secrets/wifi-ssid ] || [ ! -f /run/secrets/wifi-psk ]; then
        echo "WiFi secrets not found, skipping"
        exit 0
      fi

      SSID=$(cat /run/secrets/wifi-ssid)
      mkdir -p /var/lib/iwd
      cp /run/secrets/wifi-psk "/var/lib/iwd/$SSID.psk"
      chmod 600 "/var/lib/iwd/$SSID.psk"
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };
}
