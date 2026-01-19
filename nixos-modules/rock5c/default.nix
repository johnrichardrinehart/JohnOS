{
  config,
  lib,
  pkgs,
  utils,
  modulesPath,
  ...
}:
let
  cfg = config.dev.johnrinehart.rock5c;
in
{
  imports = [
    ./kernel_minimal.nix
    ./aic8800/module.nix
  ];

  options.dev.johnrinehart.rock5c = {
    enable = lib.mkEnableOption "radxa rock5c hardware stuff";
    useMinimalKernel = lib.mkEnableOption "use minimal kernel configuration" // {
      default = false;
    };
    enableVPU = lib.mkEnableOption "the Radxa 5C VPU" // {
      default = false;
    };

    ssdStore = {
      enable = lib.mkEnableOption "SSD-backed independent Nix store and build cache";

      device = lib.mkOption {
        type = lib.types.str;
        default = "/dev/disk/by-label/NIX_SSD";
        description = "Block device for the Nix SSD partition";
      };

      mountPoint = lib.mkOption {
        type = lib.types.path;
        default = "/mnt/nix-ssd";
        description = "Base mount point for SSD btrfs volume";
      };

      users = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "john" "alice" ];
        description = "Users who should use the SSD-backed store, cache, and build directory";
      };
    };
  };

  config = lib.mkMerge [
    # Main rock5c hardware config
    (lib.mkIf cfg.enable {
      dev.johnrinehart.rock5c.aic8800.enable = true;

      nixpkgs.hostPlatform = "aarch64-linux";

      system.build.firmware = pkgs.ubootRock5ModelC;

      boot.loader.grub.enable = false;
      boot.loader.generic-extlinux-compatible.enable = true;

      system.build.sdImage = pkgs.callPackage (
        { ... }:
        let
          rootfsImage = pkgs.callPackage "${modulesPath}/../lib/make-ext4-fs.nix" ({
            storePaths = [ config.system.build.toplevel ];
            volumeLabel = "NIXOS_SD";
            populateImageCommands = ''
              ${config.boot.loader.generic-extlinux-compatible.populateCmd} \
                -c ${config.system.build.toplevel} \
                -d ./files/boot \
                -n "rockchip/rk3588s-rock-5c.dtb" \
              ;
            '';
          });
          name = "rock-5c-sdcard-image";
        in
        pkgs.stdenv.mkDerivation {
          inherit name;
          nativeBuildInputs = [ pkgs.util-linux ];
          buildCommand = ''
            set -x
            export img=$out;
            root_fs=${rootfsImage};

            rootSizeSectors=$(du -B 512 --apparent-size $root_fs | awk '{print $1}');
            imageSize=$((512*(rootSizeSectors + 0x8000)));

            # provision img
            truncate -s $imageSize $img;

            ls -lh $img;

            # create partition table
            echo "$((0x8000)),,,*" | sfdisk $img

            # write TPL+SPL
            dd \
              if=${config.system.build.firmware}/idbloader.img \
              of=$img \
              seek=$((0x40)) \
              oflag=sync \
              status=progress \
            ;

            # write U-Boot
            dd \
              if=${config.system.build.firmware}/u-boot.itb \
              of=$img \
              seek=$((0x4000)) \
              oflag=sync \
              status=progress \
            ;

            ls -lh $img;

            # write rootfs
            dd \
              bs=$((2**20)) \
              if=${rootfsImage} \
              of=$img \
              seek=$((512*0x8000))B \
              oflag=sync \
              status=progress \
            ;

            ls -lh $img;
          '';
        }
      ) { };

      boot.kernelPatches = [
        {
          name = "device-mapper-debug";
          patch = null;
          structuredExtraConfig = {
            DM_DEBUG = lib.kernel.yes;
          };
        }
        {
          name = "zram-memory-tracking";
          patch = null;
          structuredExtraConfig = {
            ZRAM_MEMORY_TRACKING = lib.kernel.yes;
          };
        }
      ];
    })

    # SSD-backed independent store for configured users
    (lib.mkIf cfg.ssdStore.enable (let
      ssdMount = cfg.ssdStore.mountPoint;
      buildDir = "${ssdMount}/build";
      cacheDir = "${ssdMount}/cache";
      storeDir = "${ssdMount}/store";
    in {
      # Mount base btrfs volume
      fileSystems.${ssdMount} = {
        device = cfg.ssdStore.device;
        fsType = "btrfs";
        options = [ "subvol=/" "compress=zstd" "noatime" "nofail" "x-systemd.device-timeout=10s" ];
      };

      # Mount @build subvolume
      fileSystems.${buildDir} = {
        device = cfg.ssdStore.device;
        fsType = "btrfs";
        options = [ "subvol=@build" "compress=zstd" "noatime" "nofail" "x-systemd.device-timeout=5s" ];
      };

      # Mount @cache subvolume
      fileSystems.${cacheDir} = {
        device = cfg.ssdStore.device;
        fsType = "btrfs";
        options = [ "subvol=@cache" "compress=zstd" "noatime" "nofail" "x-systemd.device-timeout=5s" ];
      };

      # Mount @store subvolume
      fileSystems.${storeDir} = {
        device = cfg.ssdStore.device;
        fsType = "btrfs";
        options = [ "subvol=@store" "compress=zstd" "noatime" "nofail" "x-systemd.device-timeout=5s" ];
      };

      # Directory permissions - shared dirs + per-user cache dirs
      systemd.tmpfiles.rules = [
        "d ${buildDir} 1775 root nixbld -"
        "d ${cacheDir} 0755 root root -"
        "d ${storeDir} 0755 root root -"
        "d ${storeDir}/nix 0755 root root -"
        "d ${storeDir}/nix/store 1775 root nixbld -"
        "d ${storeDir}/nix/var 0755 root root -"
        "d ${storeDir}/nix/var/nix 0755 root root -"
        "d ${storeDir}/nix/var/nix/db 0755 root root -"
      ] ++ (map (user: "d ${cacheDir}/${user} 0755 ${user} ${user} -") cfg.ssdStore.users);

      # System-wide build-dir on SSD
      nix.settings.build-dir = lib.mkDefault buildDir;

      # Environment for configured users (XDG_CACHE_HOME + independent store with system store as substituter)
      # Generate a case statement for all configured users
      environment.extraInit = let
        userList = lib.concatStringsSep "|" cfg.ssdStore.users;
      in ''
        if mountpoint -q "${ssdMount}" 2>/dev/null; then
          case "$USER" in
            ${userList})
              export XDG_CACHE_HOME="${cacheDir}/$USER"
              export NIX_STORE_DIR="${storeDir}/nix/store"
              export NIX_STATE_DIR="${storeDir}/nix/var/nix"
              export NIX_LOG_DIR="${storeDir}/nix/var/log/nix"
              # Use system store as substituter so builds can copy from /nix/store
              export NIX_CONFIG="extra-substituters = /nix/store"
              ;;
          esac
        fi
      '';

      # nix-daemon uses SSD build dir when available
      systemd.services.nix-daemon.serviceConfig.EnvironmentFile = [
        "-%S/nix-daemon-ssd.env"
      ];

      # Service to configure nix-daemon env based on SSD availability
      systemd.services.nix-ssd-env = {
        description = "Configure nix-daemon environment for SSD";
        wantedBy = [ "multi-user.target" ];
        before = [ "nix-daemon.service" "nix-daemon.socket" ];
        after = [ "local-fs.target" "${utils.escapeSystemdPath ssdMount}.mount" "${utils.escapeSystemdPath buildDir}.mount" ];
        wants = [ "${utils.escapeSystemdPath ssdMount}.mount" "${utils.escapeSystemdPath buildDir}.mount" ];
        unitConfig.DefaultDependencies = false;
        serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
        script = ''
          ENV_FILE="/var/lib/nix-daemon-ssd.env"
          if mountpoint -q "${buildDir}" 2>/dev/null; then
            echo "TMPDIR=${buildDir}" > "$ENV_FILE"
          else
            rm -f "$ENV_FILE"
          fi
        '';
      };

      systemd.sockets.nix-daemon = {
        after = [ "nix-ssd-env.service" ];
        wants = [ "nix-ssd-env.service" ];
      };
    }))
  ];
}
