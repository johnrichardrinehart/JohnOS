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

    overlayStore = {
      enable = lib.mkEnableOption "SSD-backed overlay store for Nix";

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

    # SSD overlay store config
    (lib.mkIf cfg.overlayStore.enable {
      # Mount btrfs SSD volume
      fileSystems.${cfg.overlayStore.mountPoint} = {
        device = cfg.overlayStore.device;
        fsType = "btrfs";
        options = [
          "subvol=/"
          "compress=zstd"
          "noatime"
          "nofail"
          "x-systemd.device-timeout=10s"
        ];
      };

      # Mount subvolumes
      fileSystems."${cfg.overlayStore.mountPoint}/upper" = {
        device = cfg.overlayStore.device;
        fsType = "btrfs";
        options = [ "subvol=@upper" "compress=zstd" "noatime" "nofail" ];
      };

      fileSystems."${cfg.overlayStore.mountPoint}/work" = {
        device = cfg.overlayStore.device;
        fsType = "btrfs";
        options = [ "subvol=@work" "compress=zstd" "noatime" "nofail" ];
      };

      fileSystems."${cfg.overlayStore.mountPoint}/build" = {
        device = cfg.overlayStore.device;
        fsType = "btrfs";
        options = [ "subvol=@build" "compress=zstd" "noatime" "nofail" ];
      };

      fileSystems."${cfg.overlayStore.mountPoint}/cache" = {
        device = cfg.overlayStore.device;
        fsType = "btrfs";
        options = [ "subvol=@cache" "compress=zstd" "noatime" "nofail" ];
      };

      # Overlay mount on /nix/store (post-boot, before nix-daemon)
      systemd.mounts = [{
        what = "overlay";
        where = "/nix/store";
        type = "overlay";
        mountConfig.Options = lib.concatStringsSep "," [
          "lowerdir=/nix/store"
          "upperdir=${cfg.overlayStore.mountPoint}/upper"
          "workdir=${cfg.overlayStore.mountPoint}/work"
        ];

        unitConfig = {
          ConditionPathIsMountPoint = cfg.overlayStore.mountPoint;
          DefaultDependencies = false;
        };

        after = [
          "local-fs.target"
          "${utils.escapeSystemdPath cfg.overlayStore.mountPoint}.mount"
          "${utils.escapeSystemdPath "${cfg.overlayStore.mountPoint}/upper"}.mount"
          "${utils.escapeSystemdPath "${cfg.overlayStore.mountPoint}/work"}.mount"
        ];
        requires = [
          "${utils.escapeSystemdPath cfg.overlayStore.mountPoint}.mount"
        ];
        before = [ "nix-daemon.service" "nix-daemon.socket" ];
        wantedBy = [ "multi-user.target" ];
      }];

      # Ensure nix-daemon waits for overlay
      systemd.services.nix-daemon = {
        after = [ "nix-store.mount" ];
        wants = [ "nix-store.mount" ];
        environment.TMPDIR = "${cfg.overlayStore.mountPoint}/build";
      };

      systemd.sockets.nix-daemon = {
        after = [ "nix-store.mount" ];
        wants = [ "nix-store.mount" ];
      };

      # Nix settings
      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
          "local-overlay-store"
        ];
        build-dir = "${cfg.overlayStore.mountPoint}/build";
      };

      # Build directory permissions
      systemd.tmpfiles.rules = [
        "d ${cfg.overlayStore.mountPoint}/build 1775 root nixbld -"
      ];

      # Bind mount for user cache (graceful fallback via nofail)
      fileSystems."/home/john/.cache/nix" = {
        device = "${cfg.overlayStore.mountPoint}/cache";
        fsType = "none";
        options = [
          "bind"
          "nofail"
          "x-systemd.requires=${utils.escapeSystemdPath cfg.overlayStore.mountPoint}.mount"
        ];
      };
    })
  ];
}
