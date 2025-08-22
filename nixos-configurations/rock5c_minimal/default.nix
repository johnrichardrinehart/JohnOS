{ lib, ... }:
{
  nixpkgs.hostPlatform = "aarch64-linux";
  networking.hostName = "rock5c-minimal";
  dev.johnrinehart.rock5c.enable = true;
  dev.johnrinehart.system.enable = true;
  dev.johnrinehart.nix.enable = true;

  # try to add hw-acceleration for the rk3588 (cf.
  # https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/rockchip/)
  boot.kernelPatches =
    let
      radxaVideoKconfig = [
        {
          name = "rockchip-video";
          patch = null;
          structuredExtraConfig = {
            ROCKCHIP_MULTI_RGA = lib.kernel.yes;
            ROCKCHIP_RVE = lib.kernel.yes;
            IEP = lib.kernel.yes;
            ROCKCHIP_MPP_SERVICE = lib.kernel.yes;
            ROCKCHIP_DVBM = lib.kernel.yes;
            ROCKCHIP_VIDEO_TUNNEL = lib.kernel.yes;
            ROCKCHIP_MPP_OSAL = lib.kernel.yes;
	    # I was running into all manner of problems when trying to enable
	    # codec-specific MPP drivers. So, for now these are disabled.
            # ```
            # /nix/store/ll82pfjsgww6cmi7mazcpsbv4b1szd9b-binutils-2.44/bin/ld: Unexpected GOT/PLT entries detected!
            # /nix/store/ll82pfjsgww6cmi7mazcpsbv4b1szd9b-binutils-2.44/bin/ld: Unexpected run-time procedure linkages detected!
            # /nix/store/ll82pfjsgww6cmi7mazcpsbv4b1szd9b-binutils-2.44/bin/ld: drivers/video/rockchip/mpp/mpp_av1dec.o: in function `av1dec_reset':
            # /home/john/linux-6.16/build/../drivers/video/rockchip/mpp/mpp_av1dec.c:868:(.text+0xa8): undefined reference to `rockchip_pmu_idle_request'
            # /nix/store/ll82pfjsgww6cmi7mazcpsbv4b1szd9b-binutils-2.44/bin/ld: /home/john/linux-6.16/build/../drivers/video/rockchip/mpp/mpp_av1dec.c:874:(.text+0xec): undefined reference to `rockchip_pmu_idle_request'
            # /nix/store/ll82pfjsgww6cmi7mazcpsbv4b1szd9b-binutils-2.44/bin/ld: drivers/video/rockchip/mpp/mpp_vdpp.o: in function `mpp_pmu_idle_request':
            # /home/john/linux-6.16/build/../drivers/video/rockchip/mpp/mpp_common.h:822:(.text+0xdac): undefined reference to `rockchip_pmu_idle_request'
            # /nix/store/ll82pfjsgww6cmi7mazcpsbv4b1szd9b-binutils-2.44/bin/ld: /home/john/linux-6.16/build/../drivers/video/rockchip/mpp/mpp_common.h:822:(.text+0xdc4): undefined reference to `rockchip_pmu_idle_request'
            # make[3]: *** [../scripts/Makefile.vmlinux:91: vmlinux] Error 1                                                                                                 
            # make[2]: *** [/home/john/linux-6.16/Makefile:1236: vmlinux] Error 2
            # make[1]: *** [/home/john/linux-6.16/Makefile:248: __sub-make] Error 2
            # make[1]: Leaving directory '/home/john/linux-6.16/build'
            # make: *** [Makefile:248: __sub-make] Error 2
            # ```
            ROCKCHIP_MPP_RKVDEC = lib.kernel.no;
            ROCKCHIP_MPP_RKVDEC2 = lib.kernel.no;
            ROCKCHIP_MPP_RKVENC = lib.kernel.no;
            ROCKCHIP_MPP_RKVENC2 = lib.kernel.no;
            ROCKCHIP_MPP_VDPU1 = lib.kernel.no;
            ROCKCHIP_MPP_VEPU1 = lib.kernel.no;
            ROCKCHIP_MPP_VDPU2 = lib.kernel.no;
            ROCKCHIP_MPP_VEPU2 = lib.kernel.no;
            ROCKCHIP_MPP_IEP2 = lib.kernel.no;
            ROCKCHIP_MPP_JPGDEC = lib.kernel.no;
            ROCKCHIP_MPP_JPGENC = lib.kernel.no;
            ROCKCHIP_MPP_AV1DEC = lib.kernel.no;
            ROCKCHIP_MPP_VDPP = lib.kernel.no;
          };
        }
      ]
      ++
        # note: we omit considering the value of the attrset (the type of the fsentry)
        (lib.attrsets.foldlAttrs (
          acc: name: _:
          acc
          ++ [
            {
              inherit name;
              patch = "${./rockchip_video_patches}/${name}";
            }
          ]
        ) [ ] (builtins.readDir ./rockchip_video_patches));
    in
    [
      {
        name = "dmabuf";
        patch = null;
        structuredExtraConfig = {
          DMABUF_HEAPS = lib.kernel.yes;
          DMABUF_HEAPS_SYSTEM = lib.kernel.yes;
          DMABUF_HEAPS_CMA = lib.kernel.yes;
        };
      }
      {
        name = "cma";
        patch = null;
        structuredExtraConfig = {
          DMA_CMA = lib.kernel.yes;
        };
      }
    ]
    ++ radxaVideoKconfig;

  services.deluge = {
    web = {
      enable = true;
      openFirewall = true;
    };
    enable = true;
    openFilesLimit = 1048576; # 1<<20 = 2^20 = 1048576
  };

  services.jellyfin = {
    openFirewall = true;
    enable = true;
  };
}
