{
  config,
  lib,
  pkgs,
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
  };

  config = lib.mkIf cfg.enable {
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
        name = "device-mapper";
        patch = null;
        structuredExtraConfig = {
          DM_DEBUG = lib.kernel.yes;
        };
      }
      {
        name = "zram_comp";
        patch = null;
        structuredExtraConfig = {
          ZRAM_MEMORY_TRACKING = lib.kernel.yes;
        };
      }
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

    # matches config from services.lvm.boot.thin.enable (I needed cache_check for the NAS configuration)
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

    environment.systemPackages = [ pkgs.thin-provisioning-tools ];
  };
}
