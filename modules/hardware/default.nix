{ config, lib, pkgs, modulesPath, ... }:
let
  cfg = config.dev.johnrinehart.rock5c;
in {
  options.dev.johnrinehart.rock5c = {
    enable = lib.mkEnableOption "radxa rock5c hardware stuff";
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.hostPlatform  = "aarch64-linux";
    fileSystems = {
      "/" = {
        device = "/dev/disk/by-label/NIXOS_SD";
        fsType = "ext4";
      };
    };

    boot.loader.grub.enable = false;
    boot.loader.generic-extlinux-compatible.enable = true;
    system.build.firmware = pkgs.ubootRock5ModelC;
    system.build.sdImage = pkgs.callPackage ({ ... }:
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
    in pkgs.stdenv.mkDerivation {
      inherit name;
      nativeBuildInputs = [ pkgs.util-linux ];
      buildCommand = ''
        set -x
        export img=$out;
        root_fs=${rootfsImage};
        ''
        #mkdir $PWD/all_fs $PWD/mount;
        #ls -lh
        #ln -s ${pkgs.linux}/lib /lib
        #ls -lh ${rootfsImage}
        #${pkgs.kmod}/bin/modprobe loop
        #${pkgs.strace}/bin/strace mount -o loop ${rootfsImage} $PWD/mount;
        #cp -ra $PWD/mount/* $PWD/all_fs/;
        #mkdir $PWD/all_fs/boot;
        #cp -ra /boot/* $PWD/all_fs/boot/;
        + ''

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
          if=${config.system.build.firmware}/uboot.img \
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
    }) {};

    boot.consoleLogLevel = 7;

    boot.kernelParams = [
      "earlyprintk"
      "console=ttyS0,1500000"
      "console=ttyS1,1500000"
    ];

    nixpkgs.overlays = [
      (self: super: {
        linuxRock5C = config.boot.kernelPackages.kernel.override (old: {
          structuredExtraConfig = with lib.kernel; old.structuredExtraConfig // {
            EARLY_PRINTK=Y;
            CONFIG_DEBUG=Y;
          };
        });
      })
    ];

    boot.kernelPatches = [
      {
        name = "arm64-dts-rockchip-add-rock-5c (rev: d14f6c55c9d6a6fc5bed6f9ee4734f3a7f4e2b94)";
        patch = ./0001-arm64-dts-rockchip-add-rock-5c.patch;
      }
      {
        name = "arm64-dts-rockchip-add-rock5c-spi-devicetree (rev: 72b99c4fdfee18b85e3e2f582e6be0e01d709aa1)";
        patch = ./0002-arm64-dts-rockchip-add-rock5c-spi-devicetree.patch;
      }
      {
        name = "pull in necessary files";
        patch = ./0003-chore-pull-in-necessary-dt-bindings-and-dtsi-files.patch;
      }
      {
        name = "check out the dts explicitly";
        patch = ./0004-fix-just-checkout-the-dts-from-linux-6.1-stan-rkr1.patch;
      }
      {
        name = "keep only the device trees that matter (Rock 5C)";
        patch = ./0005-chore-retain-only-those-device-trees-that-I-care-abo.patch;
      }
    ];
  };
}
