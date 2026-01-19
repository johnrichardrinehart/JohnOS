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

    # SSD overlay store config using Nix's local-overlay-store
    # with graceful degradation when SSD is unavailable
    (lib.mkIf cfg.overlayStore.enable (let
      upperLayer = "${cfg.overlayStore.mountPoint}/upper";
      # workdir must be on same mount as upperdir, so put it inside upper
      workDir = "${cfg.overlayStore.mountPoint}/upper/.overlay-work";
      # Mount overlay directly on /nix/store so executed programs work
      buildDir = "${cfg.overlayStore.mountPoint}/build";
      overlayStoreUrl = "local-overlay://?lower-store=local&upper-layer=${upperLayer}&build-dir=${buildDir}";
    in {
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

      # Create directory structure
      systemd.tmpfiles.rules = [
        # Upper store directories on SSD
        "d ${upperLayer}/nix 0755 root root -"
        "d ${upperLayer}/nix/store 1775 root nixbld -"
        "d ${upperLayer}/nix/var 0755 root root -"
        "d ${upperLayer}/nix/var/nix 0755 root root -"
        "d ${upperLayer}/nix/var/nix/db 0755 root root -"
        # Overlay workdir (must be on same mount as upperdir)
        "d ${workDir} 0755 root root -"
        # Build directory
        "d ${cfg.overlayStore.mountPoint}/build 1775 root nixbld -"
        # Cache directory (user-owned for nix cache)
        "d ${cfg.overlayStore.mountPoint}/cache 0755 john john -"
      ];

      # Nix settings
      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
          "local-overlay-store"
        ];
        # build-dir is set dynamically via environment file based on SSD availability
      };

      # Helper scripts for overlay store management
      # Scripts are built via overlay with configuration baked in
      environment.systemPackages = let
        overlayScripts = pkgs.nix-overlay-scripts {
          mountPoint = cfg.overlayStore.mountPoint;
          inherit upperLayer workDir buildDir overlayStoreUrl;
          cacheDir = "${cfg.overlayStore.mountPoint}/cache";
        };
      in [
        pkgs.nixos-rebuild-bake
        (pkgs.writeShellScriptBin "nix-collect-garbage-safe" (builtins.readFile ./nix-collect-garbage-safe))
        overlayScripts.nix-overlay-enable
        overlayScripts.nix-overlay-disable
        overlayScripts.nix-overlay-status
      ];

      # Expose overlay scripts for standalone building
      # e.g., nix build .#nixosConfigurations.rock5c_minimal.config.system.build.nix-overlay-enable
      system.build = let
        overlayScripts = pkgs.nix-overlay-scripts {
          mountPoint = cfg.overlayStore.mountPoint;
          inherit upperLayer workDir buildDir overlayStoreUrl;
          cacheDir = "${cfg.overlayStore.mountPoint}/cache";
        };
      in {
        inherit (overlayScripts) nix-overlay-enable nix-overlay-disable nix-overlay-status;
      };

      # Setup service runs at boot - defaults to local store, user enables overlay manually
      # This ensures system always boots to a known-good state
      systemd.services.nix-overlay-store-setup = {
        description = "Initialize Nix store environment (defaults to local)";
        wantedBy = [ "multi-user.target" ];
        before = [ "nix-daemon.service" "nix-daemon.socket" ];
        after = [ "local-fs.target" ];

        unitConfig = {
          DefaultDependencies = false;
        };

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        script = ''
          ENV_FILE="/run/nix-overlay-store.env"
          STATE_FILE="/run/nix-overlay-store.mode"

          # Default to local store on boot for safety
          echo "# Boot default - local store" > "$ENV_FILE"
          echo "local" > "$STATE_FILE"

          echo "Nix store initialized in local mode"
          echo "Run 'nix-overlay-enable' to enable SSD overlay"
        '';
      };

      # Cleanup service for shutdown
      systemd.services.nix-overlay-store-cleanup = {
        description = "Cleanup Nix overlay store on shutdown";
        wantedBy = [ "multi-user.target" ];
        after = [ "nix-daemon.service" ];
        before = [ "shutdown.target" "reboot.target" "halt.target" ];

        path = [ pkgs.util-linux ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStop = "${pkgs.bash}/bin/bash -c 'findmnt -n -t overlay /nix/store && umount /nix/store || true'";
        };

        script = "true";  # No-op on start
      };

      # nix-daemon depends on setup service (wants, not requires, for graceful degradation)
      # TMPDIR is set dynamically via EnvironmentFile based on SSD availability
      systemd.services.nix-daemon = {
        after = [ "nix-overlay-store-setup.service" ];
        wants = [ "nix-overlay-store-setup.service" ];
        serviceConfig.EnvironmentFile = "-/run/nix-overlay-store.env";
      };

      systemd.sockets.nix-daemon = {
        after = [ "nix-overlay-store-setup.service" ];
        wants = [ "nix-overlay-store-setup.service" ];
      };

      # Set XDG_CACHE_HOME dynamically based on SSD availability
      environment.extraInit = ''
        if mountpoint -q "${cfg.overlayStore.mountPoint}/cache" 2>/dev/null; then
          export XDG_CACHE_HOME="${cfg.overlayStore.mountPoint}/cache"
        fi
      '';
    }))
  ];
}
