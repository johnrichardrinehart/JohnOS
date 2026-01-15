{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.rock5c;
in
{
  config = lib.mkIf cfg.useMinimalKernel {
    # Use jrinehart/linux/rock-5c-hardware-support with full vendor support
    nixpkgs.overlays = [
      (final: prev: {
        linux_rock5c_minimal = prev.linuxKernel.kernels.linux_latest.override {
          argsOverride = {
            src = builtins.fetchGit {
              url = "https://github.com/johnrichardrinehart/linux";
              rev = "8222c8dcf2f34430e15d25a5dbb09623b5a614ea";
              ref = "jrinehart/linux/rock-5c-hardware-support";
              shallow = true;
            };
            version = "6.18.5";
            modDirVersion = "6.18.5";
          };

          structuredExtraConfig = with lib.kernel; {
            # VIDEO_ROCKCHIP must be enabled first
            VIDEO_ROCKCHIP = yes;

            # MPP video codec framework
            ROCKCHIP_MPP_SERVICE = module;
            # Only enable v2 drivers - v1 drivers don't exist in this branch
            ROCKCHIP_MPP_RKVDEC2 = yes;
            ROCKCHIP_MPP_VDPU2 = yes;
            ROCKCHIP_MPP_VEPU2 = yes;
            ROCKCHIP_MPP_RKVENC = yes;
            ROCKCHIP_MPP_RKVENC2 = yes;
            ROCKCHIP_MPP_IEP2 = yes;
            ROCKCHIP_MPP_JPGDEC = yes;
            ROCKCHIP_MPP_AV1DEC = yes;
            ROCKCHIP_MPP_VDPP = yes;

            # RGA3 2D graphics accelerator (correct name is MULTI_RGA)
            ROCKCHIP_MULTI_RGA = module;
            ROCKCHIP_RGA_DEBUGGER = yes;
            ROCKCHIP_RGA_DEBUG_FS = yes;
            ROCKCHIP_RGA_PROC_FS = yes;

            # Rockchip SIP/ATF interface (required by DMC and suspend mode)
            ROCKCHIP_SIP = module;

            # DVFS and power management
            ROCKCHIP_OPP = module;
            ROCKCHIP_SYSTEM_MONITOR = module;
            ROCKCHIP_IPA = module;
            # Note: ROCKCHIP_PM_CONFIG is built as part of ROCKCHIP_SUSPEND_MODE
            ROCKCHIP_SUSPEND_MODE = module;

            # DMC memory controller scaling
            PM_DEVFREQ = yes;
            DEVFREQ_GOV_SIMPLE_ONDEMAND = yes;
            # Disable mainline RK3399 DMC driver - it's for older RK3399 SoC only
            # Rock 5C uses RK3588s which requires the vendor DMC driver below
            # The mainline driver also expects SIP constants that don't exist in
            # the vendor headers, causing compilation errors. Since we're using
            # the vendor ecosystem (MPP, RGA3, SIP, OPP, IPA), we must use the
            # vendor DMC driver that integrates with this stack.
            ARM_RK3399_DMC_DEVFREQ = no;
            ARM_ROCKCHIP_DMC_DEVFREQ = module;

            # NPU - Rocket mainline driver
            DRM_ACCEL = yes;
            DRM_ACCEL_ROCKET = module;
          };
        };
      })
    ];

    boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linux_rock5c_minimal;

    # No additional patches needed - the branch includes comprehensive
    # device tree with HDMI, USB, thermal, and all hardware support
    boot.kernelPatches = [ ];
  };
}
