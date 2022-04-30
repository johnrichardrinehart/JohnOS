{ nixpkgs, pkgs, lib, ... }:
{
  nixpkgs.config.allowBroken = true; # zfs-kernel-$VERSION is broken

  # add JohnOS-kernel as a package
  nixpkgs.overlays = [
    (
      self: super: {
        JohnOS-kernel =
          let
            v = "5.17.5";
            os_name = "-JohnOS";
          in
          super.linuxPackagesFor (super.linux_latest.override {
            argsOverride = rec {
              src = super.fetchurl {
                url = "mirror://kernel/linux/kernel/v5.x/linux-${version}.tar.xz";
                sha256 = "sha256-m7zRhblENvnI/pd/oOhi9g00ADViMn/OuyfJ+jQv6Yc=";
              };

              version = "${v}";
              modDirVersion = "${v}${os_name}";

              extraConfig = ''
                LOCALVERSION ${os_name}
                LOCALVERSION_AUTO y
              '';
            };
          });
      }
    )
  ];

  boot.kernelPackages = pkgs.JohnOS-kernel;
}
