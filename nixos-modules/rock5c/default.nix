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
      # cf. https://github.com/radxa/kernel/commit/d35989ed644b9d67de09849779e5147f4332df55
      {
        name = "enable-hdmi-cec";
        patch = ./0001-feat-enable-CEC-for-Rock-5C.patch;
      }
    ];
  };
}
