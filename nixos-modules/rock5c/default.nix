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
      cacheDir = "${ssdMount}/cache";
      storeDir = "${ssdMount}/store";
      device = cfg.ssdStore.device;
    in {
      # Service to mount SSD if available - runs late, never fails, doesn't block boot
      systemd.services.nix-ssd-mount = {
        description = "Mount Nix SSD if available";
        wantedBy = [ "multi-user.target" ];
        after = [ "local-fs.target" ];
        path = [ pkgs.util-linux pkgs.coreutils pkgs.btrfs-progs pkgs.lvm2 ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStop = pkgs.writeShellScript "nix-ssd-unmount" ''
            # Unmount in reverse order, ignore failures
            umount "${storeDir}" 2>/dev/null || true
            umount "${cacheDir}" 2>/dev/null || true
            umount "${buildDir}" 2>/dev/null || true
            umount "${ssdMount}" 2>/dev/null || true
            rm -f /var/lib/nix-daemon-ssd.env
          '';
        };
        script = ''
          # No set -e: we handle all errors explicitly and always exit 0

          # Try to activate LVM VG in degraded mode (for when NAS disks are unavailable)
          # This allows the nix_ssd LV to be activated even if the NAS storage PV is missing
          echo "Attempting to activate LVM VG 'nas' in degraded mode..."
          vgchange -ay --activationmode degraded nas 2>/dev/null || true

          # Check if device exists
          if [ ! -e "${device}" ]; then
            echo "SSD device ${device} not found, skipping"
            exit 0
          fi

          # Create base mount point only
          mkdir -p "${ssdMount}" || exit 0

          # Mount base volume - if this fails, skip everything
          if ! mount -t btrfs -o subvol=/,compress=zstd,noatime "${device}" "${ssdMount}"; then
            echo "Failed to mount base volume, skipping SSD setup"
            exit 0
          fi

          # Create subdirectory mount points (inside the mounted btrfs)
          mkdir -p "${buildDir}" "${cacheDir}" "${storeDir}" || true

          # Mount subvolumes - continue even if some fail
          mount -t btrfs -o subvol=@build,compress=zstd,noatime "${device}" "${buildDir}" || echo "Warning: failed to mount @build"
          mount -t btrfs -o subvol=@cache,compress=zstd,noatime "${device}" "${cacheDir}" || echo "Warning: failed to mount @cache"
          mount -t btrfs -o subvol=@store,compress=zstd,noatime "${device}" "${storeDir}" || echo "Warning: failed to mount @store"

          # Set up directory permissions if mounts succeeded
          if mountpoint -q "${buildDir}" 2>/dev/null; then
            chown root:ssdstore "${buildDir}" || true
            chmod 1775 "${buildDir}" || true
          fi

          if mountpoint -q "${cacheDir}" 2>/dev/null; then
            chmod 0755 "${cacheDir}" || true
            # Create per-user cache directories
            ${lib.concatMapStringsSep "\n" (user: ''
              mkdir -p "${cacheDir}/${user}" || true
              chown ${user}:${user} "${cacheDir}/${user}" || true
              chmod 0755 "${cacheDir}/${user}" || true
            '') cfg.ssdStore.users}
          fi

          if mountpoint -q "${storeDir}" 2>/dev/null; then
            mkdir -p "${storeDir}/nix/store" "${storeDir}/nix/var/nix/db" "${storeDir}/nix/var/log/nix" || true
            chown root:ssdstore "${storeDir}/nix/store" || true
            chmod 1775 "${storeDir}/nix/store" || true
          fi

          # Write nix-daemon environment file if build dir is available
          if mountpoint -q "${buildDir}" 2>/dev/null; then
            echo "TMPDIR=${buildDir}" > /var/lib/nix-daemon-ssd.env || true
          else
            rm -f /var/lib/nix-daemon-ssd.env || true
          fi

          echo "SSD setup complete"
        '';
      };

      # nix-daemon uses SSD build dir when available (- prefix means ignore if file missing)
      systemd.services.nix-daemon.serviceConfig.EnvironmentFile = [
        "-%S/nix-daemon-ssd.env"
      ];

      # Environment for configured users (XDG_CACHE_HOME + independent store with system store as substituter)
      # Only activates if SSD is actually mounted and not running as a systemd service
      environment.extraInit = let
        userList = lib.concatStringsSep "|" cfg.ssdStore.users;
      in ''
        # Skip if running as a systemd service (home-manager activation sets these empty)
        if [ -z "''${INVOCATION_ID:-}" ] && mountpoint -q "${ssdMount}" 2>/dev/null; then
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
    }))

    # home-manager should use system store, not user's SSD store
    (lib.mkIf cfg.ssdStore.enable {
      systemd.services = lib.listToAttrs (map (user: {
        name = "home-manager-${user}";
        value = {
          environment = {
            NIX_STORE_DIR = "";
            NIX_STATE_DIR = "";
            NIX_LOG_DIR = "";
          };
        };
      }) cfg.ssdStore.users);

      # Create ssdstore group and add configured users
      users.groups.ssdstore = {};
      users.users = lib.listToAttrs (map (user: {
        name = user;
        value = { extraGroups = [ "ssdstore" ]; };
      }) cfg.ssdStore.users);
    })
  ];
}
