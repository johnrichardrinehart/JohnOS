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

  system.build.literals.secondsToWaitForNAS = 20;

  nixpkgs.hostPlatform = "aarch64-linux";
  nixpkgs.config.allowUnfreePredicate =
    pkg: builtins.elem (lib.getName pkg) [ "arm-trusted-firmware-rk3588" ];
  nixpkgs.config.permittedInsecurePackages = [ "python-2.7.18.8" ];

  networking.hostName = "rock5c";
  networking.firewall.logRefusedConnections = false;
  networking.firewall.logRefusedPackets = false;
  dev.johnrinehart.rock5c.enable = true;
  dev.johnrinehart.rock5c.videoBackend = "mpp";
  dev.johnrinehart.rock5c.netconsole = {
    enable = true;
    device = "wlan0";
    targetIP = "172.16.0.3";
    targetMAC = "f4:7b:09:9b:69:0f";
  };
  dev.johnrinehart.rock5c.gstreamerHwdec.enable = true;
  dev.johnrinehart.rock5c.media = {
    enable = true;
    management.enable = true;
    kodi = {
      variant = "gbm";
      autostart.enable = true;
      disable_cec_standby_on_poweroff = true;
    };
  };
  dev.johnrinehart.rock5c.rkvdec.enable =
    lib.mkDefault (config.dev.johnrinehart.rock5c.videoBackend == "mainline");
  dev.johnrinehart.rock5c.ssdStore = {
    enable = true;
    users = [ "john" ];
  };
  rock5c.enable = true;
  dev.johnrinehart.system.enable = true;
  dev.johnrinehart.nix.enable = true;
  dev.johnrinehart.desktop = {
    enable = true;
    variant = "wl-kwin";
  };
  dev.johnrinehart.packages.shell.enable = true;
  dev.johnrinehart.packages.editors.enable = true;
  services.hypridle.enable = lib.mkForce false;

  boot.consoleLogLevel = 7;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "libata.force=noncq" ];
  boot.kernelModules = [ "dm_cache" ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/${config.dev.johnrinehart.rock5c.rootfsLabel}";
    fsType = "ext4";
  };

  fileSystems."nas" = {
    mountPoint = "/mnt/nas";
    neededForBoot = false;
    fsType = "btrfs";
    device = "/dev/mapper/nas-storage";
    options = [
      "nofail"
      "x-systemd.automount"
      "x-systemd.device-timeout=${builtins.toString config.system.build.literals.secondsToWaitForNAS}s"
    ];
  };

  services.jellyfin = {
    enable = true;
    openFirewall = true;
    dataDir = "/mnt/nas/.services/jellyfin";
    cacheDir = "/mnt/nas/.services/jellyfin/cache";
  };

  systemd.services.jellyfin.unitConfig.RequiresMountsFor = [ "/mnt/nas/.services/jellyfin" ];

  users.groups.video.members = [ config.services.jellyfin.user ];
  users.users.john.extraGroups = [
    "render"
    "video"
  ];

  services.udev.extraRules = ''
    # Defense in depth: if an HDMI input node still appears, never let
    # systemd-logind treat it as a suspend/power key source.
    SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_PATH}=="platform-fde80000.hdmi", ENV{ID_INPUT_KEY}="0", TAG-="power-switch"
    SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="fde80000.hdmi", ENV{ID_INPUT_KEY}="0", TAG-="power-switch"

    ${lib.optionalString (config.dev.johnrinehart.rock5c.videoBackend == "mpp") ''
      # The vendor MPP userspace may look for either /dev/mpp or /dev/mpp_service.
      # The current kernel driver registers the device as "mpp_service", so match
      # that real node for permissions and add a /dev/mpp compatibility symlink.
      KERNEL=="mpp_service", MODE="0660", GROUP="video", SYMLINK+="mpp"
    ''}
    KERNEL=="rga", MODE="0660", GROUP="video"
    KERNEL=="system", MODE="0666", GROUP="video"
    KERNEL=="system-dma32", MODE="0666", GROUP="video"
    KERNEL=="system-uncached", MODE="0666", GROUP="video"
    KERNEL=="system-uncached-dma32", MODE="0666", GROUP="video" RUN+="${pkgs.toybox}/bin/chmod a+rw /dev/dma_heap"
  '';

  environment.systemPackages = [
    pkgs.agent-deck
    pkgs.thin-provisioning-tools
  ];

  boot.kernelPatches = [
    {
      name = "btrfs";
      patch = null;
      structuredExtraConfig = {
        BTRFS_FS = lib.kernel.yes;
        BTRFS_DEBUG = lib.kernel.yes;
      };
    }
    {
      name = "rockchip-media-alignment";
      patch = null;
      structuredExtraConfig = {
        DRM_PANFROST = lib.kernel.no;
        DRM_GEM_DMA_HELPER = lib.kernel.yes;
        DRM_ROCKCHIP = lib.kernel.yes;
        SW_SYNC = lib.kernel.yes;
        DMABUF_HEAPS = lib.kernel.yes;
        DMABUF_HEAPS_SYSTEM = lib.kernel.yes;
        DMABUF_HEAPS_CMA = lib.kernel.yes;
        CMA_AREAS = lib.mkForce (lib.kernel.freeform "7");
        CMA_SIZE_MBYTES = lib.mkForce (lib.kernel.freeform "16");
      };
    }
  ];

  boot.supportedFilesystems.btrfs = true;

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
    matchConfig.Name = "end*";
    networkConfig.DHCP = "yes";
    linkConfig.RequiredForOnline = "no";
  };

  systemd.network.links."10-wlan0" = {
    matchConfig.OriginalName = "wlan*";
    linkConfig.MACAddress = "88:00:03:00:10:55";
  };

  systemd.network.networks."wlan0" = {
    matchConfig.Name = "wlan*";
    networkConfig.DHCP = "yes";
    linkConfig.RequiredForOnline = "no";
  };

  networking.networkmanager.enable = lib.mkForce false;
  services.speechd.enable = lib.mkForce false;
  networking.wireless.iwd = {
    enable = true;
    settings = {
      General = {
        AddressOverride = "88:00:03:00:10:55";
        AddressRandomization = "disabled";
      };
      Network.EnableIPv6 = true;
    };
  };

  # PowerDevil is initiating suspend requests on this host. Disable the
  # user service entirely so Plasma cannot auto-suspend the machine.
  systemd.user.services.plasma-powerdevil.unitConfig.ConditionPathExists =
    lib.mkForce "/this/path/should/not/exist";

  nix.package = pkgs.nixVersions.nix_2_32;

  sops.age.keyFile = "/boot/age.secret";
  sops.defaultSopsFile = ./secrets.yaml;
  sops.secrets.wifi-ssid = { };
  sops.secrets.wifi-psk = { };

  systemd.services.iwd-wifi-secret = {
    description = "Set up iwd WiFi credentials from sops secrets";
    wantedBy = [ "multi-user.target" ];
    before = [ "iwd.service" ];
    script = ''
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
      install -Dm600 /run/secrets/wifi-psk "/var/lib/iwd/$SSID.psk"
      chmod 600 "/var/lib/iwd/$SSID.psk"
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };
}
