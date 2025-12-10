{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.rock5c;
  readConfig =
    configfile:
    lib.listToAttrs (
      map
        (
          line:
          let
            match = lib.match "(.*)=\"?(.*)\"?" line;
          in
          {
            name = lib.elemAt match 0;
            value = lib.elemAt match 1;
          }
        )
        (
          lib.filter (line: !(lib.hasPrefix "#" line || line == "")) (
            lib.splitString "\n" (builtins.readFile configfile)
          )
        )
    );
in
{
  config = lib.mkIf cfg.useMinimalKernel {
    nixpkgs.overlays = [
      (final: prev: {
        linux_rock5c_minimal = pkgs.linuxManualConfig {
          src = builtins.fetchGit {
            url = "git@github.com:johnrichardrinehart/linux";
            rev = "39162db30263f4931671c06a9aeb6f5a20026d43";
            ref = "jrinehart/v6.16.1/rockchip-video";
            shallow = true;
          };
          version = "6.16.1";
          modDirVersion = "6.16.1";
          configfile = ./rock5c_minimal.config;
          config = readConfig ./rock5c_minimal.config;
        };
      })
    ];

    boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linuxKernel.kernels.linux_6_17;

    # try to add hw-acceleration for the rk3588 (cf.
    # https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/rockchip/)
    boot.kernelPatches =
      let
        radxaVideoKconfig = [
          {
            name = "rockchip-video";
            patch = null;
            structuredExtraConfig = {
              ROCKCHIP_MPP_SERVICE = lib.kernel.module; # consider changing to module
              ROCKCHIP_MULTI_RGA = lib.kernel.module; # consider changing to module
              ROCKCHIP_MPP_PROC_FS = lib.kernel.yes;
              ROCKCHIP_RVE = lib.kernel.yes;
              IEP = lib.kernel.yes; # this creates /proc/iep which currently SEGFAULTs on read. It's possible that other stuff is busted, too, around these graphics drivers since I don't know what the hell I'm doing. So, I'm going to point to the upstream kernel, for now.
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
        ];
      in
      lib.mkIf cfg.enableVPU (
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
        ++ radxaVideoKconfig
      );
  };
}
