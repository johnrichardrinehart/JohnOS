{ nixpkgs, pkgs, lib, ... }:
{
  nixpkgs.config.allowBroken = true; # zfs-kernel-$VERSION is broken

  # add JohnOS-kernel as a package
  nixpkgs.overlays = [
    (
      self: super: {
        JohnOS-kernel = super.linuxPackagesFor (super.linux_latest.override {
          argsOverride = rec {
            src = super.fetchurl {
              url = "mirror://kernel/linux/kernel/v5.x/linux-${version}.tar.xz";
              sha256 = "sha256-eoulhlnV5fD54eCk++05rFIBSdJNeuxGNvz4JV0FdPY=";
            };
            version = "5.16.14";
            modDirVersion = "5.16.14";
          };
          ignoreConfigErrors = true;
        });
      }
    )
  ];

  boot.kernelPackages = pkgs.JohnOS-kernel;
}
