{ lib, pkgs, ... }:
{
  nixpkgs.overlays = [
    (self: super: {
      # this linux doesn't work for some reason
      linuxRock5C = pkgs.linuxPackagesFor (
        (pkgs.linux_latest.override {
          defconfig = "rockchip_linux_defconfig";
          argsOverride =
            let
              version = "6.11.9";
            in
            {
              inherit version;
              modDirVersion = version;
              src = pkgs.fetchurl {
                url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.11.9.tar.xz";

                hash = "sha256-dWWKeqO9lZjJbuHlhixeHTT87XXCjYJccnoVEKbzhLQ=";
              };
            };

          structuredExtraConfig = with lib.kernel; {
            EARLY_PRINTK = yes;
            CONFIG_DEBUG = yes;
          };
        })
      );
    })
  ];

  # these are designed for v6.10
  boot.kernelPatches = [
    {
      name = "add rockchip linux defconfig";
      patch = ./0001-feat-add-rockchip_linux_defconfig.patch;
    }
    {
      name = "introduce the device tree";
      patch = ./0002-feat-pull-DeviceTree-from-Radxa-linux-6.1-stan-rkr4..patch;
    }
  ];

  boot.kernelPackages = lib.mkForce pkgs.linuxRock5C;
}
