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
    #./kernel_radxa.nix
    ./kernel_6.10.nix
  ];

  options.dev.johnrinehart.rock5c = {
    enable = lib.mkEnableOption "radxa rock5c hardware stuff";
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.hostPlatform = "aarch64-linux";
    fileSystems = {
      "/" = {
        device = "/dev/disk/by-label/NIXOS_SD";
        fsType = "ext4";
      };
    };

    boot.loader.grub.enable = false;
    boot.loader.generic-extlinux-compatible.enable = true;
    system.build.firmware = pkgs.ubootRock5ModelC;
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
      }
    ) { };

    boot.consoleLogLevel = 7;

    boot.kernelParams = [
      "earlyprintk"
      "console=ttyS0,1500000"
      "console=ttyS1,1500000"
      "console=ttyS2,1500000"
      "console=ttyAMA0,1500000"
      "console=tty0"
      "console=ttyFIQ0,1500000"
      "printk.synchronous=1"
      "earlycon=uart8250,mmio32,0xfeb50000"
    ];

  };
}
