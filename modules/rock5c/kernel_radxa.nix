{ lib, pkgs, ... }:
{
  nixpkgs.overlays = [
    (self: super: {
      radxaLinux = pkgs.linuxPackagesFor (
        pkgs.buildLinux {
          src = pkgs.fetchFromGitHub {
            owner = "radxa";
            repo = "kernel";
            #ref = "linux-6.1-stan-rkr1";
            rev = "91727f5354c23539aa50f103f36fb9e200e04072";
            hash = "sha256-a+DL8OF+cyDRvRUszYb4T24O6OtcTugOev0jYxq/BR4=";
          };

          version = "6.1.84";

          defconfig = "rockchip_linux_defconfig";

          kernelPatches = [
            {
              name = "add my flags";
              patch = ./kbuild.patch;
            }
          ];
        }
      );
    })
  ];

  boot.kernelPackages = lib.mkForce pkgs.radxaLinux;
}
