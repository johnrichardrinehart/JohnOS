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
    # Use clean Radxa 6.18.2 kernel (CEC patch only, no MPP)
    nixpkgs.overlays = [
      (final: prev: {
        linux_rock5c_minimal = prev.linuxKernel.kernels.linux_latest.override {
          argsOverride = {
            src = builtins.fetchGit {
              url = "https://github.com/radxa/kernel";
              rev = "21c3932c5808c70fa8cbed26bdb768edf75a9d6d";  # radxa/linux-6.18.2
              ref = "linux-6.18.2";
              shallow = true;
            };
            version = "6.18.2";
            modDirVersion = "6.18.2";
          };
        };
      })
    ];

    boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linux_rock5c_minimal;

    # try to add hw-acceleration for the rk3588 (cf.
    # https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/rockchip/)
    boot.kernelPatches =
      let
        cecPatch = {
          name = "rock5c-enable-hdmi-cec";
          patch = pkgs.writeText "rock5c-enable-hdmi-cec.patch" ''
            diff --git a/arch/arm64/boot/dts/rockchip/rk3588s-rock-5c.dts b/arch/arm64/boot/dts/rockchip/rk3588s-rock-5c.dts
            index 123456789abc..def0123456789 100644
            --- a/arch/arm64/boot/dts/rockchip/rk3588s-rock-5c.dts
            +++ b/arch/arm64/boot/dts/rockchip/rk3588s-rock-5c.dts
            @@ -259,6 +259,7 @@ &gpu {
             };

             &hdmi0 {
            +	cec-enable = "true";
             	pinctrl-names = "default";
             	pinctrl-0 = <&hdmim0_tx0_cec
             		     &hdmim1_tx0_hpd
          '';
        };
      in
      # Only apply CEC patch for stable Rock 5C kernel
      [ cecPatch ];
  };
}
