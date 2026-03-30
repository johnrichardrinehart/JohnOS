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
  mppDriverBits = {
    VDPU1 = 2;
    VEPU1 = 4;
    VDPU2 = 8;
    VEPU2 = 16;
    RKVDEC = 64;
    RKVENC = 128;
    IEP2 = 512;
    JPGDEC = 1024;
    RKVDEC2 = 2048;
    RKVENC2 = 4096;
    AV1DEC = 8192;
    VDPP = 16384;
    JPGENC = 32768;
  };
  mppDriverNames = builtins.attrNames mppDriverBits;
  mppMaskFromEnabledDrivers =
    names: lib.foldl' lib.bitOr 0 (map (name: mppDriverBits.${name}) names);
  mppMaskFromDisabledDrivers =
    names: mppMaskFromEnabledDrivers (lib.filter (name: !(builtins.elem name names)) mppDriverNames);
  effectiveMppDriverMask =
    if cfg.mpp.driverMask != null then
      cfg.mpp.driverMask
    else if cfg.mpp.disabledDrivers != [ ] then
      mppMaskFromDisabledDrivers cfg.mpp.disabledDrivers
    else
      null;
  makeRock5cImage =
    {
      name,
      volumeLabel ? cfg.rootfsLabel,
    }:
    pkgs.callPackage (
      { ... }:
      let
        runtimeRootDevice = "/dev/disk/by-label/${cfg.rootfsLabel}";
        imageRootDevice = "/dev/disk/by-label/${volumeLabel}";
        rootfsImage = pkgs.callPackage "${modulesPath}/../lib/make-ext4-fs.nix" ({
          storePaths = [ config.system.build.toplevel ];
          inherit volumeLabel;
          populateImageCommands = ''
            ${config.boot.loader.generic-extlinux-compatible.populateCmd} \
              -c ${config.system.build.toplevel} \
              -d ./files/boot \
              -n "rockchip/rk3588s-rock-5c.dtb" \
            ;

            if [ "${imageRootDevice}" != "${runtimeRootDevice}" ]; then
              matchingFiles=$(grep -rl -- "${runtimeRootDevice}" ./files/boot || true)
              for bootFile in $matchingFiles; do
                substituteInPlace "$bootFile" \
                  --replace-fail "${runtimeRootDevice}" "${imageRootDevice}"
              done
            fi
          '';
        });
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

          truncate -s $imageSize $img;
          echo "$((0x8000)),,,*" | sfdisk $img

          dd if=${config.system.build.firmware}/idbloader.img of=$img seek=$((0x40)) oflag=sync status=progress
          dd if=${config.system.build.firmware}/u-boot.itb of=$img seek=$((0x4000)) oflag=sync status=progress
          dd bs=$((2**20)) if=${rootfsImage} of=$img seek=$((512*0x8000))B oflag=sync status=progress
        '';
      }
    ) { };
in
{
  imports = [
    ./kernel_minimal.nix
    ./aic8800/module.nix
    ./gstreamer-hwdec/module.nix
    ./media/default.nix
    ./rkvdec/module.nix
  ];

  options.dev.johnrinehart.rock5c = {
    enable = lib.mkEnableOption "radxa rock5c hardware stuff";
    useMinimalKernel = lib.mkEnableOption "use minimal kernel configuration" // {
      default = false;
    };
    videoBackend = lib.mkOption {
      type = lib.types.enum [ "mainline" "mpp" ];
      default = "mainline";
      description = ''
        Select which Rockchip video stack should own the RK3588S2 media blocks.
        "mainline" keeps the V4L2/media drivers such as rockchip_vdec and hantro_vpu.
        "mpp" applies the vendor-style MPP device-tree takeover intended for /dev/mpp.
      '';
    };
    mpp = {
      disabledDrivers = lib.mkOption {
        type = lib.types.listOf (lib.types.enum mppDriverNames);
        default = [ ];
        example = [ "RKVDEC2" ];
        description = ''
          MPP subdrivers to suppress when loading `rk_vcodec`. This is the
          preferred user-facing way to opt out of specific engines without
          hand-constructing a bitmask.
        '';
      };
      driverMask = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.unsigned;
        default = null;
        example = 10240;
        description = ''
          Optional `rk_vcodec` subdriver bitmask passed as the `mpp_driver_mask`
          module parameter. Leave this unset to register all Kconfig-enabled MPP
          subdrivers. This is a low-level escape hatch; prefer
          `dev.johnrinehart.rock5c.mpp.disabledDrivers` for normal use.
        '';
      };
    };
    enableVPU = lib.mkEnableOption "the Radxa 5C VPU" // {
      default = false;
    };

    rootfsLabel = lib.mkOption {
      type = lib.types.str;
      default = "NIXOS_SD";
      description = "Filesystem label used by the default Rock 5C rootfs image and boot config.";
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

    netconsole = {
      enable = lib.mkEnableOption "netconsole kernel log streaming for crash capture";

      device = lib.mkOption {
        type = lib.types.str;
        default = "end0";
        description = "Network interface used for netconsole.";
      };

      targetIP = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "172.16.0.10";
        description = "Destination IPv4 address for netconsole UDP logs.";
      };

      targetMAC = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "aa:bb:cc:dd:ee:ff";
        description = "Destination MAC address for netconsole UDP logs.";
      };

      targetPort = lib.mkOption {
        type = lib.types.port;
        default = 6666;
        description = "Destination UDP port for netconsole.";
      };

      sourcePort = lib.mkOption {
        type = lib.types.port;
        default = 6665;
        description = "Source UDP port for netconsole.";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      dev.johnrinehart.rock5c.aic8800.enable = true;

      nixpkgs.hostPlatform = "aarch64-linux";

      nixpkgs.overlays = [
        (final: prev:
          let
            rock5cFlashImage = prev.callPackage ./flash-image.nix { };
            flashRock5cSd = prev.writeShellScriptBin "flash-rock5c-sd" ''
              exec ${rock5cFlashImage}/bin/rock5c-flash-image --target-type sd "$@"
            '';
            flashRock5cEmmc = prev.writeShellScriptBin "flash-rock5c-emmc" ''
              exec ${rock5cFlashImage}/bin/rock5c-flash-image --target-type emmc "$@"
            '';
          in
          {
            rock5c-flash-image = rock5cFlashImage;
            flash-rock5c-sd = flashRock5cSd;
            flash-rock5c-emmc = flashRock5cEmmc;
            provision-sd = flashRock5cSd;
            provision-emmc = flashRock5cEmmc;
          })
      ];

      system.build.firmware = pkgs.ubootRock5ModelC;

      boot.loader.grub.enable = false;
      boot.loader.generic-extlinux-compatible.enable = true;

      hardware.deviceTree.overlays = [
        {
          name = "rock5c-hdmi0-audio";
          filter = "rockchip/rk3588s-rock-5c.dtb";
          dtsText = ''
            /dts-v1/;
            /plugin/;

            / {
              compatible = "radxa,rock-5c", "rockchip,rk3588s";
            };

            &hdmi0_sound {
              status = "okay";
            };

            &i2s5_8ch {
              status = "okay";
            };
          '';
        }
        {
          name = "rock5c-ramoops";
          filter = "rockchip/rk3588s-rock-5c.dtb";
          dtsText = ''
            /dts-v1/;
            /plugin/;

            / {
              compatible = "radxa,rock-5c", "rockchip,rk3588s";
            };

            &{/reserved-memory} {
              ramoops: ramoops@110000 {
                compatible = "ramoops";
                reg = <0x0 0x110000 0x0 0xe0000>;
                boot-log-size = <0x8000>;
                boot-log-count = <0x1>;
                console-size = <0x80000>;
                pmsg-size = <0x30000>;
                ftrace-size = <0x0>;
                record-size = <0x14000>;
              };
            };
          '';
        }
      ] ++ lib.optionals (cfg.videoBackend == "mpp") [
        {
          name = "rock5c-mpp-service";
          filter = "rockchip/rk3588s-rock-5c.dtb";
          dtsText = ''
            /dts-v1/;
            /plugin/;

            / {
              compatible = "radxa,rock-5c", "rockchip,rk3588s";
            };

            &{/} {
              mpp_srv: mpp-srv {
                compatible = "rockchip,mpp-service";
                rockchip,taskqueue-count = <12>;
                rockchip,resetgroup-count = <1>;
                status = "okay";
              };

              jpege_ccu: jpege-ccu {
                compatible = "rockchip,vpu-jpege-ccu";
                status = "okay";
              };

              rkvenc_ccu: rkvenc-ccu {
                compatible = "rockchip,rkv-encoder-v2-ccu";
                status = "okay";
              };

              rkvdec_ccu: rkvdec-ccu@fdc30000 {
                compatible = "rockchip,rkv-decoder-v2-ccu";
                reg = <0x0 0xfdc30000 0x0 0x100>;
                reg-names = "ccu";
                clocks = <&cru 383>;
                clock-names = "aclk_ccu";
                assigned-clocks = <&cru 383>;
                assigned-clock-rates = <600000000>;
                resets = <&cru 321>;
                reset-names = "video_ccu";
                rockchip,skip-pmu-idle-request;
                rockchip,ccu-mode = <1>;
                power-domains = <&power 14>;
                status = "okay";
              };

              vdpu: vdpu@fdb50400 {
                compatible = "rockchip,vpu-decoder-v2";
                reg = <0x0 0xfdb50400 0x0 0x400>;
                interrupts = <0 119 4 0>;
                interrupt-names = "irq_vdpu";
                clocks = <&cru 433>, <&cru 434>;
                clock-names = "aclk_vcodec", "hclk_vcodec";
                rockchip,normal-rates = <594000000>, <0>;
                assigned-clocks = <&cru 433>;
                assigned-clock-rates = <594000000>;
                resets = <&cru 353>, <&cru 354>;
                reset-names = "shared_video_a", "shared_video_h";
                rockchip,skip-pmu-idle-request;
                rockchip,disable-auto-freq;
                iommus = <&vpu121_mmu>;
                rockchip,srv = <&mpp_srv>;
                rockchip,taskqueue-node = <0>;
                rockchip,resetgroup-node = <0>;
                power-domains = <&power 21>;
                status = "okay";
              };

              jpegd: jpegd@fdb90000 {
                compatible = "rockchip,rkv-jpeg-decoder-v1";
                reg = <0x0 0xfdb90000 0x0 0x400>;
                interrupts = <0 129 4 0>;
                interrupt-names = "irq_jpegd";
                clocks = <&cru 421>, <&cru 422>;
                clock-names = "aclk_vcodec", "hclk_vcodec";
                rockchip,normal-rates = <600000000>, <0>;
                assigned-clocks = <&cru 421>;
                assigned-clock-rates = <600000000>;
                resets = <&cru 363>, <&cru 364>;
                reset-names = "video_a", "video_h";
                rockchip,skip-pmu-idle-request;
                iommus = <&jpegd_mmu>;
                rockchip,srv = <&mpp_srv>;
                rockchip,taskqueue-node = <1>;
                power-domains = <&power 21>;
                status = "okay";
              };

              jpegd_mmu: iommu@fdb90480 {
                compatible = "rockchip,rk3588-iommu", "rockchip,rk3568-iommu";
                reg = <0x0 0xfdb90480 0x0 0x40>;
                interrupts = <0 130 4 0>;
                interrupt-names = "irq_jpegd_mmu";
                clocks = <&cru 421>, <&cru 422>;
                clock-names = "aclk", "iface";
                power-domains = <&power 21>;
                #iommu-cells = <0>;
                status = "okay";
              };

              iep: iep@fdbb0000 {
                compatible = "rockchip,iep-v2";
                reg = <0x0 0xfdbb0000 0x0 0x500>;
                interrupts = <0 117 4 0>;
                interrupt-names = "irq_iep";
                clocks = <&cru 411>, <&cru 410>, <&cru 412>;
                clock-names = "aclk", "hclk", "sclk";
                rockchip,normal-rates = <594000000>, <0>;
                assigned-clocks = <&cru 411>;
                assigned-clock-rates = <594000000>;
                resets = <&cru 366>, <&cru 365>, <&cru 367>;
                reset-names = "rst_a", "rst_h", "rst_s";
                rockchip,skip-pmu-idle-request;
                rockchip,disable-auto-freq;
                power-domains = <&power 21>;
                rockchip,srv = <&mpp_srv>;
                rockchip,taskqueue-node = <6>;
                iommus = <&iep_mmu>;
                status = "okay";
              };

              iep_mmu: iommu@fdbb0800 {
                compatible = "rockchip,rk3588-iommu", "rockchip,rk3568-iommu";
                reg = <0x0 0xfdbb0800 0x0 0x100>;
                interrupts = <0 117 4 0>;
                interrupt-names = "irq_iep_mmu";
                clocks = <&cru 411>, <&cru 410>;
                clock-names = "aclk", "iface";
                #iommu-cells = <0>;
                power-domains = <&power 21>;
                status = "okay";
              };

              rkvenc0: rkvenc-core@fdbd0000 {
                compatible = "rockchip,rkv-encoder-v2-core";
                reg = <0x0 0xfdbd0000 0x0 0x6000>;
                interrupts = <0 101 4 0>;
                interrupt-names = "irq_rkvenc0";
                clocks = <&cru 438>, <&cru 437>, <&cru 439>;
                clock-names = "aclk_vcodec", "hclk_vcodec", "clk_core";
                rockchip,normal-rates = <500000000>, <0>, <800000000>;
                assigned-clocks = <&cru 438>, <&cru 439>;
                assigned-clock-rates = <500000000>, <800000000>;
                resets = <&cru 377>, <&cru 376>, <&cru 378>;
                reset-names = "video_a", "video_h", "video_core";
                rockchip,skip-pmu-idle-request;
                iommus = <&rkvenc0_mmu>;
                rockchip,srv = <&mpp_srv>;
                rockchip,ccu = <&rkvenc_ccu>;
                rockchip,taskqueue-node = <7>;
                rockchip,task-capacity = <8>;
                rockchip,rcb-iova = <0xFFD00000 0x100000>;
                power-domains = <&power 16>;
                operating-points-v2 = <&venc_opp_table>;
                status = "okay";
              };

              rkvenc0_mmu: iommu@fdbdf000 {
                compatible = "rockchip,rk3588-iommu", "rockchip,rk3568-iommu";
                reg = <0x0 0xfdbdf000 0x0 0x40>, <0x0 0xfdbdf040 0x0 0x40>;
                interrupts = <0 99 4 0>, <0 100 4 0>;
                interrupt-names = "irq_rkvenc0_mmu0", "irq_rkvenc0_mmu1";
                clocks = <&cru 438>, <&cru 437>;
                clock-names = "aclk", "iface";
                rockchip,disable-mmu-reset;
                rockchip,enable-cmd-retry;
                rockchip,shootdown-entire;
                #iommu-cells = <0>;
                power-domains = <&power 16>;
                status = "okay";
              };

              rkvenc1: rkvenc-core@fdbe0000 {
                compatible = "rockchip,rkv-encoder-v2-core";
                reg = <0x0 0xfdbe0000 0x0 0x6000>;
                interrupts = <0 104 4 0>;
                interrupt-names = "irq_rkvenc1";
                clocks = <&cru 443>, <&cru 442>, <&cru 444>;
                clock-names = "aclk_vcodec", "hclk_vcodec", "clk_core";
                rockchip,normal-rates = <500000000>, <0>, <800000000>;
                assigned-clocks = <&cru 443>, <&cru 444>;
                assigned-clock-rates = <500000000>, <800000000>;
                resets = <&cru 382>, <&cru 381>, <&cru 383>;
                reset-names = "video_a", "video_h", "video_core";
                rockchip,skip-pmu-idle-request;
                iommus = <&rkvenc1_mmu>;
                rockchip,srv = <&mpp_srv>;
                rockchip,ccu = <&rkvenc_ccu>;
                rockchip,taskqueue-node = <7>;
                rockchip,task-capacity = <8>;
                rockchip,rcb-iova = <0xFFC00000 0x100000>;
                power-domains = <&power 17>;
                operating-points-v2 = <&venc_opp_table>;
                status = "okay";
              };

              rkvenc1_mmu: iommu@fdbef000 {
                compatible = "rockchip,rk3588-iommu", "rockchip,rk3568-iommu";
                reg = <0x0 0xfdbef000 0x0 0x40>, <0x0 0xfdbef040 0x0 0x40>;
                interrupts = <0 102 4 0>, <0 103 4 0>;
                interrupt-names = "irq_rkvenc1_mmu0", "irq_rkvenc1_mmu1";
                clocks = <&cru 443>, <&cru 442>;
                clock-names = "aclk", "iface";
                rockchip,disable-mmu-reset;
                rockchip,enable-cmd-retry;
                rockchip,shootdown-entire;
                #iommu-cells = <0>;
                power-domains = <&power 17>;
                status = "okay";
              };

              rkvdec1: rkvdec-core@fdc48000 {
                compatible = "rockchip,rkv-decoder-v2";
                reg = <0x0 0xfdc48100 0x0 0x400>, <0x0 0xfdc48000 0x0 0x100>;
                reg-names = "regs", "link";
                interrupts = <0 97 4 0>;
                interrupt-names = "irq_rkvdec1";
                clocks = <&cru 390>, <&cru 389>, <&cru 393>, <&cru 391>, <&cru 392>;
                clock-names = "aclk_vcodec", "hclk_vcodec", "clk_core", "clk_cabac", "clk_hevc_cabac";
                rockchip,normal-rates = <800000000>, <0>, <600000000>, <600000000>, <1000000000>;
                assigned-clocks = <&cru 390>, <&cru 393>, <&cru 391>, <&cru 392>;
                assigned-clock-rates = <800000000>, <600000000>, <600000000>, <1000000000>;
                resets = <&cru 330>, <&cru 329>, <&cru 335>, <&cru 333>, <&cru 334>;
                reset-names = "video_a", "video_h", "video_core", "video_cabac", "video_hevc_cabac";
                rockchip,skip-pmu-idle-request;
                iommus = <&rkvdec1_mmu>;
                rockchip,srv = <&mpp_srv>;
                rockchip,ccu = <&rkvdec_ccu>;
                rockchip,core-mask = <0x00020002>;
                rockchip,task-capacity = <16>;
                rockchip,taskqueue-node = <9>;
                rockchip,sram = <&rkvdec1_sram>;
                rockchip,rcb-iova = <0xFFE00000 0x100000>;
                rockchip,rcb-info = <136 24576>, <137 49152>, <141 90112>, <140 49152>,
                                    <139 180224>, <133 49152>, <134 8192>, <135 4352>,
                                    <138 13056>, <142 291584>;
                rockchip,rcb-min-width = <512>;
                power-domains = <&power 15>;
                status = "okay";
              };

              rkvdec0: rkvdec-core@fdc38000 {
                compatible = "rockchip,rkv-decoder-v2";
                reg = <0x0 0xfdc38100 0x0 0x400>, <0x0 0xfdc38000 0x0 0x100>;
                reg-names = "regs", "link";
                interrupts = <0 95 4 0>;
                interrupt-names = "irq_rkvdec0";
                clocks = <&cru 385>, <&cru 384>, <&cru 388>, <&cru 386>, <&cru 387>;
                clock-names = "aclk_vcodec", "hclk_vcodec", "clk_core", "clk_cabac", "clk_hevc_cabac";
                rockchip,normal-rates = <800000000>, <0>, <600000000>, <600000000>, <1000000000>;
                assigned-clocks = <&cru 385>, <&cru 388>, <&cru 386>, <&cru 387>;
                assigned-clock-rates = <800000000>, <600000000>, <600000000>, <1000000000>;
                resets = <&cru 323>, <&cru 322>, <&cru 328>, <&cru 326>, <&cru 327>;
                reset-names = "video_a", "video_h", "video_core", "video_cabac", "video_hevc_cabac";
                rockchip,skip-pmu-idle-request;
                iommus = <&rkvdec0_mmu>;
                rockchip,srv = <&mpp_srv>;
                rockchip,ccu = <&rkvdec_ccu>;
                rockchip,core-mask = <0x00010001>;
                rockchip,task-capacity = <16>;
                rockchip,taskqueue-node = <9>;
                rockchip,sram = <&rkvdec0_sram>;
                rockchip,rcb-iova = <0xFFF00000 0x100000>;
                rockchip,rcb-info = <136 24576>, <137 49152>, <141 90112>, <140 49152>,
                                    <139 180224>, <133 49152>, <134 8192>, <135 4352>,
                                    <138 13056>, <142 291584>;
                rockchip,rcb-min-width = <512>;
                power-domains = <&power 14>;
                status = "okay";
              };

              rkvdec0_mmu: iommu@fdc38700 {
                compatible = "rockchip,iommu-v2";
                reg = <0x0 0xfdc38700 0x0 0x40>, <0x0 0xfdc38740 0x0 0x40>;
                interrupts = <0 96 4 0>;
                interrupt-names = "irq_rkvdec0_mmu";
                clocks = <&cru 385>, <&cru 384>;
                clock-names = "aclk", "iface";
                rockchip,skip-mmu-read;
                rockchip,disable-mmu-reset;
                rockchip,enable-cmd-retry;
                rockchip,shootdown-entire;
                rockchip,master-handle-irq;
                #iommu-cells = <0>;
                power-domains = <&power 14>;
                status = "okay";
              };

              rkvdec1_mmu: iommu@fdc48700 {
                compatible = "rockchip,iommu-v2";
                reg = <0x0 0xfdc48700 0x0 0x40>, <0x0 0xfdc48740 0x0 0x40>;
                interrupts = <0 98 4 0>;
                interrupt-names = "irq_rkvdec1_mmu";
                clocks = <&cru 390>, <&cru 389>;
                clock-names = "aclk", "iface";
                rockchip,skip-mmu-read;
                rockchip,disable-mmu-reset;
                rockchip,enable-cmd-retry;
                rockchip,shootdown-entire;
                rockchip,master-handle-irq;
                #iommu-cells = <0>;
                power-domains = <&power 15>;
                status = "okay";
              };

              av1d_mmu: iommu@fdca0000 {
                compatible = "rockchip,rk3588-iommu", "rockchip,rk3568-iommu";
                reg = <0x0 0xfdca0000 0x0 0x600>;
                interrupts = <0 109 4 0>;
                interrupt-names = "irq_av1d_mmu";
                clocks = <&cru 65>, <&cru 67>;
                clock-names = "aclk", "iface";
                #iommu-cells = <0>;
                power-domains = <&power 23>;
                status = "okay";
              };

              venc_opp_table: venc-opp-table {
                compatible = "operating-points-v2";
                nvmem-cells = <&codec_leakage>, <&venc_opp_info>;
                nvmem-cell-names = "leakage", "opp-info";
                rockchip,leakage-voltage-sel = <
                  1 15 0
                  16 25 1
                  26 254 2
                >;
                rockchip,grf = <&sys_grf>;
                volt-mem-read-margin = <
                  855000 1
                  765000 2
                  675000 3
                  495000 4
                >;

                opp-800000000 {
                  opp-hz = /bits/ 64 <800000000>;
                  opp-microvolt = <750000 750000 850000>, <750000 750000 850000>;
                  opp-microvolt-L0 = <800000 800000 850000>, <800000 800000 850000>;
                  opp-microvolt-L1 = <775000 775000 850000>, <775000 775000 850000>;
                  opp-microvolt-L2 = <750000 750000 850000>, <750000 750000 850000>;
                };
              };
            };

            &system_sram2 {
              rkvdec0_sram: rkvdec-sram@0 {
                reg = <0x0 0x78000>;
              };

              rkvdec1_sram: rkvdec-sram@78000 {
                reg = <0x78000 0x77000>;
              };
            };

            &{/aliases} {
              vdpu = "/vdpu@fdb50400";
              jpege0 = "/video-codec@fdba0000";
              jpege1 = "/video-codec@fdba4000";
              jpege2 = "/video-codec@fdba8000";
              jpege3 = "/video-codec@fdbac000";
              rkvdec0 = "/rkvdec-core@fdc38000";
              rkvdec1 = "/rkvdec-core@fdc48000";
              rkvenc0 = "/rkvenc-core@fdbd0000";
              rkvenc1 = "/rkvenc-core@fdbe0000";
            };

            &{/video-codec@fdba0000} {
              compatible = "rockchip,vpu-jpege-core";
              reg = <0x0 0xfdba0000 0x0 0x400>;
              interrupt-names = "irq_jpege0";
              clock-names = "aclk_vcodec", "hclk_vcodec";
              rockchip,normal-rates = <594000000>, <0>;
              assigned-clocks = <&cru 413>;
              assigned-clock-rates = <594000000>;
              resets = <&cru 355>, <&cru 356>;
              reset-names = "video_a", "video_h";
              rockchip,skip-pmu-idle-request;
              rockchip,disable-auto-freq;
              rockchip,srv = <&mpp_srv>;
              rockchip,taskqueue-node = <2>;
              rockchip,ccu = <&jpege_ccu>;
              status = "okay";
            };

            &{/video-codec@fdba4000} {
              compatible = "rockchip,vpu-jpege-core";
              reg = <0x0 0xfdba4000 0x0 0x400>;
              interrupt-names = "irq_jpege1";
              clock-names = "aclk_vcodec", "hclk_vcodec";
              rockchip,normal-rates = <594000000>, <0>;
              assigned-clocks = <&cru 415>;
              assigned-clock-rates = <594000000>;
              resets = <&cru 357>, <&cru 358>;
              reset-names = "video_a", "video_h";
              rockchip,skip-pmu-idle-request;
              rockchip,disable-auto-freq;
              rockchip,srv = <&mpp_srv>;
              rockchip,taskqueue-node = <2>;
              rockchip,ccu = <&jpege_ccu>;
              status = "okay";
            };

            &{/video-codec@fdba8000} {
              compatible = "rockchip,vpu-jpege-core";
              reg = <0x0 0xfdba8000 0x0 0x400>;
              interrupt-names = "irq_jpege2";
              clock-names = "aclk_vcodec", "hclk_vcodec";
              rockchip,normal-rates = <594000000>, <0>;
              assigned-clocks = <&cru 417>;
              assigned-clock-rates = <594000000>;
              resets = <&cru 359>, <&cru 360>;
              reset-names = "video_a", "video_h";
              rockchip,skip-pmu-idle-request;
              rockchip,disable-auto-freq;
              rockchip,srv = <&mpp_srv>;
              rockchip,taskqueue-node = <2>;
              rockchip,ccu = <&jpege_ccu>;
              status = "okay";
            };

            &{/video-codec@fdbac000} {
              compatible = "rockchip,vpu-jpege-core";
              reg = <0x0 0xfdbac000 0x0 0x400>;
              interrupt-names = "irq_jpege3";
              clock-names = "aclk_vcodec", "hclk_vcodec";
              rockchip,normal-rates = <594000000>, <0>;
              assigned-clocks = <&cru 419>;
              assigned-clock-rates = <594000000>;
              resets = <&cru 361>, <&cru 362>;
              reset-names = "video_a", "video_h";
              rockchip,skip-pmu-idle-request;
              rockchip,disable-auto-freq;
              rockchip,srv = <&mpp_srv>;
              rockchip,taskqueue-node = <2>;
              rockchip,ccu = <&jpege_ccu>;
              status = "okay";
            };

            &{/video-codec@fdc70000} {
              compatible = "rockchip,av1-decoder";
              reg = <0x0 0xfdc70000 0x0 0x800>, <0x0 0xfdc80000 0x0 0x400>,
                    <0x0 0xfdc90000 0x0 0x400>;
              reg-names = "vcd", "cache", "afbc";
              interrupts = <0 108 4 0>, <0 107 4 0>, <0 106 4 0>;
              interrupt-names = "irq_av1d", "irq_cache", "irq_afbc";
              clock-names = "aclk_vcodec", "hclk_vcodec";
              rockchip,normal-rates = <400000000>, <400000000>;
              assigned-clocks = <&cru 65>, <&cru 67>;
              assigned-clock-rates = <400000000>, <400000000>;
              resets = <&cru 510>, <&cru 512>;
              reset-names = "video_a", "video_h";
              iommus = <&av1d_mmu>;
              rockchip,srv = <&mpp_srv>;
              rockchip,taskqueue-node = <11>;
              power-domains = <&power 23>;
              status = "okay";
            };

            &{/efuse@fecc0000} {
              venc_opp_info: venc-opp-info@67 {
                reg = <0x67 0x6>;
              };
            };


            &{/video-codec@fdb50000} {
              status = "disabled";
            };

          '';
        }
      ];

      boot.blacklistedKernelModules = lib.optionals (cfg.videoBackend == "mpp") [
        "rockchip_vdec"
        "hantro_vpu"
      ];

      assertions = [
        {
          assertion = !(cfg.videoBackend == "mpp" && cfg.useMinimalKernel);
          message = "dev.johnrinehart.rock5c.videoBackend = \"mpp\" requires the 6.19 vendor-MPP patch stack and is incompatible with useMinimalKernel.";
        }
        {
          assertion = !(cfg.mpp.driverMask != null && cfg.videoBackend != "mpp");
          message = "dev.johnrinehart.rock5c.mpp.driverMask only applies when dev.johnrinehart.rock5c.videoBackend = \"mpp\".";
        }
        {
          assertion = !(cfg.mpp.disabledDrivers != [ ] && cfg.videoBackend != "mpp");
          message = "dev.johnrinehart.rock5c.mpp.disabledDrivers only applies when dev.johnrinehart.rock5c.videoBackend = \"mpp\".";
        }
        {
          assertion = !(cfg.mpp.driverMask != null && cfg.mpp.disabledDrivers != [ ]);
          message = "Use either dev.johnrinehart.rock5c.mpp.driverMask or dev.johnrinehart.rock5c.mpp.disabledDrivers, not both.";
        }
        {
          assertion =
            (!cfg.netconsole.enable)
            || (cfg.netconsole.targetIP != null && cfg.netconsole.targetMAC != null);
          message = ''
            dev.johnrinehart.rock5c.netconsole.enable requires both
            dev.johnrinehart.rock5c.netconsole.targetIP and
            dev.johnrinehart.rock5c.netconsole.targetMAC.
          '';
        }
      ];

      boot.kernelParams = lib.mkAfter [
        "earlycon=uart8250,mmio32,0xfeb50000"
        "ignore_loglevel"
      ];

      boot.extraModprobeConfig = lib.concatStringsSep "\n" (
        lib.optional cfg.netconsole.enable ''
          options netconsole netconsole=${toString cfg.netconsole.sourcePort}@/${cfg.netconsole.device},${toString cfg.netconsole.targetPort}@${cfg.netconsole.targetIP}/${cfg.netconsole.targetMAC}
        ''
        ++ lib.optional (cfg.videoBackend == "mpp" && effectiveMppDriverMask != null) ''
          options rk_vcodec mpp_driver_mask=${toString effectiveMppDriverMask}
        ''
      );

      environment.systemPackages = [
        pkgs.rock5c-flash-image
        pkgs.flash-rock5c-sd
        pkgs.flash-rock5c-emmc
      ];

      system.build.sdImage = makeRock5cImage {
        name = "rock-5c-sdcard-image";
        volumeLabel = cfg.rootfsLabel;
      };

      system.build.eMMCImage = makeRock5cImage {
        name = "rock-5c-emmc-image";
        volumeLabel = cfg.rootfsLabel;
      };

      # Keep rk_vcodec manual-load only for now. Autoloading at boot may
      # trigger the same early probe crash we saw when the driver was built-in.
      # boot.kernelModules = lib.optionals (cfg.videoBackend == "mpp") [ "rk_vcodec" ];

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
      ] ++ lib.optionals (cfg.videoBackend == "mpp") [
        {
          name = "rock5c-mpp-video-kconfig";
          patch = null;
          structuredExtraConfig = with lib.kernel; {
            VIDEO_ROCKCHIP_VDEC = no;
            VIDEO_HANTRO = no;
            ROCKCHIP_MPP_SERVICE = module;
            ROCKCHIP_MPP_PROC_FS = yes;
            ROCKCHIP_MPP_RKVDEC = yes;
            ROCKCHIP_MPP_RKVDEC2 = yes;
            ROCKCHIP_MPP_VDPU1 = yes;
            ROCKCHIP_MPP_VDPU2 = yes;
            ROCKCHIP_MPP_AV1DEC = yes;
            PSTORE = yes;
            PSTORE_CONSOLE = yes;
            PSTORE_PMSG = yes;
            PSTORE_RAM = yes;
          };
        }
        {
          name = "rockchip-mpp-6.19.7";
          patch = ./patches/rockchip-mpp-6.19.7.patch;
        }
        {
          name = "rockchip-pmu-mpp-compat";
          patch = ./patches/rockchip-pmu-mpp-compat.patch;
        }
        {
          name = "rockchip-iommu-mpp-compat";
          patch = ./patches/rockchip-iommu-mpp-compat.patch;
        }
        {
          name = "rockchip-iommu-mpp-rkvdec2";
          patch = ./patches/rockchip-iommu-mpp-rkvdec2.patch;
        }
        {
          name = "rockchip-mpp-rkvdec2-reserve-rcb-iova";
          patch = ./patches/rockchip-mpp-rkvdec2-reserve-rcb-iova.patch;
        }
        {
          name = "rockchip-mpp-probe-cleanup";
          patch = ./patches/rockchip-mpp-probe-cleanup.patch;
        }
        {
          name = "rockchip-mpp-driver-mask";
          patch = ./patches/rockchip-mpp-driver-mask.patch;
        }
        {
          name = "rockchip-mpp-rkvdec2-ccu-defer";
          patch = ./patches/rockchip-mpp-rkvdec2-ccu-defer.patch;
        }
      ];

      systemd.services.mount-pstore = {
        description = "Mount pstore filesystem for crash capture";
        wantedBy = [ "multi-user.target" ];
        after = [ "local-fs.target" ];
        path = [ pkgs.util-linux pkgs.coreutils ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          mkdir -p /sys/fs/pstore
          mountpoint -q /sys/fs/pstore || mount -t pstore pstore /sys/fs/pstore || true
        '';
      };

      systemd.services.netconsole-online = lib.mkIf cfg.netconsole.enable {
        description = "Enable netconsole after network is online";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        path = [ pkgs.kmod pkgs.iproute2 pkgs.coreutils ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          set -e
          for _ in $(seq 1 20); do
            if ${pkgs.iproute2}/bin/ip -4 -br addr show ${cfg.netconsole.device} 2>/dev/null | ${pkgs.gnugrep}/bin/grep -Eq '([0-9]{1,3}\.){3}[0-9]{1,3}/'; then
              break
            fi
            ${pkgs.coreutils}/bin/sleep 2
          done
          ${pkgs.iproute2}/bin/ip -4 -br addr show ${cfg.netconsole.device} | ${pkgs.gnugrep}/bin/grep -Eq '([0-9]{1,3}\.){3}[0-9]{1,3}/'
          ${pkgs.kmod}/bin/modprobe -r netconsole 2>/dev/null || true
          ${pkgs.kmod}/bin/modprobe netconsole
        '';
      };
    })

    (lib.mkIf cfg.ssdStore.enable (
      let
        ssdMount = cfg.ssdStore.mountPoint;
        buildDir = "${ssdMount}/build";
        cacheDir = "${ssdMount}/nix-cache";
        device = cfg.ssdStore.device;
      in
      {
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
              umount "${cacheDir}" 2>/dev/null || true
              umount "${buildDir}" 2>/dev/null || true
              umount "${ssdMount}" 2>/dev/null || true
              rm -f /run/nix/ssd.conf /run/nix/ssd.env
            '';
          };
          script = ''
            set -e

            echo "Attempting to activate LVM VG 'nas' in degraded mode..."
            vgchange -ay --activationmode degraded nas 2>/dev/null || true

            if [ ! -e "${device}" ]; then
              echo "SSD device ${device} not found"
              exit 1
            fi

            mkdir -p "${ssdMount}"

            if ! mount -t btrfs -o subvol=/,compress=zstd,noatime "${device}" "${ssdMount}"; then
              echo "Failed to mount base volume"
              exit 1
            fi

            mkdir -p "${buildDir}" "${cacheDir}"

            if ! mount -t btrfs -o subvol=@build,compress=zstd,noatime "${device}" "${buildDir}"; then
              echo "Failed to mount @build subvolume"
              exit 1
            fi

            if ! mount -t btrfs -o subvol=@cache,compress=zstd,noatime "${device}" "${cacheDir}"; then
              echo "Failed to mount @cache subvolume"
              exit 1
            fi

            chown root:nixbld "${buildDir}"
            chmod 1775 "${buildDir}"

            chmod 0755 "${cacheDir}"
            ${lib.concatMapStringsSep "\n" (user: ''
              mkdir -p "${cacheDir}/${user}"
              chown ${user}:${user} "${cacheDir}/${user}"
              chmod 0755 "${cacheDir}/${user}"
            '') cfg.ssdStore.users}

            mkdir -p /run/nix
            echo "build-dir = ${buildDir}" > /run/nix/ssd.conf
            echo "TMPDIR=${buildDir}" > /run/nix/ssd.env

            echo "SSD setup complete"
          '';
        };

        nix.extraOptions = ''
          !include /run/nix/ssd.conf
        '';

        systemd.services.nix-daemon = {
          after = [ "nix-ssd-mount.service" ];
          wants = [ "nix-ssd-mount.service" ];
          serviceConfig.EnvironmentFile = [ "-/run/nix/ssd.env" ];
        };

        environment.extraInit =
          let
            userList = lib.concatStringsSep "|" cfg.ssdStore.users;
          in
          ''
            if mountpoint -q "${ssdMount}" 2>/dev/null; then
              case "$USER" in
                ${userList})
                  export NIX_CACHE_HOME="${cacheDir}/$USER"
                  ;;
              esac
            fi
          '';
      }
    ))
  ];
}
