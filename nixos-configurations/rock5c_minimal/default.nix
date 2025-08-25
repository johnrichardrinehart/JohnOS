{ lib, pkgs, ... }:
{
  nixpkgs.hostPlatform = "aarch64-linux";
  networking.hostName = "rock5c-minimal";
  dev.johnrinehart.rock5c.enable = true;
  dev.johnrinehart.system.enable = true;
  dev.johnrinehart.nix.enable = true;

  boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.linux_6_16.override {
    argsOverride = rec {
      src = builtins.fetchGit {
	url = "git@github.com:johnrichardrinehart/linux";
        rev = "43f039345502d7bde53c32e37be702635c9914e2";
        ref = "jrinehart/rockchip-video";
        shallow = true;
      };
      #src = pkgs.fetchFromGitHub {
      #      owner = "johnrichardrinehart";
      #      repo = "linux";
      #      rev = "a9420e8a177c30c25e50be9d88950d34336a79b3";
      #      sha256 = "sha256-qKE2lUd9cuCs4EnjKaI1vvde922XayJ3LNW1vaaNc5Y=";
      #};
      version = "6.16.1";
      modDirVersion = "6.16.1";
      };
  });

  # try to add hw-acceleration for the rk3588 (cf.
  # https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/rockchip/)
  boot.kernelPatches =
    let
      radxaVideoKconfig = [
#        {
#           name = "unused Kconfig options";
#           patch = null;
#           structuredExtraConfig = {
#             RASPBERRYPI_POWER = lib.kernel.no;
#	   };
#        }
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
            RK_DMABUF_PROCFS = lib.kernel.no; # TODO: failed to migrate to 6.16.1
            ROCKCHIP_MINIDUMP = lib.kernel.no; # depends on android_debug_symbols.h which isn't even in Rockchip's/Radxa's fork... Pretty sure this is unsupported.
            ROCKCHIP_FIQ_DEBUGGER = lib.kernel.no; # broken and I don't know what it is
            # disable v1 video drivers - prefer v2
            ROCKCHIP_MPP_RKVDEC = lib.kernel.no;
            ROCKCHIP_MPP_RKVENC = lib.kernel.no;
            ROCKCHIP_MPP_VDPU1 = lib.kernel.no;
            ROCKCHIP_MPP_VEPU1 = lib.kernel.no;
            # enable the things that we want!
            ROCKCHIP_OPP = lib.kernel.yes; # default is m which fails to link in symbols for the below drivers
            ROCKCHIP_PVTM = lib.kernel.yes; # default is m which fails to link in symbols for the below drivers
            ROCKCHIP_MPP_AV1DEC = lib.kernel.yes;
            ROCKCHIP_MPP_IEP2 = lib.kernel.yes;
            ROCKCHIP_MPP_JPGDEC = lib.kernel.yes;
            ROCKCHIP_MPP_JPGENC = lib.kernel.yes;
            ROCKCHIP_MPP_RKVDEC2 = lib.kernel.yes;
            ROCKCHIP_MPP_RKVENC2 = lib.kernel.yes;
            ROCKCHIP_MPP_VDPP = lib.kernel.yes;
            ROCKCHIP_MPP_VDPU2 = lib.kernel.yes;
            ROCKCHIP_MPP_VEPU2 = lib.kernel.yes;
          };
        }
      ]
#      ++
#        # note: we omit considering the value of the attrset (the type of the fsentry)
#        (lib.attrsets.foldlAttrs (
#          acc: name: _:
#          acc
#          ++ [
#            {
#              inherit name;
#              patch = "${./rockchip_video_patches}/${name}";
#            }
#          ]
#        ) [ ] (builtins.readDir ./rockchip_video_patches))
	;
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
