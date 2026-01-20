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

      # Add provision-sd to pkgs via overlay
      nixpkgs.overlays = [
        (final: prev: {
          provision-sd = prev.callPackage ./provision-sd.nix { };
        })
      ];

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
    # All mounting is done dynamically - no fileSystems declarations that could affect boot
    (lib.mkIf cfg.ssdStore.enable (let
      ssdMount = cfg.ssdStore.mountPoint;
      buildDir = "${ssdMount}/build";
      cacheDir = "${ssdMount}/nix-cache";
      device = cfg.ssdStore.device;
    in {
      # Service to mount SSD if available - runs early, never fails, has 10s timeout
      systemd.services.nix-ssd-mount = {
        description = "Mount Nix SSD if available";
        wantedBy = [ "multi-user.target" ];
        before = [ "nix-daemon.service" ];
        after = [ "local-fs.target" ];
        path = [ pkgs.util-linux pkgs.coreutils pkgs.btrfs-progs pkgs.lvm2 ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStartSec = "10s";
          ExecStop = pkgs.writeShellScript "nix-ssd-unmount" ''
            # Unmount in reverse order, ignore failures
            umount "${cacheDir}" 2>/dev/null || true
            umount "${buildDir}" 2>/dev/null || true
            umount "${ssdMount}" 2>/dev/null || true
            rm -f /run/nix/ssd.conf
          '';
        };
        script = ''
          set -e

          # Try to activate LVM VG in degraded mode (for when NAS disks are unavailable)
          # This allows the nix_ssd LV to be activated even if the NAS storage PV is missing
          echo "Attempting to activate LVM VG 'nas' in degraded mode..."
          vgchange -ay --activationmode degraded nas 2>/dev/null || true

          # Check if device exists
          if [ ! -e "${device}" ]; then
            echo "SSD device ${device} not found"
            exit 1
          fi

          # Create base mount point only
          mkdir -p "${ssdMount}"

          # Mount base volume
          if ! mount -t btrfs -o subvol=/,compress=zstd,noatime "${device}" "${ssdMount}"; then
            echo "Failed to mount base volume"
            exit 1
          fi

          # Create subdirectory mount points (inside the mounted btrfs)
          mkdir -p "${buildDir}" "${cacheDir}"

          # Mount subvolumes
          if ! mount -t btrfs -o subvol=@build,compress=zstd,noatime "${device}" "${buildDir}"; then
            echo "Failed to mount @build subvolume"
            exit 1
          fi

          if ! mount -t btrfs -o subvol=@cache,compress=zstd,noatime "${device}" "${cacheDir}"; then
            echo "Failed to mount @cache subvolume"
            exit 1
          fi

          # Set up directory permissions
          chown root:nixbld "${buildDir}"
          chmod 1775 "${buildDir}"

          chmod 0755 "${cacheDir}"
          # Create per-user cache directories
          ${lib.concatMapStringsSep "\n" (user: ''
            mkdir -p "${cacheDir}/${user}"
            chown ${user}:${user} "${cacheDir}/${user}"
            chmod 0755 "${cacheDir}/${user}"
          '') cfg.ssdStore.users}

          # Write nix config snippet
          mkdir -p /run/nix
          echo "build-dir = ${buildDir}" > /run/nix/ssd.conf

          echo "SSD setup complete"
        '';
      };

      # Include SSD-specific nix config if present
      nix.extraOptions = ''
        !include /run/nix/ssd.conf
      '';

      # nix-daemon waits for SSD mount to complete (success or failure) before starting
      systemd.services.nix-daemon = {
        after = [ "nix-ssd-mount.service" ];
        wants = [ "nix-ssd-mount.service" ];
      };

      # Environment for configured users (Nix cache on SSD)
      # Only activates if SSD is actually mounted
      environment.extraInit = let
        userList = lib.concatStringsSep "|" cfg.ssdStore.users;
      in ''
        if mountpoint -q "${ssdMount}" 2>/dev/null; then
          case "$USER" in
            ${userList})
              export NIX_CACHE_HOME="${cacheDir}/$USER"
              ;;
          esac
        fi
      '';
    }))
  ];
}
